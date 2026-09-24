extends SceneTree
var failures: Array = []
var trackers: Array[XRControllerTracker] = []
var g
var hand := Vector3(.25, 1.3, -.3)
func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures.append(label)
func _initialize() -> void: run.call_deferred()
func move_hand(z: float) -> void:
	await move_controller(Vector3(0, 0, z))
func move_controller(movement: Vector3) -> void:
	hand += movement
	trackers[1].set_pose("grip", Transform3D(Basis.IDENTITY, hand), Vector3.ZERO, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	for i in 2: await process_frame
	g._process(.05)
func controller_cast(step: float, look: Vector3, direction := Vector3.FORWARD, lift := false) -> Vector3:
	g.game.reset(); hand = Vector3(.25, 1.3, -.3)
	g.head.rotation = look
	for i in 8: await move_hand(0)
	trackers[1].set_input("trigger_click", true)
	if lift:
		for i in 4: await move_controller(Vector3(.06,.08,0))
	for i in 4: await move_controller(-direction * step)
	for i in 5: await move_controller(direction * step)
	var target: Vector3 = g._projected_cast_target()
	var offset: Vector3 = target - g.cast_aim_anchor
	check(offset.is_finite() and offset.normalized().dot(direction) > .999, "Controller swing sets heading independently of head and rod facing")
	g.cast_pose_sampler.previous.origin += Vector3(0, 0, 100); g._sample_cast_swing(.05)
	g.cast_pose_sampler.previous.origin += Vector3(0, 0, 1); g._sample_cast_swing(.2)
	check(g._projected_cast_target().is_equal_approx(target), "Tracking jumps and frame hitches cannot change controller cast power or direction")
	g.head.rotation = Vector3(.5, -2, 0)
	for i in 10: await move_hand(0)
	check(g._projected_cast_target().is_equal_approx(target), "Looking away and holding trigger cannot change swing direction or distance")
	g._update_line()
	check(g.aim_marker.visible and g.aim_marker.global_position.is_equal_approx(target), "Controller swing preview shows the release destination")
	trackers[1].set_input("trigger_click", false)
	check(g.game.state == g.Session.State.CASTING and g.cast_target.is_equal_approx(target), "Controller-only release lands at the swing destination")
	return offset
func wrist_cast(head_aim:bool,yaw:float,start_pitch:=PI*.5):
	g.game.reset();g.head_aimed_casting=head_aim;g.head.rotation=Vector3(.25,0,0)
	var grip:Transform3D=Transform3D(Basis(Vector3.UP,yaw)*Basis(Vector3.RIGHT,start_pitch),Vector3(.25,1.3,-.3))*g.rod_holster.HELD_POSE.affine_inverse()
	trackers[1].set_pose("grip",grip,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	for i in 8:await process_frame
	g._process(.05);trackers[1].set_input("trigger_click",true)
	for pitch in ([1.75,1.95,2.15,2.3,2.1,1.85,1.55,1.2,.85,.5,.25] if start_pitch<2 else [2.6,2.7,2.8,2.7,2.5,2.3,2.0,1.6,1.2,.8,.4]):
		grip=Transform3D(Basis(Vector3.UP,yaw)*Basis(Vector3.RIGHT,pitch),Vector3(.25,1.3,-.3))*g.rod_holster.HELD_POSE.affine_inverse()
		trackers[1].set_pose("grip",grip,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
		for i in 2:await process_frame
		g._process(.05)
	check(g.game.fly.strokes>0,"Overhand wrist arc starting vertical completes a cast (%s)"%head_aim)
	var target:Vector3=g._projected_cast_target()
	if not head_aim:
		var direction:=Vector3(target.x-g.cast_aim_anchor.x,0,target.z-g.cast_aim_anchor.z).normalized()
		check(direction.dot(Basis(Vector3.UP,yaw)*Vector3.FORWARD)>.98,"Vertical-start motion cast follows controller swing yaw")
	trackers[1].set_input("trigger_click",false)
	check(g.game.state==g.Session.State.CASTING,"Overhand cast releases successfully while gaze started above horizon (%s)"%head_aim)
	g.game.reset()

func run() -> void:
	g = load("res://scenes/main.tscn").instantiate(); root.add_child(g)
	await create_timer(.4).timeout
	g.set_process(false); g.motor.set_physics_process(false); g.fishing_feedback.set_process(false)
	g._select_location("lakeside", false); g.game.reset()
	# Explicit synthetic HMD pose; client startup no longer invents a desktop eye height.
	g.head.position = Vector3(0,1.65,.65)
	g.head.rotation.x = -.15
	for side in 2:
		var tracker := XRControllerTracker.new(); tracker.name = "casting_test_" + str(side)
		XRServer.add_tracker(tracker); trackers.append(tracker)
		var controller: XRController3D = g.left if side == 0 else g.right
		controller.tracker = tracker.name; controller.pose = "grip"
		tracker.set_input("grip", 0.0); tracker.set_input("primary", Vector2.ZERO); tracker.set_input("trigger_click", false)
		tracker.set_pose("grip", Transform3D(Basis.IDENTITY, Vector3(-.3, 1.2, -.3) if side == 0 else hand), Vector3.ZERO, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	for i in 3: await process_frame
	g.xr = true; g.tracking_manager.focused = true
	g.rod.reparent(g.right); g.rod.top_level = true
	for i in 8: await move_hand(0)
	check(g.left.get_has_tracking_data() and g.right.get_has_tracking_data(), "Synthetic controller poses are tracked")
	trackers[1].set_input("trigger_click", true)
	for i in 5: await move_hand(0)
	trackers[1].set_input("trigger_click", false)
	check(g.game.state == 0, "Stationary trigger press/release does not cast")
	trackers[1].set_input("trigger_click", true)
	for i in 4: await move_hand(-.08)
	trackers[1].set_input("trigger_click", false)
	check(g.game.state == 0, "Forward-only tracked movement does not bypass the backswing")
	var target: Vector3 = g._projected_cast_target()
	trackers[1].set_input("trigger_click", true)
	g.head.rotation.x = -.3; g.head.rotation.y = .2
	g._update_line()
	check(g.aim_marker.global_position.is_equal_approx(target), "Trigger locks marker despite head movement")
	for i in 4: await move_hand(.08)
	for i in 5: await move_hand(-.08)
	check(g.game.fly.strokes > 0, "Actual origin-local rod-tip motion registers back/forward swing")
	check(g._projected_cast_target().is_equal_approx(target), "Marker remains fixed through tracked rod swing")
	var accepted: int = g.game.fly.strokes
	g._sample_cast_swing(.2)
	g.cast_pose_sampler.previous.origin += Vector3(0, 0, 1.5); g._sample_cast_swing(.014)
	check(g.game.fly.strokes == accepted, "Follow-through discontinuities and frame hitches cannot erase a completed swing")
	trackers[1].set_input("trigger_click", false)
	check(g.game.state == 1 and g.cast_target.is_equal_approx(target), "Tracked trigger release lands at the projected water target")
	g.game.reset()
	check(not g._projected_cast_target().is_equal_approx(target), "Release unlocks aim for the next cast")
	trackers[1].set_input("trigger_click", true)
	g.origin.position.x += .2; g._process(.05)
	trackers[1].set_input("trigger_click", false)
	check(g.game.state == 0, "Locomotion cannot count as a casting swing")
	for i in 8: await move_hand(0)
	trackers[0].invalidate_pose("grip")
	trackers[1].set_input("trigger_click",true)
	for i in 4: await move_hand(.08)
	for i in 5: await move_hand(-.08)
	check(g.casting and g.game.fly.strokes>0,"Occluded offhand does not cancel right-hand casting")
	trackers[1].set_input("trigger_click",false)
	check(g.game.state==1,"Right hand can release a completed cast while offhand is occluded")
	g.game.reset()
	trackers[0].set_pose("grip",Transform3D(Basis.IDENTITY,Vector3(-.3,1.2,-.3)),Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	# Release consumes the latest tracked pose even before a process sample.
	for aimed in [true,false]:
		g.head_aimed_casting=aimed;g.game.reset()
		for i in 3:await move_hand(0)
		trackers[1].set_input("trigger_click",true)
		await move_hand(.12)
		await move_hand(-.055)
		check(g.game.fly.strokes==0,"Partial forward stroke awaits release-frame motion")
		hand.z-=.065
		trackers[1].set_pose("grip",Transform3D(Basis.IDENTITY,hand),Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
		for i in 2:await process_frame
		g.cast_sample_us=Time.get_ticks_usec()-20000
		trackers[1].set_input("trigger_click",false)
		check(g.game.state==g.Session.State.CASTING,"Release-frame controller movement completes cast: "+str(aimed))
		g.game.reset()
	g.head_aimed_casting=true
	# Controller rotation drives a long, fast tip arc without a hand teleport.
	var base_pose:=Transform3D(Basis.IDENTITY,Vector3(.25,1.3,-.3))
	trackers[1].set_pose("grip",base_pose*g.rod_holster.HELD_POSE.affine_inverse(),Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	for i in 2:await process_frame
	g._begin_cast()
	for pitch in [1.0,0.0]:
		trackers[1].set_pose("grip",Transform3D(Basis(Vector3.RIGHT,pitch),base_pose.origin)*g.rod_holster.HELD_POSE.affine_inverse(),Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
		for i in 2:await process_frame
		g._sample_cast_swing(1.0/30)
	check(g.game.fly.strokes>0,"Fast wrist-driven rod-tip travel remains castable at 30 FPS")
	g.casting=false;g.game.reset()
	for input in ["grip", "trigger"]:
		g.fish_guide.grip_was_down=true
		var near_reel: Vector3=g.origin.to_local(g.rod.to_global(g.crank.position+Vector3(-.035,.08,0)))
		trackers[0].set_pose("grip",Transform3D(Basis.IDENTITY,near_reel),Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
		trackers[0].set_input(input,1.0)
		for i in 3:await process_frame
		g._process(.016)
		check(g.reel_tracker.engaged,"Left " + input + " grabs nearby reel")
		check(g.avatar.left_target==g.reel_hand_target and g.reel_hand_target.global_position.distance_to(g.crank.to_global(Vector3(-.035,.08,0)))<.001,"Offhand snaps to the actual crank handle")
		var still_angle: float=g.crank.rotation.x
		g._process(.016)
		check(is_equal_approx(g.crank.rotation.x,still_angle),"Visual snap cannot generate free reeling")
		trackers[0].set_input(input,0.0);await process_frame;g._process(.016)
		check(not g.reel_tracker.engaged and g.avatar.left_target==g.calibrated_hands[0],"Releasing " + input + " returns offhand to tracked pose")
	g.head_aimed_casting = false
	var slow := await controller_cast(.025, Vector3(.6, 2, 0))
	var same := await controller_cast(.025, Vector3(-.8, -1, 0))
	check(slow.is_equal_approx(same), "Identical controller swings land identically with different initial head poses")
	var lifted := await controller_cast(.025, Vector3(.4, 1.5, 0), Vector3.FORWARD, true)
	check(lifted.is_equal_approx(slow), "Sideways raising motion cannot redirect the cast right or add launch power")
	var fast := await controller_cast(.15, Vector3.ZERO, Vector3(.3, 0, -1).normalized())
	check(fast.length() > slow.length() + 2.0, "Faster controller swing casts farther")
	g.game.reset()
	trackers[1].set_input("trigger_click", true)
	for i in 4: await move_hand(0)
	trackers[1].set_input("trigger_click", false)
	check(g.game.state == g.Session.State.READY, "Stationary controller-only trigger release cannot cast")
	trackers[1].set_input("trigger_click", true)
	for i in 6: await move_hand(-.05)
	trackers[1].set_input("trigger_click", false)
	check(g.game.state == g.Session.State.READY, "Controller-only mode still requires a backswing")
	g._update_line()
	check(not g.aim_marker.visible, "Controller-only mode has no head-driven idle marker")
	g.head_aimed_casting = true
	# A physical hook-setting lift must also fail during feeder nibbles.
	g.game.reset();g._select_rig(1);await move_hand(0)
	for during_bite in [false,true]:
		g.game.reset();g.game.cast(12);g.game.tick(.81,0,0)
		g.game.timer=100;g.game.tick(g.game.feeder.settle_time,0,0)
		g.game.timer=0;g.game.tick(.02,0,0)
		if during_bite:
			for i in 120:
				if g.game.state==g.Session.State.BITE:break
				g.game.tick(.05,0,0)
		await move_hand(0)
		hand.y+=.12;await move_hand(0)
		check(g.game.state==(g.Session.State.FIGHT if during_bite else g.Session.State.LOST),"Tracked rod lift hooks only the actual feeder bite" if during_bite else "Tracked rod lift during feeder nibbles loses the cast")
	await wrist_cast(false,0.0)
	await wrist_cast(false,.4)
	await wrist_cast(true,0.0)
	await wrist_cast(false,.4,2.5)
	await wrist_cast(true,0,2.5)
	for tracker in trackers: XRServer.remove_tracker(tracker)
	g.queue_free(); await process_frame; await create_timer(.3).timeout
	print("TRACKED_CAST_RESULT ", failures); quit(0 if failures.is_empty() else 1)
