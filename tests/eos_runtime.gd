extends SceneTree
const Runtime=preload("res://scripts/network/eos/runtime.gd")
const Fixture=preload("res://tests/eos_fixture.gd")
class Backend extends Node:
 signal expired
 signal session_lost
 signal membership_changed
 var initialized:=false
 var product_user_id:="member"
 var lobby_id:=""
 var peer:MultiplayerPeer
 var sdk=Fixture.SDK.new()
 var settings:Dictionary={}
 var creates:=0
 var leaves:=0
 func reject_member(_id:int)->void:pass
 func browse(_config:Dictionary)->Dictionary:return {"lobbies":[{"id":"test","title":"Test","locked":true,"members":1,"capacity":8}]}
 func initialize(value:Dictionary)->String:initialized=true;settings=value;return ""
 func login(_identity:Dictionary,_refresh:Callable)->String:
  await get_tree().process_frame;return ""
 func snapshot()->Dictionary:return {"bucket_id":Runtime.Config.bucket(settings),"max_members":8,"members":[product_user_id],"available_slots":7}
 func create_lobby(_config:Dictionary,_title:String="Fishing together",_locked:bool=false)->Dictionary:
  creates+=1;await get_tree().process_frame;lobby_id="fixture-lobby";return snapshot()
 func join_lobby(_id:String)->Dictionary:return await create_lobby(settings)
 func open_peer(_host:bool)->String:
  peer=Fixture.Native.new();peer.ids=[];return ""
 func identity_token(_id:int)->String:return "a".repeat(64)
 func leave_lobby()->bool:
  await get_tree().process_frame
  if peer!=null:peer.close();peer=null
  if not lobby_id.is_empty():leaves+=1
  lobby_id="";return true
class Meta extends Node:
 signal join_requested(reference:String)
 signal leave_requested(lobby:String)
 var publishes:=0
 var clears:=0
 func identity(_config:Dictionary)->Dictionary:return {"type":10}
 func publish(_config:Dictionary,_lobby:String,_joinable:bool)->bool:
  publishes+=1;await get_tree().process_frame;return true
 func clear()->bool:clears+=1;await get_tree().process_frame;return true
 func invite()->bool:return true
class Session extends Node:
 signal changed
 var online:Node
 var active:=false
 var status:=""
 var peer:MultiplayerPeer
 var attaches:=0
 func leave(text:String="Offline",release_online:=true)->void:
  status=text;active=false
  if peer!=null:peer.close();peer=null
  if release_online:online.stop()
 func attach_transport(value:MultiplayerPeer,_hosting:bool,_label:String)->void:
  peer=value;active=true;attaches+=1
var failures:Array=[]
func check(ok:bool,label:String)->void:
 if not ok:failures.append(label);push_error(label)
func settle(runtime:Node)->void:
 for i in 100:
  await process_frame
  if not runtime.busy and not runtime.stop_due:return
 check(false,"Lifecycle settles")
func _initialize()->void:run.call_deferred()
func run()->void:
 var session=Session.new();root.add_child(session)
 var flow=Runtime.new();session.online=flow
 flow.backend.requests.free();flow.backend.free();flow.meta.requests.free();flow.meta.free()
 flow.backend=Backend.new();flow.meta=Meta.new();session.add_child(flow);flow.setup(session)
 var config:=ConfigFile.new()
 for key in ["product_id","sandbox_id","deployment_id","client_id","client_secret"]:config.set_value("eos",key,"offline-test")
 config.set_value("eos","relay","auto");config.set_value("identity","provider","device");config.save("user://eos-test.cfg")
 check(await flow.start(true,"","user://eos-test.cfg")==OK and session.active,"Online startup attaches gameplay transport")
 var attached_before_browse:int=session.attaches
 await flow.browse_lobbies("user://eos-test.cfg")
 check(flow.lobbies.size()==1 and session.active and session.attaches==attached_before_browse and flow.backend.leaves==0,"Browsing preserves an active lobby")
 var reference:String=flow.join_reference()
 check(not Runtime.Config.parse_reference(flow.config,reference).is_empty(),"Gameplay-scoped invite reference")
 flow.queue_invite(Runtime.Config.join_reference(flow.config,"other-lobby"))
 check(not flow.pending_reference.is_empty() and flow.backend.creates==1,"Invite cannot replace active game automatically")
 session.leave();await settle(flow)
 check(flow.lobby.is_empty() and flow.backend.peer==null and not flow.presence_ready,"Leave clears lobby, native peer and presence")
 var attached:int=session.attaches
 flow.start(true,"","user://eos-test.cfg")
 await process_frame
 session.leave("User cancelled")
 await settle(flow)
 check(session.attaches==attached and not session.active and flow.lobby.is_empty(),"Cancellation during authentication cannot attach late peer")
 check(await flow.start(true,"","user://eos-test.cfg")==OK,"Reconnect after cancellation")
 flow.backend.session_lost.emit();await settle(flow)
 check(not session.active and flow.lobby.is_empty(),"Host/service loss leaves the gameplay session")
 session.queue_free();await process_frame
 print("EOS_RUNTIME_RESULT ",failures);quit(0 if failures.is_empty() else 1)
