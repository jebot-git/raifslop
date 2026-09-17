extends SceneTree
const Photo = preload("res://scripts/guide_camera.gd")
var failures: Array = []
var checks := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures.append(label)
func _initialize() -> void: run.call_deferred()
func key(game, code: Key) -> void:
	var event := InputEventKey.new(); event.pressed = true; event.keycode = code
	game._unhandled_input(event)
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	await create_timer(.3).timeout
	game.set_process(false); game.motor.set_physics_process(false)
	var guide = game.fish_guide
	var photo = guide.photo_camera
	check(is_instance_valid(photo.camera) and photo.view.render_target_update_mode == SubViewport.UPDATE_DISABLED, "Camera allocates no ongoing render while inactive")
	key(game, KEY_G); key(game, KEY_C)
	check(guide.held and photo.active, "Guide keyboard shortcut opens camera")
	photo.update_pose()
	check(photo.camera.global_transform.is_equal_approx(game.head.global_transform), "Desktop lens follows center of viewpoint")
	check(photo.camera.cull_mask & Photo.UI_LAYER == 0 and game.head.cull_mask & Photo.UI_LAYER != 0, "Photo hides UI layer while player view retains it")
	check(guide.device.find_children("*", "MeshInstance3D", true, false).all(func(n): return n.layers == Photo.UI_LAYER), "Entire guide excluded from photo to prevent recursive screens")
	check(photo.view.world_3d == game.get_world_3d() and photo.view.get_parent() != game.hud.get_parent(), "Photo shares scenery but has no main HUD canvas")
	key(game, KEY_F)
	check(photo.selfie and photo.camera.cull_mask == 5, "Selfie includes complete avatar layer")
	var target: Vector3 = game.head.global_position - Vector3.UP * .3
	check((-photo.camera.global_basis.z).dot((target-photo.camera.global_position).normalized()) > .99, "Selfie lens faces angler")
	var previous: int = game.game.state
	if DisplayServer.get_name() == "headless":
		key(game, KEY_SPACE)
		check(not photo.busy and photo.status.contains("renderer"), "Unavailable renderer reports failure without becoming stuck")
	check(game.game.state == previous, "Camera shutter never casts or releases fish")
	key(game, KEY_C); key(game, KEY_C)
	game.xr = true
	game.left.global_transform = Transform3D(Basis.from_euler(Vector3(.1, .4, 0)), game.head.global_position + Vector3(-.3, -.2, -.3))
	photo.selfie = false; photo.update_pose()
	guide.global_transform = game.left.global_transform * Transform3D(guide.GRIP_BASIS, guide.GRIP_OFFSET)
	photo.update_pose()
	check(photo.camera.global_transform.is_equal_approx(guide.global_transform * Photo.lens_pose(false)), "VR rear lens stays on guide rear face")
	check((-photo.camera.global_basis.z).dot(-guide.global_basis.z) > .999, "Rear lens looks perpendicular to screen, not along handle")
	photo.selfie = true; photo.update_pose()
	check(photo.camera.global_transform.is_equal_approx(guide.global_transform * Photo.lens_pose(true)), "VR selfie lens stays on guide front face")
	check((-photo.camera.global_basis.z).dot(guide.global_basis.z) > .999, "Selfie lens looks outward from front screen")
	# A front lens reverses its optical axis, never the tracked translation.
	# Exercise combined yaw/pitch/roll, including near vertical orientations.
	for angles in [Vector3.ZERO,Vector3(.4,.8,-.3),Vector3(1.55,-1.2,.7),Vector3(-1.55,2.4,-.9)]:
		for front in [false,true]:
			photo.selfie=front
			var pose:=Transform3D(Basis.from_euler(angles),Vector3(2,3,-4))
			guide.global_transform=pose;photo.update_pose()
			var before:Transform3D=photo.camera.global_transform
			check(before.basis.determinant()>.999,"Lens rotation is right-handed, never mirrored")
			for axis in [Vector3.RIGHT,Vector3.UP,Vector3.BACK]:
				guide.global_transform=pose.translated(axis*.2);photo.update_pose()
				check((photo.camera.global_position-before.origin).is_equal_approx(axis*.2),"World-axis movement follows guide without inversion")
				check(photo.camera.global_basis.is_equal_approx(before.basis),"Translation never rotates lens")
			guide.global_transform=pose;photo.update_pose()
			var lens:Transform3D=photo.camera.global_transform
			var center:Vector2=photo.camera.unproject_position(lens*Vector3(0,0,-2))
			check(photo.camera.unproject_position(lens*Vector3(.1,0,-2)).x>center.x,"Lens-right projects to image-right")
			check(photo.camera.unproject_position(lens*Vector3(0,.1,-2)).y<center.y,"Lens-up projects to image-top")
			check(photo.camera.unproject_position(lens*Vector3(0,0,-3)).distance_to(center)<.01,"Optical-axis movement stays centered")
	photo.selfie = false
	game._right_pressed("ax_button")
	check(photo.selfie, "Right A toggles selfie while guide is held")
	game._left_button("trigger_click")
	check(not photo.active, "Left trigger returns to collection")
	game._left_button("trigger_click"); game.xr = false
	if "--capture" in OS.get_cmdline_user_args():
		photo.selfie = false
		await photo.capture()
		check(not photo.last_path.is_empty() and FileAccess.file_exists(photo.last_path), "Actual renderer saves PNG")
		if not photo.last_path.is_empty():
			var image := Image.load_from_file(photo.last_path)
			check(image.get_size() == Photo.PHOTO_SIZE, "Photo is 1920 by 1080")
			image.save_png("res://test-results/guide_camera_forward.png")
		var first_path: String = photo.last_path
		photo.selfie = true
		await photo.capture()
		check(photo.last_path != first_path and FileAccess.file_exists(first_path), "Second shot preserves first photo")
		if not photo.last_path.is_empty(): Image.load_from_file(photo.last_path).save_png("res://test-results/guide_camera_selfie.png")
		check(photo.view.size == Photo.PREVIEW_SIZE and not photo.busy, "Photo returns to low resolution preview after saving")
		# Fill a foreground rectangle on the UI-only layer. It must never affect a saved image.
		var quad := MeshInstance3D.new(); var mesh := QuadMesh.new(); mesh.size = Vector2(10,10); quad.mesh = mesh
		var material := StandardMaterial3D.new(); material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; material.albedo_color = Color.MAGENTA
		quad.material_override = material; quad.layers = Photo.UI_LAYER
		game.add_child(quad); quad.global_transform = photo.camera.global_transform.translated_local(Vector3(0,0,-.2))
		await photo.capture()
		var actual := Image.load_from_file(photo.last_path)
		var center := actual.get_pixel(actual.get_width()/2, actual.get_height()/2)
		check(not (center.r > .8 and center.b > .8 and center.g < .2), "Rendered screenshot excludes an opaque UI test overlay")
		quad.queue_free()
	guide.dock()
	check(not guide.held and photo.view.render_target_update_mode == SubViewport.UPDATE_DISABLED, "Docking stops preview rendering")
	game.queue_free(); await process_frame; await create_timer(.3).timeout
	print("GUIDE_CAMERA_RESULT %d checks: %s" % [checks, failures]); quit(0 if failures.is_empty() else 1)
