extends SceneTree
var failures: Array = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures.append(label)
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await create_timer(1.0).timeout
	var deadline := Time.get_ticks_msec() + 30000
	while game.avatar_loading and Time.get_ticks_msec() < deadline:
		await process_frame
	await process_frame
	await process_frame
	game.set_process(false)
	game.motor.set_physics_process(false)
	if "--native-xr" in OS.get_cmdline_user_args():
		check(game.xr and game.xr_view != null, "PC VR creates a headset viewport")
		if not game.xr or game.xr_view == null:
			quit(1)
			return
		check(game.head.get_viewport().use_xr and not root.use_xr, "Stereo headset and mono window are independent")
		check(game.xr_view.get_camera_3d() == game.head, "Headset retains tracked camera")
		check(root.get_camera_3d() == game.spectator.camera, "Window renders spectator camera")
		check(game.xr_view.world_3d == game.get_world_3d(), "Both views share gameplay world")
		check(game.xr_view.audio_listener_enable_3d and not root.audio_listener_enable_3d, "Spatial audio stays with headset")
		var capture = preload("res://tests/xr_capture.gd").new()
		var compositor := Compositor.new()
		compositor.compositor_effects = [capture]
		game.head.compositor = compositor
		capture.request_capture("spectator")
		for i in 180:
			await process_frame
			if capture.completed == "spectator": break
		check(capture.views == 2 and capture.results.size() == 2, "Headset still renders two native eye images")
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://test-results")
		root.get_texture().get_image().save_png("res://test-results/spectator_desktop.png")
	else:
		check(not game.xr and game.spectator == null and game.xr_view == null, "Desktop play allocates no spectator or stereo viewport")
		check(root.get_camera_3d() == game.head, "Desktop play retains first-person camera")
		game.spectator = preload("res://scripts/spectator_camera.gd").new()
		game.add_child(game.spectator)
		game.spectator.setup(game)
	var spectator = game.spectator
	game.fishing_feedback.update_feeding_ripples()
	for ripple in game.fishing_feedback.feeding_surfaces:
		check(ripple.layers & spectator.camera.cull_mask == 0 and ripple.layers & game.head.cull_mask != 0, "Feeding indicator stays in player view and out of stream")
	check(game.fishing_feedback.surface.layers & spectator.camera.cull_mask != 0, "Actual fish wakes remain visible in stream")
	spectator.set_physics_process(false)
	# Move clear of location scenery for deterministic geometry checks.
	game.motor.global_position = Vector3(0, 100, 0)
	game.origin.rotation = Vector3.ZERO
	spectator.update_pose(1.0 / 90)
	var initial: Transform3D = spectator.camera.global_transform
	var head_pose: Transform3D = game.head.transform
	check(spectator.camera.cull_mask == 5, "Streaming view includes full avatar without duplicate first-person mesh")
	game.head.rotation = Vector3(.5, .8, .3)
	spectator.update_pose(1.0 / 90)
	check(spectator.camera.global_transform.is_equal_approx(initial), "Head turns and tilt do not shake streaming camera")
	game.head.transform = head_pose
	game.motor.position.x += 1
	spectator.update_pose(1.0 / 90)
	check(spectator.camera.global_position.x > initial.origin.x and spectator.camera.global_position.x < initial.origin.x + 1, "Walking is smoothed")
	game.motor.position.x += 50
	spectator.update_pose(1.0 / 90)
	var target: Vector3 = game.head.global_position - Vector3.UP * .35
	check(spectator.anchor.distance_to(target) < .001, "Teleport resets follow immediately")
	var wall := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(5, 5, .2)
	collision.shape = box
	wall.add_child(collision)
	game.add_child(wall)
	wall.global_position = target + Vector3(0, 0, 1.5)
	await physics_frame
	await physics_frame
	# Runtime tracking may update between frames; compare within this update.
	head_pose = game.head.transform
	spectator.update_pose(1.0 / 90)
	check(spectator.camera.global_position.z < wall.global_position.z - .1, "Obstacle pulls camera in front of wall")
	check(game.head.transform.is_equal_approx(head_pose), "Spectator never modifies headset pose")
	game.queue_free()
	await process_frame
	await create_timer(.3).timeout
	print("SPECTATOR_RESULT ", failures)
	quit(0 if failures.is_empty() else 1)
