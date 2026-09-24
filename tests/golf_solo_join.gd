extends SceneTree
var failures:Array=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func until(fn:Callable)->bool:
 for i in 600:
  if fn.call():return true
  await create_timer(.05).timeout
 return false
func run():
 var args:=OS.get_cmdline_user_args();var server:bool="server" in args
 var g=load("res://scenes/main.tscn").instantiate();root.add_child(g);await process_frame
 g.set_process(false);g.motor.set_physics_process(false);g.network.voice_enabled=false
 if server:
  check(g.network.host(28983,"127.0.0.1")==OK,"Solo join test server starts")
  check(await until(func():return g.network.players.size()>1),"Remote client connects")
  check(await until(func():return g.network.players.size()==1),"Remote client finishes")
 else:
  g.network.join("127.0.0.1",28983)
  if not await until(func():return g.network.active):check(false,"Client handshake");quit(1);return
  g.xr=true;g.motor.xr=true;g.motor.tracking_focused=true
  var trackers:Array=[]
  for side in 2:
   var tracker:=XRControllerTracker.new();tracker.name="solo_join_"+str(side);XRServer.add_tracker(tracker);trackers.append(tracker)
   var controller:XRController3D=g.left if side==0 else g.right;controller.tracker=tracker.name;controller.pose="grip"
   tracker.set_pose("grip",Transform3D(Basis.IDENTITY,Vector3((side*2-1)*.3,1,-.4)),Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
   tracker.set_input("grip",0.0)
  var a=g.golf_activity
  await a.join_course("spyglass")
  var golf=a.golf;golf.set_process(false);golf.set_physics_process(false);g.motor.set_physics_process(false);golf.focused=true
  # Choose solo from the actual hosted menu, as a client with delayed RPCs.
  a.open_settings("golf");a.start_play("solo")
  check(await until(func():return a.enrolled() and a.clubhouse_round==null and not a.lobby_waiting),"Remote solo join reaches tee")
  check(not golf.menu_open and not a.settings_open and not g.menu_open,"All menus close on joining solo")
  check(not golf.equipment.stowed and golf.club.visible and golf.club.get_parent()==g.right,"Club is available at first solo tee")
  golf.equipment.set_stowed(true);golf.equipment.update()
  var hip:Transform3D=golf.equipment.belt_pose
  trackers[1].set_pose("grip",Transform3D(Basis.IDENTITY,g.origin.to_local(hip.origin)),Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
  for frame in 3:await process_frame
  trackers[1].set_input("grip",0.0);golf.equipment.update()
  trackers[1].set_input("grip",1.0);golf.equipment.update()
  check(not golf.equipment.stowed and golf.club.get_parent()==g.right,"First hip grab works without rejoining")
  # The server can already retain a solo membership when a client enters
  # golf again. Activation must finish before the user can retrieve a club.
  a.leave();await process_frame
  await a.join_course("spyglass");golf=a.golf;golf.set_process(false);golf.set_physics_process(false);golf.focused=true
  check(a.menu_ready and is_instance_valid(a.course_life),"Existing server membership completes local golf activation")
  a.start_play("solo");await create_timer(.15).timeout
  check(a.clubhouse_round==null and not golf.menu_open and not golf.equipment.stowed,"Existing server solo membership resumes with usable club")
  golf.equipment.set_stowed(true);golf.equipment.update();hip=golf.equipment.belt_pose
  trackers[1].set_pose("grip",Transform3D(Basis.IDENTITY,g.origin.to_local(hip.origin)),Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
  for frame in 3:await process_frame
  trackers[1].set_input("grip",0.0);golf.equipment.update()
  trackers[1].set_input("grip",1.0);golf.equipment.update()
  check(not golf.equipment.stowed,"Retained server membership allows first hip grab")
  # A grip click can be delivered without an analog squeeze value.
  trackers[1].set_input("grip",0.0);golf.equipment.set_stowed(true);golf.equipment.update()
  trackers[1].set_input("grip_click",true);golf.equipment.update()
  check(not golf.equipment.stowed,"Digital grip retrieves the visible hip club")
  trackers[1].set_input("grip_click",false);golf.equipment.update()
  # Both controllers stay tracked, but the player holds the nonpreferred one.
  golf.equipment.set_stowed(true);golf.equipment.update();hip=golf.equipment.belt_pose
  trackers[0].set_pose("grip",Transform3D(Basis.IDENTITY,g.origin.to_local(hip.origin)),Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
  for frame in 3:await process_frame
  trackers[0].set_input("grip",0.0);golf.equipment.update()
  trackers[0].set_input("grip",1.0);golf.equipment.update()
  check(not golf.equipment.stowed and golf.left_handed and golf.club.get_parent()==g.left,"Either hand retrieves the visible hip club and becomes swing hand")
  for tracker in trackers:XRServer.remove_tracker(tracker)
  a.retire();await create_timer(.3).timeout
 g.network.leave();g.queue_free();await process_frame
 print("GOLF_SOLO_JOIN_RESULT ",failures);quit(0 if failures.is_empty() else 1)
