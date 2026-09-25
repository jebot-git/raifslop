extends SceneTree
## LAN probe against a full, rendering Quest host; this process is only a client.
const Schema=preload("res://scripts/network/state.gd")
const Sites=preload("res://scripts/bbq/sites.gd")
const Food=preload("res://scripts/bbq/model.gd")
var net:Node
var pose:Dictionary={}
var failures:Array=[]
var checks:=0
var sender:Timer
var role:="actor"
const LOCATION="lakeside"
func _initialize()->void:run.call_deferred()
func check(ok:bool,message:String)->bool:
 checks+=1
 print("PASS " if ok else "FAIL ",message)
 if not ok:failures.append(message)
 return ok
func until(fn:Callable,seconds:=15.0)->bool:
 var deadline:=Time.get_ticks_msec()+int(seconds*1000)
 while Time.get_ticks_msec()<deadline:
  if fn.call():return true
  await create_timer(.05).timeout
 return false
func send_pose()->void:
 if not net.active:return
 pose.serial+=1
 net.states[net.multiplayer.get_unique_id()]=pose.duplicate(true)
 net._submit_pose.rpc_id(1,net.PoseCodec.encode(pose))
func hand(at:Transform3D)->void:
 pose.right=Sites.pose(LOCATION)*at
 send_pose()
 await create_timer(.35).timeout
func item(id:int)->Dictionary:
 return net.bbq.model.stations.get(LOCATION,{}).get("items",[])[id] if net.bbq.model.stations.has(LOCATION) else {}
func finish()->void:
 sender.stop()
 print("QUEST_HOST_CLIENT_RESULT ",JSON.stringify({"role":role,"checks":checks,"failures":failures,"transport":net.multiplayer.multiplayer_peer.diagnostics() if net.active else {},"remote_states":net.state_diagnostics()}))
 net.leave();await create_timer(.2).timeout
 quit(0 if failures.is_empty() else 1)
func run()->void:
 var args:=OS.get_cmdline_user_args()
 if args.size()<3:push_error("Expected ADDRESS PORT actor|observer");quit(2);return
 role=args[2]
 var owner:=Node.new();owner.name="RealAIFishing";root.add_child(owner)
 net=preload("res://scripts/network/session.gd").new();owner.add_child(net);net.setup(owner,true)
 net.voice_enabled=false;net.metrics_enabled=true
 net.player_token=("c" if role=="actor" else "d").repeat(64);net.display_name="QuestProbe-"+role
 sender=Timer.new();sender.wait_time=.05;owner.add_child(sender);sender.timeout.connect(send_pose)
 net.join(args[0],int(args[1]))
 if not check(await until(func():return net.active and net.players.has(1)),"Quest accepts protocol handshake and includes itself in roster"):
  await finish();return
 var at:=Sites.arrival(LOCATION)
 pose={"user_height":1.78,"serial":0,"location":LOCATION,"body":{},"face":{},"visemes":PackedFloat32Array([0,0,0,0,0]),"state":0,"bait":0,"species":0,"rod_tier":0,"rig":0,"length":10.0,"curl":0.0,"reel_angle":0.0,"golf_club":-1,"golf_stowed":false}
 for key in Schema.TRANSFORMS:pose[key]=Transform3D(Basis.IDENTITY,at+Vector3(0,1.7,0))
 for key in Schema.VECTORS:pose[key]=at
 for key in ["caught","in_hand","xr","bobber_visible","bait_visible"]:pose[key]=false
 pose.left_valid=true;pose.right_valid=true
 check(Schema.valid(pose),"Probe pose follows production wire schema")
 sender.start();send_pose()
 check(await until(func():return net.states.has(1)),"Quest sends its live tracked player state")
 if role=="actor":
  check(await until(func():return net.players.size()>=3),"Quest hosts two simultaneous remote clients")
  net.bbq.request("start")
  if check(await until(func():return not item(6).is_empty()),"Quest creates authoritative shared BBQ"):
   check(await until(func():
    for id in net.players:
     if net.players[id].name=="QuestProbe-observer" and net.states.get(id,{}).get("bait",0)==1:return true
    return false),"Observer records the initial food side before flipping")
   var expected_side:int=1-int(item(0).side)
   await hand(Transform3D(Basis.IDENTITY,item(6).pos));net.bbq.request("grab",6,1)
   check(await until(func():return item(6).owner==net.multiplayer.get_unique_id()),"Quest grants tongs ownership")
   await hand(Transform3D(Basis.IDENTITY,Food.resting_pose(item(0)).origin+Vector3(0,0,.25)));net.bbq.request("clamp",0,1)
   if check(await until(func():return item(0).get("place")=="tongs"),"Quest attaches food to replicated tongs"):
    var turned:=Basis(Vector3.FORWARD,PI)
    var offset:Transform3D=item(0).grip_offset
    await hand(Transform3D(turned,Sites.grill(1)-turned*offset.origin));net.bbq.request("unclamp",0,1)
    check(await until(func():return item(0).get("place")=="grill" and item(0).side==expected_side),"Quest resolves a physical half turn on release")
    check(await until(func():return item(0).cook[expected_side]>.01),"Quest advances cooking while rendering VR")
   net.bbq.request("release")
  net.golf.request("join",{"course":"spyglass","mode":"solo"})
  check(await until(func():return not net.golf.view.is_empty()),"Quest creates remote solo golf round")
  net.golf.request("presence",{"present":true})
  if check(await until(func():return net.golf.can_shoot()),"Quest grants golf turn"):
   var epoch:int=net.golf.view.epoch
   net.golf.request("shot",{"epoch":epoch})
   check(await until(func():return net.golf.view.get("flight",false)),"Quest acknowledges stroke")
   net.golf.request("settled",{"epoch":epoch,"holed":false})
   check(await until(func():return net.golf.view.get("epoch",0)>epoch and not net.golf.view.get("flight",true)),"Quest settles stroke and advances epoch")
  net.golf.request("retire")
  check(await until(func():return net.golf.view.get("retired",false)),"Quest acknowledges retirement")
  await create_timer(6).timeout
  sender.stop();net.leave();await create_timer(1).timeout
  net.join(args[0],int(args[1]))
  check(await until(func():return net.active),"Quest accepts same-identity reconnect")
  sender.start();await create_timer(2).timeout
 else:
  check(await until(func():return net.states.size()>=3),"Quest relays remote client state to observer")
  if not check(await until(func():return not item(0).is_empty()),"Observer receives initial food state"):
   await finish();return
  var expected_side:int=1-int(item(0).side)
  pose.bait=1;send_pose()
  check(await until(func():return item(0).get("side")==expected_side,30),"Observer receives wrist-flipped food from Quest")
  check(await until(func():return item(0).cook[expected_side]>.01),"Observer sees authoritative cook progression")
  await create_timer(10).timeout
 await finish()
