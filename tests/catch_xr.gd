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
	var pose: Transform3D = g.right.global_transform.looking_at(target, Vector3.UP)
	set_controller_pose(controllers[1], g.origin.global_transform.affine_inverse() * pose)
	await settle()
	check(g._pointer_position().distance_to(point) < 2.0, "Tracked controller ray hits intended UI point")
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
	g._select_bait(0)
	for bait_step in range(g.game.BAITS.size()):
		controllers[0].set_input("ax_button", true)
		await process_frame
		controllers[0].set_input("ax_button", false)
		await settle()
		check(g.game.bait == (bait_step + 1) % g.game.BAITS.size(), "Tracked X button cycles all six baits")
	# Drive real tracked controller poses and trigger signals through production casting.
	g.set_process(false)
	g.motor.set_physics_process(false)
	var right_pose: Transform3D = controllers[1].get_pose("grip").transform
	right_pose.basis = Basis(Vector3.UP, 0.5)
	set_controller_pose(controllers[1], right_pose)
	g._process(0.05)
	controllers[1].set_input("trigger_click", true)
	for i in range(6): g._process(0.05)
	controllers[1].set_input("trigger_click", false)
	check(g.game.state == 0, "Stationary trigger release does not cast")
	controllers[1].set_input("trigger_click", true)
	for i in range(8):
		right_pose.origin += -g.head.basis.z * 0.10
		set_controller_pose(controllers[1], right_pose)
		g._process(0.05)
	check(g.peak_speed > 0.55, "Tracked forward swing builds casting power")
	var aim: Vector3 = -g.head.global_basis.z
	aim.y = 0
	aim = aim.normalized()
	controllers[1].set_input("trigger_click", false)
	check(g.game.state == 1, "Releasing trigger after physical swing casts")
	check((g.cast_target - g.cast_anchor).normalized().dot(aim) > 0.999, "VR cast follows gaze rather than sideways rod orientation")
	check(g.game.cast_distance >= 5.0 and g.game.cast_distance <= 24.0, "Physical cast distance stays bounded")
	g.game.reset()
	controllers[1].set_input("trigger_click", true)
	var origin_before: Transform3D = g.origin.global_transform
	g.origin.position.x += 0.2
	g._process(0.05)
	controllers[1].set_input("trigger_click", false)
	check(g.game.state == 0, "Locomotion alone cannot produce a physical cast")
	g.origin.global_transform = origin_before
	# Rotating the wrist/rod also generates forward tip speed without translating the hand.
	right_pose.basis = Basis(Vector3.UP, 0.5) * Basis(Vector3.RIGHT, -1.2)
	set_controller_pose(controllers[1], right_pose)
	g._process(0.05)
	controllers[1].set_input("trigger_click", true)
	for i in range(10):
		right_pose.basis = Basis(Vector3.UP, 0.5) * Basis(Vector3.RIGHT, -1.2 + (i + 1) * 0.09)
		set_controller_pose(controllers[1], right_pose)
		g._process(0.05)
	controllers[1].set_input("trigger_click", false)
	check(g.game.state == 1, "Angular rod swing alone produces a physical cast")
	g.game.reset()
	# Land a real catch and exercise the default attachment and inspection controls.
	g.game.fish_index = 6
	g.game.journal.append(g.game.SPECIES[6].duplicate())
	g.game.state = 5
	g.last_state = 5
	g.game.message = "Zander · 60 cm · 2.0 kg\nSander lucioperca · Right A to release."
	g._show_fish()
	g._process(0.05)
	check(not g.catch_in_hand, "New catch hangs from rod by default")
	check(g.fish_display.to_global(g._catch_mouth()).distance_to(g.tip.global_position - Vector3.UP * 0.28) < 0.001, "Mouth is attached below rod tip")
	check(g.fish_display.global_basis.x.dot(Vector3.UP) > 0.99, "Default hanging fish is head-up")
	check(g.line_mesh.get_surface_count() == 1 and not g.bobber.visible, "Caught fish retains line to rod without bobber")
	await capture_stereo("catch_hanging")
	controllers[0].set_input("grip", 1.0)
	g._process(0.05)
	check(g.catch_in_hand, "Left grip brings catch to left hand")
	check(g.fish_display.to_global(g._catch_mouth()).distance_to(g.left.global_position - Vector3.UP * 0.08) < 0.001, "Left hand grips string 8 cm above fish mouth")
	var string_vertices = g.line_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	check(string_vertices.size() == 3 and string_vertices[1].distance_to(g.left.global_position) < 0.001, "String routes from rod through left grip to fish mouth")
	check(g.fish_display.global_basis.x.dot(Vector3.UP) > 0.999, "Fish stays head-up in the left hand")
	var tilted_hand: Transform3D = controllers[0].get_pose("grip").transform
	tilted_hand.origin.y += 0.35
	tilted_hand.basis = Basis(Vector3.FORWARD, 0.8) * Basis(Vector3.RIGHT, 0.5)
	set_controller_pose(controllers[0], tilted_hand)
	g._process(0.05)
	check(g.fish_display.global_basis.x.dot(Vector3.UP) > 0.999, "Tilting the hand cannot tip the catch sideways")
	var player_before: Transform3D = g.origin.global_transform
	for side in range(2):
		var previous: Quaternion = g.catch_rotation
		controllers[side].set_input("primary", Vector2(0.8, 0.5))
		g._process(0.25)
		g.motor._physics_process(0.05)
		check(g.catch_rotation.angle_to(previous) > 0.1, "Either joystick rotates catch")
		check(g.fish_display.global_basis.x.dot(Vector3.UP) > 0.999, "Joystick rotation preserves vertical head-up orientation")
		controllers[side].set_input("primary", Vector2.ZERO)
	check(g.origin.global_basis.is_equal_approx(player_before.basis) and g.motor.velocity.length() < 0.01, "Catch sticks do not walk or turn the player")
	check(g.fish_display.to_global(g._catch_mouth()).distance_to(g.left.global_position - Vector3.UP * 0.08) < 0.001, "Lifting, tilting and rotating preserve string hold above mouth")
	await capture_stereo("catch_in_hand")
	XRServer.remove_tracker(controllers[0])
	g._process(0.05)
	check(not g.catch_in_hand, "Disconnected left controller returns inspection fish to rod")
	XRServer.add_tracker(controllers[0])
	set_controller_pose(controllers[0], controllers[0].get_pose("aim").transform)
	controllers[0].set_input("grip", 0.0)
	g._process(0.05)
	check(not g.catch_in_hand and g.fish_display.to_global(g._catch_mouth()).distance_to(g.tip.global_position - Vector3.UP * 0.28) < 0.001, "Releasing grip returns fish to rod")
	check(g.fish_display.global_basis.x.dot(Vector3.UP) > 0.999, "Returned hanging fish remains head-up after rotation")
	controllers[1].set_input("ax_button", true)
	controllers[1].set_input("ax_button", false)
	g._process(0.05)
	check(g.game.state == 0 and not g.fish_display.visible and not g.motor.catch_controls, "Right A releases catch and restores movement controls")
	for tracker in controllers: XRServer.remove_tracker(tracker)
	print("XR catch and casting tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
