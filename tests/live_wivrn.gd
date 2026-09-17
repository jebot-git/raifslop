extends SceneTree
var capture_effect = preload("res://tests/xr_capture.gd").new()
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g);current_scene=g
	await create_timer(2.0).timeout
	if not g.xr:
		push_error("Live WiVRn test did not initialize OpenXR");quit(1);return
	DirAccess.make_dir_recursive_absolute("res://test-results/vr-fixes")
	for frame in 600:
		if is_instance_valid(g.avatar) and not g.avatar_loading:break
		await process_frame
	if not is_instance_valid(g.avatar):quit(1);return
	var compositor := Compositor.new();compositor.compositor_effects=[capture_effect];g.head.compositor=compositor
	var solved_errors: Dictionary = {}
	var record_pose:=func():
		var avatar = g.avatar
		var sk: Skeleton3D = avatar.skeleton
		solved_errors["viewpoint_error_m"] = avatar.viewpoint_position().distance_to(g.head.global_position)
		solved_errors["finite_pose"] = true
		for index in sk.get_bone_count():
			if not sk.get_bone_global_pose(index).is_finite():solved_errors["finite_pose"] = false
		for side in ["Left", "Right"]:
			var key:String=side.to_lower()
			var body:Dictionary=avatar.xr_pose.get("body",{})
			var controller:XRController3D=g.left if side=="Left" else g.right
			if not body.has(key+"_hand") and not controller.get_has_tracking_data():
				solved_errors[side+"_wrist_error_m"]=null;continue
			var target:Transform3D=avatar.tracking_transform()*body[key+"_hand"] if body.has(key+"_hand") else avatar.tracking_transform()*avatar.xr_pose[key]
			if not body.has(key+"_hand"):target.origin+=target.basis.y*.06
			var wrist := sk.to_global(sk.get_bone_global_pose(sk.find_bone(side+"Hand")).origin)
			solved_errors[side+"_wrist_error_m"] = wrist.distance_to(target.origin)
	var observed_avatar:Node3D=g.avatar
	observed_avatar.solver.modification_processed.connect(record_pose)
	var selfie_test:bool="--selfie" in OS.get_cmdline_user_args()
	if selfie_test:
		g.fish_guide.photo_camera.active=true;g.fish_guide.photo_camera.selfie=true
		print("LIVE_SELFIE_READY: grab guide at left hip; right stick up/down extends/retracts; right trigger saves")
	for sample in (60 if selfie_test else 6):
		await create_timer(2.0).timeout
		if is_instance_valid(g.avatar) and g.avatar!=observed_avatar:
			observed_avatar=g.avatar
			solved_errors.clear()
			observed_avatar.solver.modification_processed.connect(record_pose)
			await process_frame
		var readings: Dictionary={"focused":g.tracking_manager.focused,"head":g.tracking_manager.head_tracked(),"left":g.left.get_has_tracking_data(),"right":g.right.get_has_tracking_data(),"body":g.tracking_manager.body.keys(),"status":g.tracking_manager.tracking.status,"guide_held":g.fish_guide.held,"head_height":g.head.global_position.y-g.motor.global_position.y,"fps":Engine.get_frames_per_second()}
		if is_instance_valid(g.avatar):
			readings["avatar_height"]=g.avatar.standing_height
			readings["calibrated"]=g.tracking_manager.tracking.calibrated
			readings["left_finger_joints"]=g.tracking_manager.body.get("left_finger_rotations",{}).size()
			readings["right_finger_joints"]=g.tracking_manager.body.get("right_finger_rotations",{}).size()
			readings["body_hips"]=str(g.tracking_manager.body.get("hips"))
			readings.merge(solved_errors)
		if selfie_test:
			readings["selfie"]=g.fish_guide.photo_camera.selfie
			readings["extension_m"]=g.fish_guide.photo_camera.selfie_extension
			readings["effective_extension_m"]=g.fish_guide.photo_camera.effective_extension
			readings["right_stick_y"]=g.right.get_vector2("primary").y if g.right.get_has_tracking_data() else 0
			readings["photo"]=g.fish_guide.photo_camera.last_path
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
