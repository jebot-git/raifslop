extends SceneTree
## Explicit live test; device identities only, no XR or headset installation.
const Net=preload("res://scripts/network/session.gd")
class Probe extends Node:
 var received:=0
 var voice_count:=0
 var corrupt:=false
 @rpc("any_peer","call_remote","reliable",4)
 func bulk(bytes:PackedByteArray)->void:
  received+=1
  if bytes.size()!=200000 or bytes.count(53)!=200000:corrupt=true
  if multiplayer.is_server():bulk.rpc_id(multiplayer.get_remote_sender_id(),bytes)
 @rpc("any_peer","call_remote","unreliable",6)
 func voice(bytes:PackedByteArray)->void:
  if bytes.size()==400:voice_count+=1
  if multiplayer.is_server():voice.rpc_id(multiplayer.get_remote_sender_id(),bytes)
var net:Node
var probe:Probe
var role:=""
var handoff:=""
var report_path:=""
var pose_max:=0
var lobby_check:=false
var listed:=false
func _process(_delta:float)->bool:
 if net==null or role!="host":return false
 for state in net.states.values():pose_max=maxi(pose_max,int(state.serial))
 return false
func arg(key:String,fallback:String="")->String:
 var args:=OS.get_cmdline_user_args();var i:=args.find(key)
 return args[i+1] if i>=0 and i+1<args.size() else fallback
func _initialize()->void:run.call_deferred()
func until(test:Callable,seconds:=20.0)->bool:
 var end:=Time.get_ticks_msec()+int(seconds*1000)
 while Time.get_ticks_msec()<end:
  if test.call():return true
  await create_timer(.02).timeout
 return false
func write(path:String,data:Dictionary)->void:
 var file:=FileAccess.open(path,FileAccess.WRITE)
 if file!=null:file.store_string(JSON.stringify(data))
func run()->void:
 role=arg("--role");handoff=arg("--handoff");report_path=arg("--result")
 if role not in ["host","client","denied"] or handoff.is_empty() or report_path.is_empty():quit(2);return
 var game:=Node.new();game.name="RealAIFishing";root.add_child(game)
 net=Net.new();game.add_child(net);net.setup(game,true);net.voice_enabled=false
 net.player_token="f".repeat(64);net.display_name="EOS test guest"
 probe=Probe.new();probe.name="Probe";game.add_child(probe)
 var reference:=""
 lobby_check="--lobby-check" in OS.get_cmdline_user_args()
 if role!="host":
  var data=JSON.parse_string(FileAccess.get_file_as_string(handoff))
  if not data is Dictionary or not data.get("reference") is String:await finish(false,"handoff");return
  reference=data.reference
 if lobby_check and role!="host":
  # EOS indexing is eventually consistent immediately after publication.
  for attempt in 8:
   await net.online.browse_lobbies()
   for entry in net.online.lobbies:
    if entry.id==net.online.Config.parse_reference(net.online.config,reference):
     listed=entry.title=="Live fishing lobby" and entry.locked and entry.capacity==8 and entry.members==1
   if listed or not net.online.browse_error.is_empty():break
   await create_timer(1).timeout
  if not listed:await finish(false,"lobby_discovery");return
 var password:="test-lobby-password" if lobby_check else ""
 if role=="denied":password="wrong-password"
 var result:int=await net.online.start(role=="host",reference,"","Live fishing lobby",password)
 if result!=OK:await finish(false,"online_start");return
 if role=="host":
  write(handoff,{"reference":net.online.join_reference()})
  var complete:=await until(func():return FileAccess.file_exists(handoff+".done"),210)
  await finish(complete and probe.received>=4 and pose_max>1 and not probe.corrupt,"host_transfers");return
 if role=="denied":
  var denied:=await until(func():return not net.online.lobby.is_empty() and net.active or net.online.lobby.is_empty() and not net.online.busy)
  await finish(denied and not net.active and net.players.is_empty(),"password_rejected");return
 if not await until(func():return net.active):await finish(false,"gameplay_handshake");return
 net.rankings.request("fishing","catches")
 if not await until(func():return not net.rankings.view.is_empty()):await finish(false,"rankings");return
 var one_record:bool=net.rankings.view.players==1
 var payload:=PackedByteArray();payload.resize(200000);payload.fill(53)
 probe.bulk.rpc_id(1,payload);probe.bulk.rpc_id(1,payload)
 var pose:Dictionary=preload("res://tests/network_fixture.gd").player(10,true)
 var voice:=PackedByteArray();voice.resize(400)
 for i in 150:
  pose.serial=i+1
  if i==0:net._submit_event.rpc_id(1,Net.PoseCodec.encode(pose))
  else:net._send_pose(1,net.multiplayer.get_unique_id(),Net.PoseCodec.encode(pose),false)
  probe.voice.rpc_id(1,voice)
  await create_timer(.02).timeout
 var complete:=await until(func():return probe.received==2 and probe.voice_count>0)
 await finish(complete and one_record and not probe.corrupt,"client_transfers")
func finish(ok:bool,stage:String)->void:
 var stats:Dictionary=net.multiplayer.multiplayer_peer.diagnostics() if net.multiplayer.multiplayer_peer.has_method("diagnostics") else {}
 var network_type:String=net.online.backend.transport
 if ok and role!="denied" and arg("--relay")=="force" and network_type!="2":ok=false;stage="forced_relay"
 if ok and role!="denied" and (stats.get("wire_max_bytes",9999)+6>1000 or stats.get("failed",true)):ok=false;stage="packet_budget"
 net.leave()
 var cleaned:=await until(func():return not net.online.busy and not net.online.stop_due and net.online.backend.lobby_id.is_empty(),20)
 cleaned=cleaned and net.online.cleanup_ok
 write(report_path,{"ok":ok and cleaned,"stage":stage,"role":role,"cleanup":cleaned,"network_type":network_type,"pose_max_serial":pose_max,"bulk_received":probe.received,"voice_received":probe.voice_count,"transport":stats,"listed":listed,"browse_error":net.online.browse_error,"browse_count":net.online.lobbies.size()})
 print("EOS_GAME_RESULT role=%s ok=%s stage=%s cleanup=%s"%[role,ok,stage,cleaned])
 quit(0 if ok and cleaned else 1)
