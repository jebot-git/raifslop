extends SceneTree
const Net=preload("res://scripts/network/session.gd")
var failures:Array=[]
func check(ok:bool,label:String):
 if not ok:failures.append(label);push_error(label)
func wait_for(test:Callable,seconds:=12.0)->bool:
 var end:=Time.get_ticks_msec()+seconds*1000
 while Time.get_ticks_msec()<end:
  if test.call():return true
  await create_timer(.05).timeout
 return false
func _initialize():run.call_deferred()
func run():
 var args:=OS.get_cmdline_user_args();var role:String=args[0]
 var game:=Node.new();game.name="RealAIFishing";root.add_child(game)
 var net=Net.new();game.add_child(net);net.setup(game,true);net.load_preferences()
 net.display_name="Returning angler" if role=="return" else role
 check(net.join("127.0.0.1",int(args[1]))==OK,"Connect")
 check(await wait_for(func():return net.active and not net.leaderboard_view.is_empty()),"Handshake and server standings")
 if role=="writer":
  var d:Dictionary={"body":{},"face":{},"visemes":PackedFloat32Array([0,0,0,0,0]),"serial":0,"location":"lakeside","rod_tier":0,"rig":0,"reel_angle":0.0,"state":0,"bait":0,"species":0,"length":Net.State.Fish.SPECIES[0].length*1.14,"caught":false,"in_hand":false,"xr":false,"left_valid":true,"right_valid":true,"bobber_visible":true,"bait_visible":true,"curl":0.0}
  for key in Net.State.TRANSFORMS:d[key]=Transform3D.IDENTITY
  for key in Net.State.VECTORS:d[key]=Vector3.ZERO
  check(Net.State.valid(d),"Wire fixture validates")
  for state in [1,2,3,4,5,5,5]:
   d.serial+=1;d.state=state;d.caught=state==5
   net._submit_event.rpc_id(1,d);await create_timer(.12).timeout
 if role in ["writer","observer","return"]:
  check(await wait_for(func():return not net.leaderboard_view.is_empty() and net.leaderboard_view.categories.catches[0].catches==1),"Server retains exactly one catch")
  check(net.leaderboard_view.categories.earned[0].earned>0,"Server supplies lifetime earnings")
  check(net.leaderboard_view.categories.exceptional[0].exceptional==1,"Exceptional record visible")
  check(not FileAccess.file_exists("user://server/leaderboard.json"),"Client has no saved leaderboard")
  if role=="return":check(net.leaderboard_view.categories.catches[0].name=="Returning angler","Reconnect updates display name without duplicating totals")
 await create_timer(.5).timeout
 net.leave();game.queue_free();await process_frame
 print("LEADERBOARD_NETWORK_RESULT ",role," ",failures);quit(0 if failures.is_empty() else 1)
