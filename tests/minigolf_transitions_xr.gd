extends SceneTree
var game
var failures:Array=[]
var controllers:Array[XRControllerTracker]=[]
var capture=preload("res://tests/xr_capture.gd").new()
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func snap(label:String)->void:
 await create_timer(.5).timeout
 capture.request_capture(label)
 var deadline:=Time.get_ticks_msec()+8000
 while capture.completed!=label and Time.get_ticks_msec()<deadline:await process_frame
 check(capture.completed==label and capture.results.size()==2,"Native stereo capture: "+label)
 for eye in capture.results.size():
  var frame:Image=capture.results[eye];frame.convert(Image.FORMAT_RGBA8);frame.linear_to_srgb()
  frame.save_png("res://test-results/minigolf-vr/%s-eye%d.png"%[label,eye])
func run()->void:
 DirAccess.make_dir_recursive_absolute("res://test-results/minigolf-vr")
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);current_scene=game
 await create_timer(1).timeout
 game.set_process(false);game.motor.set_physics_process(false)
 check(game.xr and game.head.get_viewport().use_xr,"Native Monado OpenXR headset is active")
 if not game.xr:quit(1);return
 for hand in ["left_hand","right_hand"]:
  var tracker:=XRControllerTracker.new();tracker.type=XRServer.TRACKER_CONTROLLER;tracker.name=hand;tracker.description="Minigolf synthetic controller"
  XRServer.add_tracker(tracker);controllers.append(tracker)
 for i in 2:
  var pose:=Transform3D(Basis.IDENTITY,Vector3(-.3 if i==0 else .3,1.15,-.45))
  for key in ["grip","aim","default"]:controllers[i].set_pose(key,pose,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
 await process_frame
 var comp:=Compositor.new();comp.compositor_effects=[capture];game.head.compositor=comp
 game.tracking_manager.sample(.016);game._update_avatar(.016)
 var water:String=game.current_location
 await snap("01-fishing")
 game.bbq.visit();await create_timer(.8).timeout
 check(game.bbq.visiting and game.current_location==water,"Fishing to BBQ keeps water identity")
 await snap("02-bbq")
 var golf=game.golf_activity;golf.enter(water);golf.update_player(.016)
 check(golf.active and not game.bbq.visiting and game.current_location==water,"BBQ to minigolf uses shared world and rig")
 check(game.motor.single_controller_controls,"One-controller locomotion retained")
 await snap("03-minigolf-arrival")
 golf.teleport_to_ball();golf.update_player(.016)
 var stance:Vector3=game.motor.global_position
 var facing:Basis=game.motor.global_basis
 await snap("04-optional-ball-teleport")
 golf.begin_club_fit();check(game.motor.global_position.is_equal_approx(stance),"Club fitting does not position player");golf.cancel_club_fit()
 golf.load_hole(1);check(game.motor.global_position.is_equal_approx(stance) and game.motor.global_basis.is_equal_approx(facing),"Hole change preserves player position and facing")
 # Remove support controller tracking: the visual support hand must snap without moving the striking pose.
 XRServer.remove_tracker(controllers[0]);await process_frame
 var striking:Transform3D=game.right.global_transform
 for i in 12:golf.update_player(.09);await process_frame
 check(golf.support_hand.engaged,"Missing offhand snaps visually for one-hand play")
 check(game.right.global_transform.is_equal_approx(striking),"Support snap never alters striking controller")
 await snap("05-one-hand-putter")
 golf.leave();check(not golf.active and game.current_location==water,"Minigolf returns to fishing")
 await snap("06-return-fishing")
 XRServer.remove_tracker(controllers[1]);game.ambience.stop();game.queue_free();await process_frame
 print("MINIGOLF_TRANSITIONS_XR failures: ",failures);quit(0 if failures.is_empty() else 1)
