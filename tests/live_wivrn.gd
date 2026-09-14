extends SceneTree
var capture_effect = preload("res://tests/xr_capture.gd").new()
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g);current_scene=g
	await create_timer(2.0).timeout
	if not g.xr:
		push_error("Live WiVRn test did not initialize OpenXR");quit(1);return
	var compositor := Compositor.new();compositor.compositor_effects=[capture_effect];g.head.compositor=compositor
	var solved_errors: Dictionary = {}
	g.avatar.solver.modification_processed.connect(func():
		var avatar = g.avatar
		var sk: Skeleton3D = avatar.skeleton
		for side in ["Left", "Right"]:
			var target: Transform3D = avatar.tracking_transform() * avatar.xr_pose[side.to_lower()]
			target.origin += target.basis.y * .06
			var wrist := sk.to_global(sk.get_bone_global_pose(sk.find_bone(side+"Hand")).origin)
			solved_errors[side+"_wrist_error_m"] = wrist.distance_to(target.origin))
	for sample in 6:
		await create_timer(2.0).timeout
		var readings: Dictionary={"focused":g.tracking_manager.focused,"head":g.tracking_manager.head_tracked(),"left":g.left.get_has_tracking_data(),"right":g.right.get_has_tracking_data(),"body":g.tracking_manager.body.keys(),"status":g.tracking_manager.tracking.status,"guide_held":g.fish_guide.held,"head_height":g.head.global_position.y-g.motor.global_position.y,"fps":Engine.get_frames_per_second()}
		if is_instance_valid(g.avatar):
			readings["avatar_height"]=g.avatar.standing_height
			readings["calibrated"]=g.tracking_manager.tracking.calibrated
			readings["left_finger_joints"]=g.tracking_manager.body.get("left_finger_rotations",{}).size()
			readings["right_finger_joints"]=g.tracking_manager.body.get("right_finger_rotations",{}).size()
			readings["body_hips"]=str(g.tracking_manager.body.get("hips"))
			readings.merge(solved_errors)
		print("LIVE_WIVRN ",JSON.stringify(readings))
	capture_effect.request_capture("live")
	for i in 240:
		await process_frame
		if capture_effect.completed=="live":break
	if capture_effect.views!=2:
		push_error("Live stereo readback failed");quit(1);return
	for eye in 2:
		var frame: Image=capture_effect.results[eye]
		frame.convert(Image.FORMAT_RGBA8);frame.linear_to_srgb()
		frame.save_png("res://test-results/vr-fixes/live-eye%d.png"%eye)
	print("LIVE_WIVRN_STEREO ",capture_effect.views," eyes captured")
	g.head.compositor=null;g.queue_free();await process_frame;await create_timer(.2).timeout
	quit(0)
