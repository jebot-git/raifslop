extends SceneTree
const Net=preload("res://scripts/network/session.gd")
var failures:=0
var checks:=0
var net:Node
func check(ok:bool,label:String)->void:
 checks+=1;print("PASS " if ok else "FAIL ",label)
 if not ok:failures+=1
func until(test:Callable,seconds:=20.0)->bool:
 var end:=Time.get_ticks_msec()+seconds*1000
 while Time.get_ticks_msec()<end:
  if test.call():return true
  await create_timer(.05).timeout
 return false
func _initialize()->void:run.call_deferred()
func pose(location:String,serial:int)->void:
 var at:Vector3=preload("res://scripts/bbq/sites.gd").arrival(location)
 var data:Dictionary={"serial":serial,"location":location,"body":{},"face":{},"visemes":PackedFloat32Array([0,0,0,0,0]),"state":0,"bait":0,"species":0,"rod_tier":0,"rig":0,"length":10.0,"curl":0.0,"reel_angle":0.0,"golf_club":0,"golf_stowed":true}
 for key in Net.State.TRANSFORMS:data[key]=Transform3D(Basis.IDENTITY,at+Vector3.UP*1.7)
 for key in Net.State.VECTORS:data[key]=at
 for key in ["caught","in_hand","xr","bobber_visible","bait_visible"]:data[key]=false
 data.left_valid=true;data.right_valid=true
 check(Net.State.valid(data),"Mapped activity state validates")
 net.states[net.multiplayer.get_unique_id()]=data;net._submit_event.rpc_id(1,data)
func run()->void:
 var args:=OS.get_cmdline_user_args();var role:String=args[0];var verify:=role=="verify"
 var owner:=Node.new();owner.name="RealAIFishing";root.add_child(owner)
 net=Net.new();owner.add_child(net);net.setup(owner,true);net.voice_enabled=false
 net.player_token=("a" if role in ["A","verify"] else "b").repeat(64);net.display_name=role
 net.join("127.0.0.1",int(args[1]))
 check(await until(func():return net.active and not net.golf.board.is_empty()),"Exported server handshake and golf hook")
 if verify:
  check(await until(func():return net.golf.board.spyglass.size()==2),"Golf rankings survive exported server restart")
  check(net.golf.board.spyglass.all(func(r):return r.best==18 and r.rounds==1),"Both full scorecards persist exactly once")
 else:
  net.golf.request("join",{"course":"spyglass"})
  check(await until(func():return not net.golf.view.is_empty() and net.golf.view.roster.size()==2),"Two identities join one dedicated golf game")
  pose("golf_spyglass_clubhouse" if role=="B" else "golf_spyglass_05",1)
  check(await until(func():return net.states.size()==2),"Course poses replicated across holes and clubhouse")
  check(net.same_location(net.states.keys()[0],net.states.keys()[1]),"Dedicated server and client share course visibility domain")
  if role=="B":
   net.bbq.request("start")
   check(await until(func():return net.bbq.model.stations.has("golf_spyglass_clubhouse")),"Exported server resolves terrain-backed clubhouse BBQ")
   net.bbq.request("grab",6,1)
   check(await until(func():return net.bbq.model.stations.golf_spyglass_clubhouse.items[6].owner==net.multiplayer.get_unique_id()),"Dedicated server grants tongs ownership")
   net.bbq.request("release")
  else:
   var rejected:Array=[]
   net.golf.result.connect(func(action,accepted):
    if action=="shot" and not accepted:rejected.append(true))
   net.golf.request("shot",{"epoch":[]})
   check(await until(func():return not rejected.is_empty()),"Malformed golf command rejected without stopping server")
  net.golf.request("presence",{"present":true})
  var deadline:=Time.get_ticks_msec()+60000
  var last_epoch:=-1
  while Time.get_ticks_msec()<deadline and not net.golf.view.get("finished",false):
   if net.golf.can_shoot() and int(net.golf.view.epoch)!=last_epoch:
    last_epoch=int(net.golf.view.epoch);net.golf.request("shot",{"epoch":last_epoch})
    if await until(func():return net.golf.view.get("flight",false),3):
     await create_timer(.15).timeout
     net.golf.request("settled",{"epoch":last_epoch,"holed":true})
   await create_timer(.18).timeout
  check(net.golf.view.get("finished",false) and net.golf.view.scores.size()==18,"Dedicated hooks complete all 18 turns and holes")
  check(await until(func():return net.golf.board.spyglass.size()==2),"Completed golf scorecards published to both clients")
  net.golf.request("retire")
  check(await until(func():return net.golf.view.get("retired",false)),"Retirement works on exported server")
  await create_timer(.6).timeout
 net.leave();owner.queue_free();await process_frame
 print("GOLF_DEDICATED_RESULT ",role," ",checks-failures,"/",checks);quit(0 if failures==0 else 1)
