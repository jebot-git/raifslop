extends SceneTree
var failures:Array=[]
var trackers:Array[XRControllerTracker]=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,message:String)->void:
	if not ok:failures.append(message);push_error(message)
func settle()->void:
	for i in 4:await process_frame
func run()->void:
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await create_timer(.5).timeout
	game.set_process(false);game.motor.set_physics_process(false)
	for hand in 2:
		var tracker:=XRControllerTracker.new();tracker.name="minigolf_walk_%d"%hand;XRServer.add_tracker(tracker);trackers.append(tracker)
		var controller:XRController3D=game.left if hand==0 else game.right;controller.tracker=tracker.name;controller.pose="grip"
		tracker.set_pose("grip",Transform3D(Basis.IDENTITY,Vector3(-.3 if hand==0 else .3,1.2,-.4)),Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	await settle()
	game.xr=true;game.motor.xr=true;game.motor.tracking_focused=true;game.tracking_manager.focused=true;game.tracking_manager.calibration_pending=false;game.tracking_manager.startup_settle_frames=0
	var activity=game.golf_activity;activity.enter(game.current_location);await settle()
	var motor=game.motor;motor.blocked=false;motor.catch_controls=false;motor.turn_reserved=false
	for hand in 2:
		activity.left_handed=hand==0;activity.support_hand.automatic=false
		for input in ["grip","grip_click"]:
			trackers[hand].set_input(input,true if input=="grip_click" else 1.0)
			trackers[0].set_input("primary",Vector2(.8,.8));trackers[1].set_input("primary",Vector2(.8,0))
			motor.velocity=Vector3.ZERO;motor.turn_latched=false
			var before:Basis=game.origin.global_basis;motor._physics_process(.016)
			check(Vector2(motor.velocity.x,motor.velocity.z).length()<.001 and game.origin.global_basis.is_equal_approx(before),"Grip locks two-controller movement: %s, hand %d"%[input,hand])
			trackers[hand].set_input(input,false if input=="grip_click" else 0.0)
			for tracker in trackers:tracker.set_input("primary",Vector2.ZERO)
			motor._physics_process(.016)
			trackers[0].set_input("primary",Vector2(.8,.8));trackers[1].set_input("primary",Vector2(.8,0))
			motor.turn_latched=false;before=game.origin.global_basis;motor._physics_process(.016)
			check(not motor.stick_release_pending and Vector2(motor.velocity.x,motor.velocity.z).length()>.01 and not game.origin.global_basis.is_equal_approx(before),"Release and neutral restore two-controller walking and turning")
		for tracker in trackers:tracker.set_input("primary",Vector2.ZERO)
		var other:=1-hand;trackers[other].invalidate_pose("grip");await settle()
		trackers[hand].set_input("grip",1.0);trackers[hand].set_input("primary",Vector2(.8,.8))
		motor.turn_latched=false;var before:Basis=game.origin.global_basis;motor._physics_process(.016)
		check(Vector2(motor.velocity.x,motor.velocity.z).length()<.001 and game.origin.global_basis.is_equal_approx(before),"Grip locks single-controller movement: "+str(hand))
		trackers[hand].set_input("grip",0.0);trackers[hand].set_input("primary",Vector2.ZERO);motor._physics_process(.016)
		trackers[hand].set_input("primary",Vector2(0,1));motor._physics_process(.016)
		check(Vector2(motor.velocity.x,motor.velocity.z).length()>.01,"Single-controller walking after release: "+str(hand))
		motor.turn_latched=false;before=game.origin.global_basis
		trackers[hand].set_input("primary",Vector2(1,0));motor._physics_process(.016)
		check(not game.origin.global_basis.is_equal_approx(before),"Single-controller turning after release: "+str(hand))
		trackers[hand].set_input("primary",Vector2.ZERO)
		trackers[other].set_pose("grip",Transform3D(Basis.IDENTITY,Vector3(-.3 if other==0 else .3,1.2,-.4)),Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);await settle()
	activity.leave()
	check(not motor.stick_lock.is_valid() and not motor.stick_release_pending,"Leaving minigolf restores fishing movement")
	for tracker in trackers:XRServer.remove_tracker(tracker)
	game.ambience.stop();game.queue_free();await settle();await create_timer(.3).timeout
	print("MINIGOLF_LOCOMOTION_RESULT ",failures);quit(0 if failures.is_empty() else 1)
