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
	hand.z += z
	trackers[1].set_pose("grip", Transform3D(Basis.IDENTITY, hand), Vector3.ZERO, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	for i in 2: await process_frame
	g._process(.05)
func run() -> void:
	g = load("res://scenes/main.tscn").instantiate(); root.add_child(g)
	await create_timer(.4).timeout
	g.set_process(false); g.motor.set_physics_process(false); g.fishing_feedback.set_process(false)
	g._select_location("lakeside", false); g.game.reset()
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
	g.cast_last_tip += Vector3(0, 0, 1.5); g._sample_cast_swing(.014)
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
	for input in ["grip", "trigger"]:
		g.fish_guide.grip_was_down=true
		var near_reel: Vector3=g.origin.to_local(g.rod.to_global(g.crank.position+Vector3(-.035,.08,0)))
		trackers[0].set_pose("grip",Transform3D(Basis.IDENTITY,near_reel),Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
		trackers[0].set_input(input,1.0)
		for i in 3:await process_frame
		g._process(.016)
		check(g.reel_tracker.engaged,"Left " + input + " grabs nearby reel")
		check(g.avatar.left_target==g.desktop_left and g.desktop_left.global_position.distance_to(g.crank.to_global(Vector3(-.035,.08,0)))<.001,"Offhand snaps to the actual crank handle")
		var still_angle: float=g.crank.rotation.x
		g._process(.016)
		check(is_equal_approx(g.crank.rotation.x,still_angle),"Visual snap cannot generate free reeling")
		trackers[0].set_input(input,0.0);await process_frame;g._process(.016)
		check(not g.reel_tracker.engaged and g.avatar.left_target==g.calibrated_hands[0],"Releasing " + input + " returns offhand to tracked pose")
	for tracker in trackers: XRServer.remove_tracker(tracker)
	g.queue_free(); await process_frame; await create_timer(.3).timeout
	print("TRACKED_CAST_RESULT ", failures); quit(0 if failures.is_empty() else 1)
