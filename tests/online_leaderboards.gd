extends SceneTree
const Catalog=preload("res://scripts/network/leaderboards/catalog.gd")
const Outbox=preload("res://scripts/network/leaderboards/state.gd")
const Service=preload("res://scripts/network/leaderboards/service.gd")
const Providers=preload("res://scripts/network/leaderboards/providers.gd")
class SilentSdk extends Node:
 signal stats_interface_query_stats_callback(data:Dictionary)
 signal lobby_interface_create_lobby_callback(data:Dictionary)
 func stats_interface_query_stats(_options:Object)->void:pass
 func lobby_interface_create_lobby(_options:Object)->void:pass
class Session extends Node:
 var dedicated:=false
 var active:=true
class Runtime extends Node:
 var session=Session.new()
 var lobby:="fixture-lobby"
 var busy:=false
class FakeProvider extends RefCounted:
 var scores:Dictionary={}
 var ingests:Array=[]
 var mirrors:Array=[]
 var reads:=0
 var pages:=0
 var ingest_ok:=true
 var mirror_ok:=true
 var hold:=false
 signal release
 func ingest(values:Dictionary)->bool:ingests.append(values.duplicate());return ingest_ok
 func read_scores()->Dictionary:
  reads+=1
  if hold:await release
  return {"scores":scores.duplicate()}
 func can_mirror()->bool:return true
 func mirror(key:String,score:int)->bool:mirrors.append([key,score]);return mirror_ok
 func page(key:String,index:int)->Dictionary:pages+=1;return {"source":"eos","key":key,"page":index,"total":0,"rows":[]}
class Viewer extends RefCounted:
 var id:="123456"
 func get_id()->String:return id
class ViewerMessage extends RefCounted:
 var user=Viewer.new()
 func get_user()->Object:return user
class Sdk extends RefCounted:
 var wrong_definition:=false
 var start_time:=Catalog.START_TIME
 var end_time:=-1
 var viewer_id:="123456"
 func user_get_logged_in_user_async()->Object:
  var reply=ViewerMessage.new();reply.user.id=viewer_id;return reply
 var writes:Array=[]
 func leaderboards_interface_copy_leaderboard_definition_by_leaderboard_id(options:Object)->Dictionary:
  for definition in Catalog.boards().values():
   if definition.board==options.values.leaderboard_id:
    return {"result_code":0,"definition":{"stat_name":definition.stat,"aggregation":2 if wrong_definition else (0 if definition.aggregation=="MIN" else 1),"start_time":start_time,"end_time":end_time}}
  return {"result_code":18}
 func stats_interface_copy_stat_by_name(options:Object)->Dictionary:
  return {"result_code":0,"stat":{"value":4321}} if options.values.name=="ubs_v1_heaviest_g" else {"result_code":18}
 func leaderboard_write_entry_async(board:String,score:int,extra:PackedByteArray,force_update:bool)->Object:
  writes.append([board,score,extra,force_update]);return RefCounted.new()
 func leaderboards_interface_get_leaderboard_record_count(_options:Object)->int:return 12
 func leaderboards_interface_copy_leaderboard_record_by_index(options:Object)->Dictionary:
  var i:int=options.values.leaderboard_record_index
  return {"result_code":0,"record":{"rank":i,"score":5000-i,"user_display_name":"Angler","user_id":"must-not-leak"}}
class Backend extends Node:
 var initialized:=true
 var product_user_id:="fixture-eos-user"
 var sdk=Sdk.new()
 var calls:Array=[]
 var hold:=false
 signal release
 func _call(method:String,values:Dictionary)->Dictionary:
  calls.append([method,values.duplicate(true)])
  if hold:await release
  return {"result_code":0}
class Requests extends Node:
 func meta(request:Object)->Object:return request
class Meta extends Node:
 var user_id:="123456"
 var enabled:=true
 var sdk=Sdk.new()
 var requests=Requests.new()
var failures:Array=[]
var checks:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func fresh(name:String)->RefCounted:
 var value=Outbox.new();var path:String="user://online-board-test/"+name+".json"
 DirAccess.remove_absolute(path);value.open(path,"fixture");return value
func _initialize()->void:run.call_deferred()
func run()->void:
 check(Catalog.boards().size()==8,"Bounded best-score catalog")
 var portal=JSON.parse_string(FileAccess.get_file_as_string("res://docs/EOS_LEADERBOARDS.example.json"))
 for definition in portal.boards:
  var local:Dictionary=Catalog.boards()[definition.key]
  check(local.stat==definition.eos_stat_name and local.board==definition.eos_leaderboard_id and local.meta==definition.meta_api_name and local.aggregation==definition.eos_stat_aggregation and definition.eos_start_time==Catalog.START_TIME and definition.eos_end_time==-1,"Portal provisioning template matches " + definition.key)
 check(Catalog.encode("heaviest",1.234)==1234 and Catalog.encode("longest",123.4)==1234,"Stable grams and millimetres encoding")
 check(Catalog.encode("catches",10)==0 and Catalog.encode("heaviest",INF)==0 and Catalog.encode("heaviest",1e12)==0,"No counters, nonfinite scores or overflow")
 var state=fresh("persistence")
 check(state.offer("heaviest",1200) and not state.offer("heaviest",1100),"MAX keeps best")
 check(state.offer("golf/spyglass",80) and state.offer("golf/spyglass",75) and not state.offer("golf/spyglass",85),"MIN keeps best")
 check(state.save()==OK,"Outbox persists atomically")
 var restored=Outbox.new();restored.open(state.path,"fixture")
 check(restored.pending()==state.pending(),"Restart retries unacknowledged scores")
 state.observe({"heaviest":1100});check(state.pending().heaviest==1200,"Eventual consistency never clears a newer pending score")
 state.offer("heaviest",1300);state.observe({"heaviest":1200})
 check(state.pending().heaviest==1300 and state.mirror_jobs({"heaviest":1200}).heaviest==1200,"Mirror only EOS-confirmed value, not newer local value")
 state.observe({"heaviest":1300,"golf/spyglass":75});check(state.pending().is_empty(),"Read-back acknowledges both aggregation types")
 var wrong=Outbox.new();wrong.open(state.path,"different-account")
 check(not wrong.error.is_empty() and wrong.save()==ERR_FILE_CORRUPT,"Account mismatch cannot overwrite existing outbox")
 var file:=FileAccess.open(state.path,FileAccess.WRITE);file.store_string("broken");file.close()
 restored.open(state.path,"fixture");check(restored.save()==ERR_FILE_CORRUPT and FileAccess.get_file_as_string(state.path)=="broken","Corrupt outbox preserved")
 var runtime=Runtime.new();root.add_child(runtime);runtime.add_child(runtime.session)
 var service=Service.new();runtime.add_child(service);service.setup(runtime);service.set_process(false)
 var provider=FakeProvider.new();service.provider=provider;service.outbox=fresh("sync");service.enabled=true
 runtime.session.dedicated=true;service.offer("heaviest",9000)
 runtime.session.dedicated=false;runtime.lobby="";service.offer("heaviest",9000)
 check(service.outbox.targets.is_empty(),"Dedicated and ENet sessions cannot export scores")
 runtime.lobby="fixture-lobby";service.offer("heaviest",1800)
 provider.ingest_ok=false;await service.synchronize()
 check(provider.reads==0 and provider.mirrors.is_empty() and service.outbox.pending().heaviest==1800,"Failed ingest cannot advance either provider")
 check(service.due-Time.get_ticks_msec()>100000,"Failures back off")
 provider.ingest_ok=true;provider.scores={"heaviest":1400};await service.synchronize()
 check(provider.mirrors[-1]==["heaviest",1400] and service.outbox.pending().heaviest==1800,"Stale EOS read mirrors only confirmed score and retains target")
 provider.scores.heaviest=1800;provider.mirror_ok=false;await service.synchronize()
 check(service.outbox.pending().is_empty() and service.outbox.mirrored.heaviest==1400,"Meta failure retains independent mirror retry")
 var count:int=provider.ingests.size();provider.mirror_ok=true;await service.synchronize()
 check(provider.ingests.size()==count and service.outbox.mirrored.heaviest==1800,"Meta retry never re-ingests acknowledged EOS score")
 var before:int=provider.mirrors.size()
 for key in Catalog.boards():provider.scores[key]=100
 provider.mirror_ok=false;await service.synchronize();await service.synchronize()
 check(provider.mirrors.size()-before==4 and provider.mirrors[before][0]!=provider.mirrors[before+2][0],"Two writes per cycle and fair retry rotation")
 await service.query_page("heaviest",0);await service.query_page("heaviest",0)
 check(provider.pages==1,"Repeated UI requests use a bounded cache")
 check((await service.query_page("catches",0)).has("error") and (await service.query_page("heaviest",5)).has("error"),"Unsupported categories and pages rejected")
 var values_before:Dictionary=service.outbox.confirmed.duplicate()
 provider.hold=true;provider.scores={"heaviest":99999};service.synchronize()
 await process_frame
 service.stop();provider.release.emit();await process_frame
 check(service.outbox.confirmed==values_before and not service.busy,"Late response after leaving cannot mutate account state")
 service.enabled=true
 var golf_card:Dictionary={"finished":true,"retired":false,"course":"spyglass","scores":[]}
 for i in 18:golf_card.scores.append(4)
 service.observe_golf(golf_card);check(service.outbox.targets.get("golf/spyglass")==72,"Only completed own golf card is collected")
 golf_card.scores[0]=-1;service.observe_golf(golf_card)
 check(service.outbox.targets.get("golf/spyglass")==72,"Forfeit does not create lower golf score")
 service.collector.connect_player(1,"local","Local player")
 var wire:Dictionary={"user_height":1.78,"golf_club":-1,"golf_stowed":false,"body":{},"face":{},"visemes":PackedFloat32Array([0,0,0,0,0]),"serial":0,"location":"fish_hoek_beach","rod_tier":0,"rig":2,"reel_angle":0.0,"state":0,"bait":2,"species":39,"length":Service.Board.Fish.SPECIES[39].length*1.14,"caught":false,"in_hand":false,"xr":false,"left_valid":true,"right_valid":true,"bobber_visible":false,"bait_visible":true,"curl":0.0}
 var state_codec=preload("res://scripts/network/state.gd")
 for key in state_codec.TRANSFORMS:wire[key]=Transform3D.IDENTITY
 for key in state_codec.VECTORS:wire[key]=Vector3.ZERO
 for phase in [1,4,5]:
  wire.serial+=1;wire.state=phase;wire.caught=phase==5;service.observe_state(wire)
 check(service.outbox.targets.get("longest")==Catalog.encode("longest",wire.length) and service.outbox.targets.heaviest>1800,"Live local fishing sequence collects personal bests")
 check(not service.outbox.targets.has("earned") and not service.outbox.targets.has("catches"),"Server-local counters never become global totals")
 var backend=Backend.new();var meta=Meta.new();var adapters=Providers.new();adapters.bind(backend,meta)
 backend.sdk.wrong_definition=true
 check(not await adapters.ingest({"heaviest":1234}) and backend.calls.size()==1,"Mismatched EOS aggregation blocks writes")
 backend.sdk.wrong_definition=false
 backend.sdk.start_time=Catalog.START_TIME+60
 check(not await adapters.ingest({"heaviest":1234}),"Different EOS start window blocks writes")
 backend.sdk.start_time=Catalog.START_TIME;backend.sdk.end_time=Catalog.START_TIME+86400
 check(not await adapters.ingest({"heaviest":1234}),"Expiring EOS leaderboard blocks writes")
 backend.sdk.end_time=-1
 check(await adapters.ingest({"heaviest":1234}),"Pinned EOS stats adapter accepts valid schema")
 var submitted:Dictionary=backend.calls[-1][1]
 check(submitted.local_user_id==backend.product_user_id and submitted.target_user_id==backend.product_user_id and submitted.stats==[{"stat_name":"ubs_v1_heaviest_g","ingest_amount":1234}],"Only local PUID and integer absolute score sent to EOS")
 var read:Dictionary=await adapters.read_scores()
 check(read=={"scores":{"heaviest":4321}},"Unranked stats are absent, not synthetic zero scores")
 check(await adapters.mirror("heaviest",4321) and meta.sdk.writes[0][3]==false and meta.sdk.writes[0][2].is_empty(),"Meta write uses keep-best and no identity payload")
 var page:Dictionary=await adapters.page("heaviest",1)
 check(page.rows.size()==2 and page.rows[0].position==11 and not JSON.stringify(page).contains("must-not-leak"),"EOS pages bounded and omit account identifiers")
 meta.sdk.viewer_id="another-viewer";check(not await adapters.mirror("heaviest",4321) and meta.sdk.writes.size()==1,"SDK viewer change blocks mirror even when login cache is stale")
 meta.user_id="changed";check(not await adapters.mirror("heaviest",4321),"Meta identity change blocks mirror")
 backend.product_user_id="changed";check(not await adapters.ingest({"heaviest":9999}),"EOS identity change blocks ingest")
 var cancelled_adapter=Providers.new();cancelled_adapter.bind(backend,meta)
 backend.hold=true;var previous_calls:int=backend.calls.size()
 cancelled_adapter.ingest({"heaviest":9999});await process_frame
 cancelled_adapter.cancel();backend.release.emit();await process_frame;backend.hold=false
 check(backend.calls.size()==previous_calls+1,"Cancellation during definition lookup prevents a later ingest")
 var settings:Dictionary={"deployment_id":"fixture-"+str(Time.get_ticks_usec()),"app_id":"123","leaderboards_enabled":true}
 runtime.session.dedicated=true;service.start(settings,backend,meta)
 check(not service.enabled,"Dedicated service cannot start even with opt-in enabled")
 runtime.session.dedicated=false;service.start(settings,backend,meta);service.offer("heaviest",2468);service.stop();service.start(settings,backend,meta)
 check(service.outbox.pending().get("heaviest")==2468,"Same account resumes its durable outbox")
 backend.product_user_id="another-account";service.start(settings,backend,meta)
 check(service.outbox.targets.is_empty(),"New EOS account cannot inherit pending scores")
 settings.leaderboards_enabled=false;service.start(settings,backend,meta)
 check(not service.enabled,"Configuration explicitly disables synchronization")
 var requests=preload("res://scripts/network/eos/requests.gd").new();root.add_child(requests);requests.timeout_ms=0
 var silent=SilentSdk.new();root.add_child(silent)
 var options=preload("res://scripts/network/eos/options.gd").new()
 for i in 10:await requests.eos(silent,"stats_interface_query_stats","stats_interface_query_stats_callback",options)
 check(requests.abandoned.is_empty(),"Repeated leaderboard timeouts do not leak lobby cleanup state")
 await requests.eos(silent,"lobby_interface_create_lobby","lobby_interface_create_lobby_callback",options)
 check(requests.abandoned.size()==1,"Late lobby cleanup remains tracked")
 requests.free();silent.free()
 if Engine.has_singleton("IEOS"):
  var sdk:Object=Engine.get_singleton("IEOS")
  for method in ["stats_interface_ingest_stat","stats_interface_query_stats","stats_interface_copy_stat_by_name","leaderboards_interface_query_leaderboard_definitions","leaderboards_interface_copy_leaderboard_definition_by_leaderboard_id","leaderboards_interface_query_leaderboard_ranks","leaderboards_interface_get_leaderboard_record_count","leaderboards_interface_copy_leaderboard_record_by_index"]:check(sdk.has_method(method),"Installed EOSG API: "+method)
 meta.requests.free();meta.free();backend.free();runtime.free()
 print("ONLINE_LEADERBOARDS_RESULT ",checks," checks, ",failures)
 quit(0 if failures.is_empty() else 1)
