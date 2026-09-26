extends Node
## Opt-in client-attested records. Dedicated/ENet records never enter this service.
const Catalog=preload("res://scripts/network/leaderboards/catalog.gd")
const Outbox=preload("res://scripts/network/leaderboards/state.gd")
const Board=preload("res://scripts/network/leaderboard.gd")
var runtime:Node
var provider=preload("res://scripts/network/leaderboards/providers.gd").new()
var outbox=Outbox.new()
var collector=Board.new()
var enabled:=false
var busy:=false
var generation:=0
var due:=0
var failures:=0
var status:="Online leaderboard synchronization is disabled."
var page_cache:Dictionary={}
var page_due:=0
var mirror_cursor:=0
signal changed
func setup(owner_runtime:Node)->void:
 runtime=owner_runtime;name="Leaderboards"
func eligible()->bool:
 return enabled and is_instance_valid(runtime) and runtime.session.get("dedicated")!=true and runtime.session.active and not runtime.lobby.is_empty()
func start(settings:Dictionary,backend:Node,meta:Node)->void:
 if not settings.get("leaderboards_enabled",false) or runtime.session.get("dedicated")==true:stop();return
 var identity:String=JSON.stringify([1,settings.get("product_id",""),settings.get("sandbox_id",""),settings.deployment_id,backend.product_user_id,settings.get("app_id",""),str(meta.get("user_id"))]).sha256_text()
 if enabled and outbox.scope==identity:return
 stop();provider=preload("res://scripts/network/leaderboards/providers.gd").new();provider.bind(backend,meta)
 outbox=Outbox.new();outbox.open("user://online-leaderboards/"+identity+".json",identity)
 collector=Board.new();collector.connect_player(1,"local","Local player")
 enabled=outbox.error.is_empty();due=0;failures=0
 status="Waiting to synchronize online records." if enabled else outbox.error
 changed.emit()
func stop()->void:
 generation+=1;enabled=false;page_cache.clear();page_due=0
 if provider.has_method("cancel"):provider.cancel()
 collector.attempts.clear()
 # An in-flight cycle retains its busy flag until its callback settles.
func offer(key:String,score:int)->void:
 if not eligible() or not outbox.offer(key,score):return
 if persist():status="Online records awaiting synchronization.";changed.emit()
func persist()->bool:
 var code:Error=outbox.save()
 if code==OK:return true
 stop();status="Online leaderboard outbox could not be saved.";changed.emit();return false
func observe_state(data:Dictionary)->void:
 if not eligible() or not preload("res://scripts/network/state.gd").valid(data) or data.location.begins_with("golf_"):return
 var before:Dictionary=collector.records.values()[0].duplicate(true)
 if not collector.observe(1,data):return
 var row:Dictionary=collector.records.values()[0]
 for key in ["heaviest","longest"]:offer(key,Catalog.encode(key,float(row[key])))
 for key in ["catches","earned","exceptional"]:outbox.add(key,int(row[key])-int(before[key]))
 persist()
func observe_golf(view:Dictionary)->void:
 if not eligible():return
 var key:String="golf/"+str(view.get("course",""))
 var id:String=str(view.get("id",""))
 if not Catalog.boards().has(key) or id.is_empty() or id.length()>128:return
 id=str(view.course)+":"+id
 var progress:Dictionary=outbox.rounds.get(id,{"complete":false,"forfeits":0})
 var forfeits=view.get("forfeit_holes",[])
 if not forfeits is Array or forfeits.size()>18:return
 var unique:Array=[]
 var forfeits_changed:=false
 for hole in forfeits:
  if not hole is int or hole<0 or hole>=18 or hole in unique:return
  unique.append(hole)
 if forfeits.size()>progress.forfeits:
  outbox.add("golf_forfeits/"+view.course,forfeits.size()-progress.forfeits);progress.forfeits=forfeits.size()
  forfeits_changed=true
 if not outbox.rounds.has(id) and outbox.rounds.size()>=128:outbox.rounds.erase(outbox.rounds.keys()[0])
 outbox.rounds[id]=progress
 if view.get("finished")!=true or view.get("retired",true)!=false or progress.complete:
  if forfeits_changed:persist()
  return
 var scores=view.get("scores")
 if not Catalog.boards().has(key) or not scores is Array or scores.size()!=18:return
 var total:=0
 for score in scores:
  if not score is int or score<1 or score>1000:return # Reject DNF, partial and malformed cards.
  total+=score
 offer(key,total)
 progress.complete=true
 outbox.add("golf_rounds/"+view.course,1)
 var records:Dictionary={"local":{"golf":outbox.golf}}
 preload("res://addons/golfminus/scripts/golf/server_records.gd").finish(records,"local",view.course,scores,false)
 outbox.golf=records.local.golf
 offer("golf_last/"+view.course,total)
 var handicap:float=preload("res://addons/golfminus/scripts/golf/handicap.gd").index(outbox.golf)
 for course in outbox.golf:offer("golf_handicap/"+course,Catalog.encode("golf_handicap/"+course,handicap))
 persist()
func _process(_delta:float)->void:
 if not eligible() or runtime.busy or busy or Time.get_ticks_msec()<due:return
 await synchronize()
func synchronize()->void:
 if not eligible() or busy:return
 busy=true
 var current:=generation
 if not outbox.increments.is_empty():
  var baseline:Dictionary=await provider.read_scores()
  if current!=generation:busy=false;return
  if baseline.has("error") or not Outbox.valid_scores(baseline.get("scores",{})):
   status="Online totals could not be reconciled; will retry.";due=Time.get_ticks_msec()+60000;busy=false;changed.emit();return
  outbox.rebase_counters(baseline.get("scores",{}))
  if not persist():busy=false;return
 var values:Dictionary=outbox.pending()
 var ok:=true
 if not values.is_empty():ok=await provider.ingest(values)
 if current!=generation:busy=false;return
 # A successful ingest callback is not a score: wait for a fresh EOS read before mirroring.
 var result:Dictionary=await provider.read_scores() if ok else {"error":"EOS score submission failed; will retry."}
 if current!=generation:busy=false;return
 if result.has("error"):ok=false;status=str(result.error)
 else:
  var scores:Dictionary=result.get("scores",{})
  if not Outbox.valid_scores(scores):ok=false;status="EOS returned invalid scores."
  else:
   outbox.observe(scores)
   if not persist():busy=false;return
   if provider.can_mirror():
    var jobs:Dictionary=outbox.mirror_jobs(scores)
    # At most two writes per cycle. A failing board must not starve other boards.
    var attempted:=0
    var keys:Array=Catalog.boards().keys()
    for _index in keys.size():
     var key:String=keys[mirror_cursor]
     mirror_cursor=(mirror_cursor+1)%keys.size()
     if not jobs.has(key):continue
     attempted+=1
     var mirrored:bool=await provider.mirror(key,int(jobs[key]))
     if current!=generation:busy=false;return
     if mirrored:outbox.mirrored[key]=jobs[key]
     else:ok=false
     if attempted==2:break
   if ok:status="Online records synchronized." if outbox.pending().is_empty() and (not provider.can_mirror() or outbox.mirror_jobs(scores).is_empty()) else "Online records awaiting synchronization."
   else:status="Meta leaderboard mirror unavailable; will retry."
 failures=0 if ok else mini(failures+1,4)
 due=Time.get_ticks_msec()+mini(300000,60000*(1<<failures))
 busy=false;changed.emit()
func query_page(key:String,page:int=0)->Dictionary:
 if not eligible() or not Catalog.boards().has(key) or page<0 or page>4:return {"error":"Online rankings are unavailable for this session or category."}
 var query:String="%s:%d"%[key,page]
 if page_cache.has(query) and Time.get_ticks_msec()<page_cache[query].expires:return page_cache[query].data.duplicate(true)
 if busy or Time.get_ticks_msec()<page_due:return {"error":"Online rankings are busy; retry shortly."}
 busy=true;page_due=Time.get_ticks_msec()+5000
 var current:=generation
 var result:Dictionary=await provider.page(key,page)
 busy=false
 if current!=generation:return {"error":"Online session changed."}
 if not result.has("error"):page_cache[query]={"expires":Time.get_ticks_msec()+60000,"data":result.duplicate(true)}
 return result
