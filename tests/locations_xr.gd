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
	var orientation := Transform3D(Basis.IDENTITY, ray.get("aim_origin",ray.origin)).looking_at(target, Vector3.UP).basis
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
		var upper := frame.get_pixel(frame.get_width() / 2, frame.get_height() / 4)
		var lower := frame.get_pixel(frame.get_width() / 2, frame.get_height() * 3 / 4)
		check(absf(upper.r - lower.r) + absf(upper.g - lower.g) + absf(upper.b - lower.b) > 0.01, "Eye contains scene detail")
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
	check(g.head.get_viewport().use_xr and interface.get_view_count() == 2, "Native stereo viewport has two views")
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
	for entry in Locations.CATALOG:
		check(g._select_location(entry.id, false), "XR travel to " + entry.id)
		await settle()
		await capture_stereo("xr_" + entry.id)
	controllers[1].set_input("by_button", true)
	controllers[1].set_input("by_button", false)
	await settle()
	check(g.menu_open and g.avatar_panel.visible and g.motor.blocked, "Controller B opens and pauses VR menu")
	g.avatar_menu.show_locations()
	await settle()
	check(g.avatar_menu.size.x <= 900 and g.avatar_menu.position.y + g.avatar_menu.size.y <= 720, "VR menu fits its texture")
	check(g.avatar_menu_view.get_texture().get_image().save_png("res://docs/locations/xr_menu_texture.png") == OK, "Saved in-world menu texture")
	var list = g.avatar_menu.location_list
	await click_control(g, list.global_position + list.get_item_rect(1).get_center())
	check(list.get_selected_items()[0] == 1, "Controller trigger selects Lake Pier row")
	await click_control(g, g.avatar_menu.visit_button.get_global_rect().get_center())
	check(g.current_location == "lake_pier" and not g.menu_open and not g.avatar_panel.visible and not g.motor.blocked, "Tracked travel closes menu and resumes movement")
	g._toggle_avatar_menu()
	await capture_stereo("xr_menu")
	controllers[1].set_input("by_button", true)
	controllers[1].set_input("by_button", false)
	await settle()
	check(not g.menu_open and not g.motor.blocked, "Controller B closes VR menu")
	XRServer.remove_tracker(controllers[0])
	await settle()
	await create_timer(.6).timeout
	check(g.hud.tracking_lost, "Sustained controller loss shows tracking warning")
	XRServer.add_tracker(controllers[0])
	set_controller_pose(controllers[0], controllers[0].get_pose("aim").transform)
	await settle()
	check(not g.hud.tracking_lost, "Restoring controller tracking resumes fishing")
	for tracker in controllers: XRServer.remove_tracker(tracker)
	print("XR location tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
