extends SceneTree
const Locations = preload("res://scripts/locations.gd")
var failures := 0
var checks := 0
var capture_effect = preload("res://tests/xr_capture.gd").new()
var controllers: Array[XRControllerTracker] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void:
	call_deferred("run")

func settle() -> void:
	for i in range(30): await process_frame
	await RenderingServer.frame_post_draw

func set_controller_pose(tracker: XRControllerTracker, pose: Transform3D) -> void:
	for name in ["grip", "aim", "default"]:
		tracker.set_pose(name, pose, Vector3.ZERO, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_HIGH)

func click_control(g, point: Vector2) -> void:
	var target: Vector3 = g.avatar_panel.to_global(Vector3((point.x / 1000.0 - 0.5) * 1.8, (0.5 - point.y / 720.0) * 1.296, 0))
	# Keep grip/finger placement stable while directing the OpenXR aim pose.
	await settle()
	var ray: Dictionary = preload("res://scripts/menu_ray.gd").sample(g)
	check(not ray.is_empty(), "Tracked fingertip ray available")
	if ray.is_empty(): return
	var orientation := Transform3D(Basis.IDENTITY, ray.origin).looking_at(target, Vector3.UP).basis
	var pose := Transform3D(orientation, g.right.global_position)
	controllers[1].set_pose("aim", g.origin.global_transform.affine_inverse()*pose,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	await settle()
	check(g._pointer_position().distance_to(point) < 2.0, "Fingertip ray hits intended UI point")
	controllers[1].set_input("trigger_click", true)
	await process_frame
	controllers[1].set_input("trigger_click", false)
	await settle()

func capture_stereo(label: String) -> void:
	capture_effect.request_capture(label)
	for i in range(120):
		await process_frame
		if capture_effect.completed == label: break
	check(capture_effect.completed == label and capture_effect.views == 2 and capture_effect.results.size() == 2, "Captured native stereo buffers")
	for eye in range(capture_effect.results.size()):
		var frame: Image = capture_effect.results[eye]
		# Preserve original scene-linear pixels as EXR; display conversion only for PNG.
		DirAccess.make_dir_recursive_absolute("res://test-results/xr")
		frame.save_exr("res://test-results/xr/" + label + "_eye%d.exr" % eye)
		# Sample the whole image: the Guide may cover both points of a two-pixel probe.
		var darkest := INF
		var brightest := -INF
		for y in range(1,8):
			for x in range(1,8):
				var value := frame.get_pixel(frame.get_width()*x/8,frame.get_height()*y/8).get_luminance()
				darkest=minf(darkest,value);brightest=maxf(brightest,value)
		check(brightest-darkest > 0.02, "Eye contains scene detail")
		frame.convert(Image.FORMAT_RGBA8)
		frame.linear_to_srgb()
		check(frame.save_png("res://docs/locations/" + label + "_eye%d.png" % eye) == OK, "Saved stereo eye")

func run() -> void:
	var g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	current_scene = g
	await settle()
	var interface = XRServer.find_interface("OpenXR")
	check(g.xr and interface != null and interface.is_initialized(), "Native OpenXR initialized")
	if not g.xr:
		quit(1)
		return
	check(root.use_xr and interface.get_view_count() == 2, "Native stereo viewport has two views")
	var left: Transform3D = interface.get_transform_for_view(0, Transform3D.IDENTITY)
	var right: Transform3D = interface.get_transform_for_view(1, Transform3D.IDENTITY)
	check(left.origin.distance_to(right.origin) > 0.01, "Runtime supplies separate eye poses")
	for side in range(2):
		var tracker := XRControllerTracker.new()
		tracker.name = "synthetic_left" if side == 0 else "synthetic_right"
		tracker.hand = XRPositionalTracker.TRACKER_HAND_LEFT if side == 0 else XRPositionalTracker.TRACKER_HAND_RIGHT
		tracker.description = "Test-only synthetic tracked controller"
		tracker.set_input("primary", Vector2.ZERO)
		tracker.set_input("grip", 0.0)
		tracker.set_input("trigger_click", false)
		tracker.set_input("by_button", false)
		XRServer.add_tracker(tracker)
		controllers.append(tracker)
		var position: Vector3 = g.head.position + Vector3(-0.22 if side == 0 else 0.22, -0.4, -0.35)
		set_controller_pose(tracker, Transform3D(Basis.IDENTITY, position))
	g.left.tracker = controllers[0].name
	g.right.tracker = controllers[1].name
	var compositor := Compositor.new()
	compositor.compositor_effects = [capture_effect]
	g.head.compositor = compositor
	await settle()
	check(g.left.get_has_tracking_data() and g.right.get_has_tracking_data(), "Both controller nodes receive tracked grip poses")
	check(g.rod.visible and not g.hud.tracking_lost, "Tracked controllers enable rod and fishing updates")
	var before: Vector3 = g.left.position
	var moved: Transform3D = controllers[0].get_pose("grip").transform
	moved.origin.x += 0.1
	set_controller_pose(controllers[0], moved)
	controllers[0].set_input("grip", 1.0)
	await settle()
	check(g.left.position.distance_to(before) > 0.09, "Left tracked pose moves independently")
	check(g.avatar.left_curl > 0.7, "Synthetic grip drives avatar hand curl")
	controllers[0].set_input("grip", 0.0)
	print("XR runtime: ", interface.get_system_info(), " | eye separation: ", left.origin.distance_to(right.origin))
	var guide = g.fish_guide
	guide.entries.clear()
	guide.ingest(g.game.SPECIES)
	guide.update_device()
	check(not guide.held and guide.visible, "Field guide is docked and visible in VR")
	var belt: Vector3 = guide.dock_grip_position()
	check(belt.distance_to(g.head.global_position) < 1.1, "Belt device is within arm reach")
	# Grip away from belt must remain available for reeling/catch inspection.
	controllers[0].set_input("grip", 1.0)
	await settle()
	check(not guide.held, "Remote grip cannot grab device")
	controllers[0].set_input("grip", 0.0)
	await settle()
	var hand := Transform3D(Basis.IDENTITY, g.origin.to_local(belt))
	set_controller_pose(controllers[0], hand)
	await settle()
	controllers[0].set_input("grip", 1.0)
	await settle()
	check(guide.held, "Grip near belt grabs physical device")
	hand.origin = g.head.position + Vector3(-0.08, -0.20, -0.46)
	set_controller_pose(controllers[0], hand)
	await settle()
	check(guide.global_position.distance_to(g.left.to_global(guide.GRIP_OFFSET)) < 0.001, "Device follows tracked grip at inspection distance")
	check(guide.to_local(g.left.global_position).is_equal_approx(guide.GRIP_ANCHOR), "Grip anchor stays below screen and navigation controls")
	g.game.state = 2
	g.game.timer = 4.0
	var timer_before: float = g.game.timer
	await settle()
	check(g.game.timer == timer_before and not g.hud.visible, "Device inspection pauses fishing and clears status panel")
	var page_before: int = guide.selected
	controllers[0].set_input("ax_button", true)
	controllers[0].set_input("ax_button", false)
	await settle()
	check(guide.selected == posmod(page_before + 2, guide.Session.SPECIES.size() + 1) - 1, "Left X pages device without changing bait")
	page_before = guide.selected
	controllers[1].set_input("primary", Vector2(1, 0))
	var heading_before: Basis = g.origin.global_basis
	await settle()
	check(guide.selected == posmod(page_before + 2, guide.Session.SPECIES.size() + 1) - 1, "Joystick pages once per deflection")
	check(g.origin.global_basis.is_equal_approx(heading_before), "Browsing does not snap-turn player")
	controllers[1].set_input("primary", Vector2.ZERO)
	await settle()
	await capture_stereo("field_guide")
	check(guide.viewport.get_texture().get_image().save_png("res://docs/field_guide_screen.png") == OK, "Saved species collection screen")
	controllers[0].set_input("trigger_click", true)
	await process_frame
	controllers[0].set_input("trigger_click", false)
	await settle()
	var photo = guide.photo_camera
	check(photo.active, "Tracked left trigger opens guide camera")
	check(photo.camera.global_transform.is_equal_approx(g.left.global_transform), "Native VR photo lens follows tracked hand")
	check(not photo.view.use_xr and photo.camera.cull_mask & 128 == 0, "VR photo uses mono view with UI excluded")
	controllers[1].set_input("trigger_click", true)
	await process_frame
	controllers[1].set_input("trigger_click", false)
	for frame in range(120):
		await process_frame
		if not photo.busy: break
	check(not photo.last_path.is_empty() and FileAccess.file_exists(photo.last_path), "Tracked right trigger saves UI-free photo in native VR")
	controllers[1].set_input("ax_button", true)
	await process_frame
	controllers[1].set_input("ax_button", false)
	await settle()
	check(photo.selfie and photo.camera.cull_mask == 5, "Tracked right A extends selfie lens with full avatar")
	await photo.capture()
	if not photo.last_path.is_empty():
		var selfie := Image.load_from_file(photo.last_path)
		check(selfie.get_size() == Vector2i(1920,1080), "Native VR selfie saves full resolution")
		selfie.save_png("res://docs/guide_camera_selfie_xr.png")
	await settle()
	check(guide.viewport.get_texture().get_image().save_png("res://docs/guide_camera_screen.png") == OK, "Saved camera preview and controls")
	controllers[0].set_input("trigger_click", true)
	await process_frame
	controllers[0].set_input("trigger_click", false)
	await settle()
	check(not photo.active, "Tracked left trigger returns from camera to guide")
	controllers[0].set_input("grip", 0.0)
	await settle()
	check(not guide.held and guide.global_position.distance_to(guide.belt_transform.origin) < 0.001, "Releasing grip returns guide to belt")
	check(g.game.timer < timer_before, "Docking resumes fishing")
	g.game.reset()
	g.game.fish_index = 6
	g.game.journal.append(g.game.SPECIES[6].duplicate())
	g.game.state = 5
	g.last_state = 5
	g._show_fish()
	set_controller_pose(controllers[0], Transform3D(Basis.IDENTITY, g.origin.to_local(guide.dock_grip_position())))
	await settle()
	controllers[0].set_input("grip", 1.0)
	await settle()
	check(guide.held, "Device can be grabbed again")
	check(not g.catch_in_hand and g.fish_display.visible, "Guide grip takes priority over catch inspection without releasing fish")
	XRServer.remove_tracker(controllers[0])
	await settle()
	check(not guide.held, "Lost controller safely docks device")
	XRServer.remove_tracker(controllers[1])
	print("XR field guide tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
