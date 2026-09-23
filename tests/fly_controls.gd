extends SceneTree
var failures:Array=[]
var g
var trackers:Array[XRControllerTracker]=[]
var hand:=Vector3(.25,1.3,-.3)
func check(ok:bool,label:String)->void:
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func pose(side:int,at:Vector3)->void:
 trackers[side].set_pose("grip",Transform3D(Basis.IDENTITY,at),Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
func settle()->void:
 for i in 3:await process_frame
 g._process(.02)
func swing()->void:
 for direction in [1,-1]:
  for i in 6:
   hand.z+=direction*.025;pose(1,hand);await settle()
func _initialize()->void:run.call_deferred()
func run()->void:
 g=load("res://scenes/main.tscn").instantiate();root.add_child(g)
 await create_timer(.4).timeout
 g.set_process(false);g.motor.set_physics_process(false);g.fishing_feedback.set_process(false)
 for side in 2:
  var t:=XRControllerTracker.new();t.name="fly_controls_"+str(side);XRServer.add_tracker(t);trackers.append(t)
  var c:XRController3D=g.left if side==0 else g.right;c.tracker=t.name;c.pose="grip"
  t.set_input("grip",0.0);t.set_input("trigger",0.0);t.set_input("primary",Vector2.ZERO);t.set_input("trigger_click",false)
  pose(side,Vector3(-.3,1.2,-.3) if side==0 else hand)
 g.xr=true;g.tracking_manager.calibration_pending=false;g.tracking_manager.focused=true
 for location in ["meadow_bend","boulder_run"]:
  g.game.reset();g._select_location(location,false);g.head.rotation=Vector3(-.25,0,0)
  for i in 8:await settle()
  for input in ["grip","trigger"]:
   g.game.reset();g.game.state=g.Session.State.BITE;g.game.fish_index=11;g.game.strike()
   g.game.jumps_enabled=false;g.game.next_cue=100;g.game.next_submerge=100;g.game.distance=20
   pose(0,g.origin.to_local(g.crank.to_global(g.rod_visual.crank_grip_position())))
   trackers[0].set_input(input,1.0);await settle()
   check(g.reel_tracker.engaged and not g.game.fly.strip_engaged,location+": "+input+" grabs fly reel without grabbing loose line")
   check(g.avatar.left_target==g.reel_hand_target and g.reel_hand_target.global_position.distance_to(g.crank.to_global(g.rod_visual.crank_grip_position()))<.001,"Offhand snaps to the smaller fly crank")
   var before:float=g.crank.rotation.x
   var raw_rod:Transform3D=g.right.transform*g.rod_holster.HELD_POSE
   var a:float=g.reel_tracker.previous_angle+.16
   pose(0,raw_rod*(g.crank.position+Vector3(-.0105,cos(a)*.039,sin(a)*.039)-g.reel_tracking_offset));await settle()
   check(absf(g.crank.rotation.x-before)>.1 and g.game.fly_reel_penalty,"Actual fly-crank motion winds and applies fighting-fish strain")
   trackers[0].set_input(input,0.0);await settle()
   check(not g.reel_tracker.engaged,"Release frees fly reel")
  g.game.reset();g.game.state=g.Session.State.WAITING;g.game.timer=20;g.game.fly.start=Vector3(0,g.water_level,-10)
  pose(0,g.origin.to_local(g.rod.to_global(Vector3(-.025,0,-.25))))
  trackers[0].set_input("grip",1.0);await settle()
  check(g.game.fly.strip_engaged and not g.reel_tracker.engaged,"Grabbing farther up the loose line still strips")
  trackers[0].set_input("grip",0.0);await settle()
  g.game.reset();g.head.rotation=Vector3(-.25,0,0);await settle()
  var base:Vector3=g._projected_cast_target()
  trackers[1].set_input("trigger_click",true);await swing()
  check(g.game.fly.strokes==1 and g.cast_aim_target.is_equal_approx(base),"First stroke preserves the locked aim point")
  await swing()
  check(g.game.fly.strokes==2 and absf(g.cast_aim_target.distance_to(base)-2.0)<.01,"Extra complete stroke extends fly cast by two metres")
  var extended:Vector3=g.cast_aim_target
  g.head.rotation.y=.15;await settle();g._update_line()
  check(g.aim_marker.global_position.is_equal_approx(extended),"Head motion cannot move the deliberately extended aim marker")
  trackers[1].set_input("trigger_click",false)
  check(g.game.state==g.Session.State.CASTING and g.cast_target.is_equal_approx(extended),"Released fly lands at the displayed extended target")
 for t in trackers:XRServer.remove_tracker(t)
 g.queue_free();await process_frame;await create_timer(.2).timeout
 print("FLY_CONTROLS_RESULT ",failures);quit(0 if failures.is_empty() else 1)
