extends RefCounted
## Use only the already-authenticated local EOS PUID / Meta viewer; no remote-user writes.
const Catalog=preload("res://scripts/network/leaderboards/catalog.gd")
const Options=preload("res://scripts/network/eos/options.gd")
var backend:Node
var meta:Node
var user_id:=""
var meta_id:=""
var definitions_verified:=false
var cancelled:=false
func cancel()->void:cancelled=true
func bind(eos_backend:Node,meta_provider:Node)->void:
 backend=eos_backend;meta=meta_provider;user_id=backend.product_user_id;meta_id=str(meta.get("user_id"))
 definitions_verified=false;cancelled=false
func ready()->bool:
 return not cancelled and is_instance_valid(backend) and backend.initialized and not user_id.is_empty() and backend.product_user_id==user_id and backend.sdk!=null
func can_mirror()->bool:
 return not cancelled and is_instance_valid(meta) and meta.enabled and meta.sdk!=null and not meta_id.is_empty() and str(meta.get("user_id"))==meta_id
func verify_definitions()->bool:
 if not ready():return false
 if definitions_verified:return true
 var reply:Dictionary=await backend._call("leaderboards_interface_query_leaderboard_definitions",{"local_user_id":user_id,"start_time":-1,"end_time":-1})
 if not ready() or reply.get("result_code")!=0:return false
 for definition in Catalog.boards().values():
  var copied:Dictionary=backend.sdk.leaderboards_interface_copy_leaderboard_definition_by_leaderboard_id(Options.new({"leaderboard_id":definition.board}))
  if copied.get("result_code")!=0 or not copied.get("definition") is Dictionary:return false
  var remote:Dictionary=copied.definition
  if remote.get("stat_name")!=definition.stat or remote.get("aggregation")!=(0 if definition.aggregation=="MIN" else 1):return false
  if remote.get("start_time")!=Catalog.START_TIME or remote.get("end_time")!=-1:return false
 definitions_verified=true;return true
func ingest(values:Dictionary)->bool:
 if not ready() or not preload("res://scripts/network/leaderboards/state.gd").valid_scores(values):return false
 if not await verify_definitions():return false
 var stats:Array=[]
 for key in values:stats.append({"stat_name":Catalog.boards()[key].stat,"ingest_amount":int(values[key])})
 if stats.is_empty():return true
 var reply:Dictionary=await backend._call("stats_interface_ingest_stat",{"local_user_id":user_id,"target_user_id":user_id,"stats":stats})
 return ready() and reply.get("result_code")==0
func read_scores()->Dictionary:
 if not ready():return {"error":"EOS leaderboard identity is unavailable."}
 if not await verify_definitions():return {"error":"EOS leaderboard definitions are missing or do not match the configured schema."}
 var definitions:=Catalog.boards()
 var names:Array=[]
 for definition in definitions.values():names.append(definition.stat)
 var reply:Dictionary=await backend._call("stats_interface_query_stats",{"local_user_id":user_id,"target_user_id":user_id,"stat_names":names,"start_time":-1,"end_time":-1})
 if not ready() or reply.get("result_code")!=0:return {"error":"EOS score query failed; will retry."}
 var scores:Dictionary={}
 for key in definitions:
  var copied:Dictionary=backend.sdk.stats_interface_copy_stat_by_name(Options.new({"target_user_id":user_id,"name":definitions[key].stat}))
  if copied.get("result_code")==18:continue # EOS_NotFound: a new player has no score.
  if copied.get("result_code")!=0 or not copied.get("stat") is Dictionary:return {"error":"EOS score cache could not be read."}
  var value=copied.stat.get("value")
  if value==0:continue # Unset/default MAX stat.
  if not Catalog.valid_score(value):return {"error":"EOS returned an invalid leaderboard score."}
  scores[key]=int(value)
 return {"scores":scores}
func mirror(key:String,score:int)->bool:
 if not can_mirror() or not Catalog.boards().has(key) or not Catalog.valid_score(score):return false
 # Recheck the SDK viewer, not just the identity cached at EOS login.
 var viewer:Object=await meta.requests.meta(meta.sdk.user_get_logged_in_user_async())
 if viewer==null or viewer.get_user()==null or str(viewer.get_user().get_id())!=meta_id or not ready() or not can_mirror():return false
 # force_update=false keeps best according to the configured board sort order.
 var request:Object=meta.sdk.leaderboard_write_entry_async(Catalog.boards()[key].meta,score,PackedByteArray(),false)
 return await meta.requests.meta(request)!=null and can_mirror()
func page(key:String,page_index:int)->Dictionary:
 if not ready() or not Catalog.boards().has(key) or page_index<0 or page_index>4:return {"error":"Invalid online ranking request."}
 if not await verify_definitions():return {"error":"EOS leaderboard definitions do not match the configured schema."}
 var reply:Dictionary=await backend._call("leaderboards_interface_query_leaderboard_ranks",{"local_user_id":user_id,"leaderboard_id":Catalog.boards()[key].board})
 if not ready() or reply.get("result_code")!=0:return {"error":"EOS rankings are unavailable."}
 var count:int=mini(50,backend.sdk.leaderboards_interface_get_leaderboard_record_count(Options.new()))
 var rows:Array=[]
 for index in range(page_index*10,mini(count,(page_index+1)*10)):
  var copied:Dictionary=backend.sdk.leaderboards_interface_copy_leaderboard_record_by_index(Options.new({"leaderboard_record_index":index}))
  if copied.get("result_code")!=0 or not copied.get("record") is Dictionary:return {"error":"EOS rankings cache could not be read."}
  var row:Dictionary=copied.record
  if not Catalog.valid_score(row.get("score")) or not row.get("rank") is int or row.rank<0:return {"error":"EOS returned an invalid ranking."}
  # Preserve the native rank and expose a separate one-based list position.
  # Do not expose PUIDs or reconcile people by display name.
  var display_name:=""
  for character in str(row.get("user_display_name","")).left(32):
   if character.unicode_at(0)>=32 and character.unicode_at(0)!=127:display_name+=character
  display_name=display_name.strip_edges()
  rows.append({"rank":row.rank,"position":index+1,"name":display_name if not display_name.is_empty() else "Angler","score":int(row.score)})
 return {"source":"eos","key":key,"page":page_index,"total":count,"rows":rows}
