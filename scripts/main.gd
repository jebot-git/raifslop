extends Node3D

const Session = preload("res://scripts/fishing_session.gd")
const ReelTracker = preload("res://scripts/reel_tracker.gd")
const HUD = preload("res://scripts/hud.gd")
const Motor = preload("res://scripts/locomotion.gd")
const Shore = preload("res://scripts/shore.gd")
const AvatarLibrary = preload("res://scripts/avatar_library.gd")
const AvatarRig = preload("res://scripts/avatar_rig.gd")
const AvatarMenu = preload("res://scripts/avatar_menu.gd")
const Locations = preload("res://scripts/locations.gd")
var golf_activity: Node
var tracking_manager: Node
var ambience: Node
var shoulder_radio: Node3D
var network: Node
var rod_status: Node3D
var server_only := false
var fish_guide: Node3D
var foreground: Node3D
var bbq: Node3D
var current_location := Locations.DEFAULT_ID
var world_environment: Environment
var panorama_material: ShaderMaterial
var location_sun: DirectionalLight3D
var water_material: ShaderMaterial
var water_surface: MeshInstance3D
var water_level := -.35
var motor: CharacterBody3D
var avatars = AvatarLibrary.new()
var avatar: Node3D
var avatar_menu: PanelContainer
var avatar_menu_view: SubViewport
var avatar_panel: MeshInstance3D
var menu_pointer: MeshInstance3D
var menu_laser: MeshInstance3D
var menu_ray_start := Vector3.ZERO
var menu_open := false
var menu_last_position := Vector2.ZERO
var menu_filtered_position := Vector2(-1, -1)
var menu_mouse_down := false
var avatar_loading := false
var desktop_left: Node3D
var catch_label: Label3D
var cast_anchor := Vector3.ZERO
var aim_marker: MeshInstance3D
var game = Session.new()
var reel_tracker = ReelTracker.new()
var reel_tracking_offset := Vector3.ZERO
var xr := false
var xr_view: SubViewport
var spectator: Node3D
var origin: XROrigin3D
var head: Camera3D
var left: XRController3D
var right: XRController3D
var rod_holster: Node3D
var rod_visual: Node3D
var rig_radial:Node3D
var rod: Node3D
var tip: Node3D
var crank: Node3D
var bobber: MeshInstance3D
var line_mesh: ImmediateMesh
var line_material: StandardMaterial3D
var fish_display: Node3D
var hooked_fish: Node3D
var catch_bounds := AABB()
var catch_twitch = preload("res://scripts/catch_twitch.gd").new()
var catch_rotation := Quaternion.IDENTITY
var catch_in_hand := false
var hud: Control
var last_tip := Vector3.ZERO
var velocity := Vector3.ZERO
var casting := false
var head_aimed_casting := true
var controller_calibration = preload("res://scripts/controller_calibration.gd").new()
var calibrated_hands: Array[Node3D] = []
var cast_aim_target := Vector3.ZERO
var cast_aim_anchor := Vector3.ZERO
var cast_swing_axis := Vector3.FORWARD
var cast_motion = preload("res://scripts/cast_motion.gd").new()
var desktop_cast_extensions := 0
var cast_last_tip := Vector3.ZERO
var cast_sample_us := 0
var cast_trace:Array[Dictionary]=[]
var peak_speed := 0.0
var time := 0.0
var cast_target := Vector3(0, -0.35, -12)
var cast_start := Vector3.ZERO
var last_state := 0
var gesture_cooldown := 0.0
var fight_input = preload("res://scripts/fight_input.gd").new()
var tracking_was_valid := false
var tracking_warning_time := 0.0
var audio: AudioStreamPlayer
var fishing_feedback: Node3D
var shadow_policy: Node
var cast_barriers: Array[RID] = []
var cast_water_boundary = preload("res://scripts/fish_water_boundary.gd").new()
var fish_boundary = preload("res://scripts/fish_water_boundary.gd").new()
var fish_safe_position := Vector3(INF, INF, INF)
var boundary_landing_direction := Vector3(INF, INF, INF)
var boundary_landing_anchor := Vector3(INF, INF, INF)
var boundary_landing_radius := -1.0
var boundary_landing := .35
var escape_offset := Vector3.ZERO
var quitting := false

func _ready() -> void:
	var diagnostics=preload("res://scripts/client_diagnostics.gd").new()
	diagnostics.game_root=self;add_child(diagnostics)
	server_only = "--server" in OS.get_cmdline_user_args()
	if server_only:
		_start_network()
		return
	_build_environment()
	get_tree().auto_accept_quit = false
	_build_rig()
	_load_player_preferences()
	_build_rod()
	_build_ui()
	_build_avatar_menu()
	var saved := Locations.saved_location()
	if not _select_location(saved, false): _select_location(Locations.DEFAULT_ID, false)
	avatars.initialize()
	avatar_menu.refresh()
	_select_avatar(avatars.selected_path)
	fish_guide = preload("res://scripts/fish_guide.gd").new()
	fish_guide.game_root = self
	add_child(fish_guide)
	_load_journal()
	game.tackle.load_profile()
	avatar_menu.attach_tackle(game)
	audio = AudioStreamPlayer.new()
	add_child(audio)
	last_tip = _strike_tip()
	ambience=preload("res://scripts/ambience.gd").new()
	add_child(ambience);ambience.setup(self)
	shoulder_radio=preload("res://scripts/voice/shoulder_radio.gd").new()
	add_child(shoulder_radio);shoulder_radio.setup(self)
	hooked_fish=preload("res://scripts/hooked_fish.gd").new()
	add_child(hooked_fish);hooked_fish.setup(self)
	fishing_feedback=preload("res://scripts/fishing_feedback.gd").new()
	add_child(fishing_feedback);fishing_feedback.setup(self)
	shadow_policy=preload("res://scripts/shadow_policy.gd").new()
	add_child(shadow_policy);shadow_policy.setup(self)
	if xr_view:
		spectator = preload("res://scripts/spectator_camera.gd").new()
		add_child(spectator)
		spectator.setup(self)
	_start_network()
	bbq=preload("res://scripts/bbq/activity.gd").new();add_child(bbq);bbq.setup(self)
	golf_activity = preload("res://addons/golfminus/scripts/golf/fishing_host.gd").new()
	add_child(golf_activity); golf_activity.setup(self)
	print("Real AI Fishing ready | ", "OpenXR" if xr else "Desktop", " | panorama + location foreground loaded")

func material(color: Color, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metal
	m.roughness = 0.45
	return m

func mesh_node(mesh: Mesh, parent: Node3D, pos: Vector3, mat: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = mat
	parent.add_child(n)
	n.position = pos
	return n

func box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return mesh_node(b, parent, pos, mat)

func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, mat: Material) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = radius * 0.85
	c.bottom_radius = radius
	c.height = height
	c.radial_segments = 12
	return mesh_node(c, parent, pos, mat)

func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	world_environment = env
	var sky := Sky.new()
	var pano := preload("res://scripts/panorama_material.gd").new()
	panorama_material = pano
	sky.sky_material = pano
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	location_sun = sun
	sun.rotation_degrees = Vector3(-35, -40, 0)
	sun.light_color = Color("ffe2b5")
	sun.light_energy = 0.55
	sun.shadow_enabled = false
	sun.light_angular_distance = 4.0
	sun.light_specular = 0.45
	add_child(sun)
	var water := PlaneMesh.new()
	water.size = Vector2(512, 512) # Cover the full modeled shore, including rear aprons.
	water.subdivide_width = 64
	water.subdivide_depth = 64
	var wm := ShaderMaterial.new()
	water_material = wm
	wm.shader = load("res://assets/environment/water.gdshader")
	var ripple_noise := FastNoiseLite.new()
	ripple_noise.seed = 731
	ripple_noise.frequency = .045
	var ripple_texture := NoiseTexture2D.new()
	ripple_texture.width = 256
	ripple_texture.height = 256
	ripple_texture.seamless = true
	ripple_texture.as_normal_map = true
	ripple_texture.bump_strength = 2.0
	ripple_texture.noise = ripple_noise
	wm.set_shader_parameter("ripple_normal",ripple_texture)
	wm.set_shader_parameter("river_bed",load("res://assets/models/locations/lit/gray_pier_gravelly_sand_Diffuse.jpg"))
	wm.set_shader_parameter("bank_cover",load("res://assets/models/locations/lit/lakeside_aerial_grass_rock_Diffuse.jpg"))
	water_surface=mesh_node(water, self, Vector3(0, water_level, -40), wm)
	water_surface.name="WaterSurface"
	bobber = preload("res://scripts/bobber_visual.gd").new()
	add_child(bobber)
	bobber.position = Vector3(0, 0, -3)
	line_mesh = ImmediateMesh.new()
	var lm := material(Color("d8f5e5"))
	line_material = lm
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_node(line_mesh, self, Vector3.ZERO, lm)
	fish_display = Node3D.new()
	add_child(fish_display)
	fish_display.position = Vector3(0, 1.2, -1.1)
	fish_display.visible = false

func _build_rig() -> void:
	var interface := XRServer.find_interface("OpenXR")
	xr = interface != null and interface.is_initialized()
	# Log the application API, selected runtime and renderer for support reports.
	var xr_info := {
		"api": "OpenXR" if xr else "Desktop",
		"initialized": xr,
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"rendering_method": RenderingServer.get_current_rendering_method(),
	}
	if xr:
		xr_info.merge(interface.get_system_info())
	print("XR_STARTUP ", JSON.stringify(xr_info))
	if not xr and "--xr-mode" in OS.get_cmdline_args():
		var mode_index := OS.get_cmdline_args().find("--xr-mode")
		if mode_index + 1 < OS.get_cmdline_args().size() and OS.get_cmdline_args()[mode_index + 1] == "on":
			push_warning("OpenXR did not initialize; using desktop controls. Select an active OpenXR runtime (VDXR or SteamVR on Windows), connect the headset, and restart. See the earlier OpenXR errors in this log.")
	# PC VR renders stereo into a dedicated viewport, leaving the window mono.
	# Standalone headsets retain their single XR output without a spectator pass.
	if xr and not OS.has_feature("android"):
		xr_view = SubViewport.new()
		xr_view.name = "HeadsetViewport"
		xr_view.world_3d = get_world_3d()
		xr_view.size = interface.get_render_target_size()
		xr_view.use_xr = true
		xr_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		xr_view.audio_listener_enable_3d = true
		get_viewport().audio_listener_enable_3d = false
		add_child(xr_view)
	motor = Motor.new()
	(xr_view if xr_view else self).add_child(motor)
	origin = XROrigin3D.new()
	origin.name = "XROrigin3D"
	motor.add_child(origin)
	if xr:
		get_viewport().use_xr = xr_view == null
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		head = XRCamera3D.new()
	else:
		head = Camera3D.new()
		head.position = Vector3(0, 1.65, 0.65)
		head.rotation.x = -0.08
	origin.add_child(head)
	head.current = true
	head.cull_mask = 3
	left = XRController3D.new()
	left.tracker = "left_hand"
	left.pose = "grip"
	left.name = "LeftHand"
	origin.add_child(left)
	right = XRController3D.new()
	right.tracker = "right_hand"
	right.pose = "grip"
	right.name = "RightHand"
	origin.add_child(right)
	left.button_pressed.connect(_left_button)
	right.button_pressed.connect(_right_pressed)
	right.button_released.connect(_right_released)
	for controller in [left, right]:
		var grip := Node3D.new(); grip.name = "CalibratedGrip"
		controller.add_child(grip); calibrated_hands.append(grip)
	motor.origin = origin
	motor.head = head
	motor.left = left
	motor.right = right
	motor.xr = xr
	desktop_left = Node3D.new()
	origin.add_child(desktop_left)

func _build_rod() -> void:
	rod = Node3D.new()
	rod.name = "FishingRod"
	if xr:
		right.add_child(rod)
	else:
		origin.add_child(rod)
		rod.position = Vector3(0.30, 1.43, 0.30)
	rod.rotation.x = 0.35
	if xr: rod.top_level = true
	rod_visual = preload("res://scripts/rod_visual.gd").new()
	rod.add_child(rod_visual)
	rod_visual.equip(game.tackle.equipped)
	rig_radial=preload("res://scripts/ui/rig_radial.gd").new();add_child(rig_radial);rig_radial.setup(self)
	crank = rod_visual.crank
	tip = Node3D.new()
	rod.add_child(tip)
	tip.position = Vector3(0, 0, -1.68)
	rod_holster = preload("res://scripts/rod_holster.gd").new()
	rod_holster.game_root=self
	add_child(rod_holster)
	rod_status = preload("res://scripts/rod_status.gd").new()
	rod_status.game_root = self
	add_child(rod_status)

func _build_ui() -> void:
	hud = HUD.new()
	hud.game = game
	hud.vr_mode = xr
	if xr:
		# Retain the shared HUD state for gameplay; VR has no floating HUD surface.
		add_child(hud)
		hud.hide()
	else:
		var layer := CanvasLayer.new()
		add_child(layer)
		layer.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.bait_selected.connect(func(index: int): _select_bait(index))
	hud.action_pressed.connect(_primary_action)
	hud.avatar_requested.connect(_toggle_avatar_menu)
	catch_label = preload("res://scripts/catch_label.gd").new()
	catch_label.game_root = self
	add_child(catch_label)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if server_only: get_tree().quit()
		else: _quit_game()

func _load_player_preferences() -> void:
	var cfg := ConfigFile.new()
	cfg.load("user://player.cfg")
	var symbols = cfg.get_value("interface", "pictograms", true)
	preload("res://scripts/ui/pictograms.gd").enabled = symbols if symbols is bool else true
	controller_calibration.load_config(cfg)
	_apply_controller_calibration()
	var head_aim = cfg.get_value("controls", "head_aimed_casting", true)
	head_aimed_casting = head_aim if head_aim is bool else true
	var smooth = cfg.get_value("controls", "smooth_turn", false)
	motor.smooth_turn = smooth if smooth is bool else false
	var speed = cfg.get_value("controls","smooth_turn_speed",75.0)
	motor.smooth_turn_speed=clampf(float(speed),30,360) if (speed is float or speed is int) and is_finite(speed) else 75.0
	var angle = cfg.get_value("controls","snap_turn_angle",30.0)
	motor.snap_turn_angle=clampf(float(angle),15,90) if (angle is float or angle is int) and is_finite(angle) else 30.0
	var saved_rig=cfg.get_value("tackle","rig",0)
	game.rig=saved_rig if saved_rig is int and saved_rig in [0,1,2] else 0
	var bait = cfg.get_value("tackle", "bait", 0)
	game.bait = clampi(int(bait), 0, game.bait_count()-1) if (bait is int or bait is float) and is_finite(bait) else 0

func controller_pose(hand: int) -> Transform3D:
	return (left.global_transform if hand == 0 else right.global_transform) * controller_calibration.pose(hand)

func controller_local_pose(hand: int) -> Transform3D:
	return (left.transform if hand == 0 else right.transform) * controller_calibration.pose(hand)

func _apply_controller_calibration() -> void:
	for hand in calibrated_hands.size(): calibrated_hands[hand].transform = controller_calibration.pose(hand)
	# A settings adjustment must never be interpreted as a cast or reel gesture.
	casting = false; tracking_was_valid = false; reel_tracker.engaged = false
	game.fly.reset_mend_gesture(); game.fly.release_strip(true)

func _save_player_preferences() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("interface", "pictograms", preload("res://scripts/ui/pictograms.gd").enabled)
	controller_calibration.save_config(cfg)
	cfg.set_value("controls", "head_aimed_casting", head_aimed_casting)
	cfg.set_value("controls", "smooth_turn", motor.smooth_turn)
	cfg.set_value("controls", "smooth_turn_speed", motor.smooth_turn_speed)
	cfg.set_value("controls", "snap_turn_angle", motor.snap_turn_angle)
	cfg.set_value("tackle", "bait", game.bait)
	cfg.set_value("tackle", "rig",game.rig)
	var error := cfg.save("user://player.cfg")
	if error != OK: push_warning("Cannot save player settings: " + error_string(error))

func _save_user_settings() -> void:
	_save_player_preferences()
	ambience.save()
	tracking_manager.save()
	network.save_preferences()
	network.voice.save_preferences()
	avatars.save_selection(avatars.selected_path)
	var error := Locations.save_location(current_location)
	if error != OK: push_warning("Cannot save location: " + error_string(error))

func _quit_game() -> void:
	if quitting: return
	quitting = true
	if is_instance_valid(golf_activity):golf_activity.cancel_loading()
	avatar_menu.quit_button.disabled = true
	set_process(false)
	motor.set_physics_process(false)
	_save_user_settings()
	_save_journal()
	game.tackle.save_profile()
	if is_instance_valid(network) and network.active: network.leave()
	ambience.stop()
	fishing_feedback.set_process(false)
	for type in ["AudioStreamPlayer", "AudioStreamPlayer3D"]:
		for player in find_children("*", type, true, false): player.stop()
	# Let the audio mixer release queued streaming buffers before engine shutdown.
	await get_tree().create_timer(.3).timeout
	get_tree().quit()

func _select_rig(value:int)->void:
	if not game.select_rig(value):return
	rod_visual.equip(game.tackle.equipped,game.is_fly_fishing(),game.is_feeder_fishing(),game.is_lure_fishing())
	rod_status.update_bait();rod_status.show_bait();_update_line();hud.queue_redraw();_save_player_preferences()

func _select_bait(index: int) -> void:
	var previous: int = game.bait
	game.select_bait(index)
	if game.bait != previous and is_instance_valid(rod_status): rod_status.show_bait()
	_save_player_preferences()
	hud.queue_redraw()

func _left_button(button: String) -> void:
	if is_instance_valid(golf_activity) and golf_activity.active: return
	if is_instance_valid(bbq) and bbq.holds(0) and not fish_guide.held and not menu_open:
		if button=="ax_button":bbq.use(0,bbq.hovered,true)
		return
	if rig_radial.opened:return
	if is_instance_valid(shoulder_radio) and shoulder_radio.held:return
	if fish_guide.held:
		if button == "trigger_click": fish_guide.photo_camera.toggle(); return
		if button == "ax_button": fish_guide.page(1)
		elif button == "by_button": fish_guide.page(-1)
		return
	if menu_open: return
	if button == "trigger_click" and _catch_grip_active():
		_primary_action()
	elif button == "ax_button":
		_select_bait((game.bait + 1) % game.bait_count())
	elif button == "by_button":
		_primary_action()

func _right_pressed(button: String) -> void:
	if is_instance_valid(golf_activity) and golf_activity.active: return
	if is_instance_valid(bbq) and bbq.holds(1) and not fish_guide.held and not menu_open and button!="by_button":
		if button=="ax_button":bbq.use(1,bbq.hovered,true)
		return
	if button=="primary_click":rig_radial.toggle();return
	if rig_radial.opened and button!="by_button":return
	if fish_guide.held:
		if button == "trigger_click": fish_guide.photo_camera.capture()
		elif button == "ax_button": fish_guide.photo_camera.toggle_selfie()
		return
	if button == "by_button":
		_toggle_avatar_menu()
		return
	if menu_open:
		if button == "trigger_click": _menu_click(true)
		return
	if button == "trigger_click" and game.state in [Session.State.READY, Session.State.LOST] and not rod_holster.stowed:
		if game.state == Session.State.LOST: game.reset()
		_begin_cast()
		cast_last_tip = _tracked_cast_tip()
		peak_speed = 0.0
	elif button == "ax_button" and game.state in [Session.State.LANDED, Session.State.LOST]:
		_primary_action()

func _right_released(button: String) -> void:
	if is_instance_valid(golf_activity) and golf_activity.active: return
	if button=="primary_click":return
	if rig_radial.opened:return
	if fish_guide.held: return
	if menu_open:
		if button == "trigger_click": _menu_click(false)
		return
	if button == "trigger_click" and casting:
		# Input can release before this frame's process callback samples the pose.
		if xr and right.get_has_tracking_data() and tracking_manager.focused:
			_sample_cast_swing((Time.get_ticks_usec()-cast_sample_us)/1000000.0)
		var measured_strokes:int=game.fly.strokes
		game.fly.charging = false
		if game.fly.strokes > 0 and cast_motion.release_allowed(controller_local_pose(1) * rod_holster.HELD_POSE, head.position.y, cast_swing_axis) and right.get_has_tracking_data() and tracking_manager.focused:
			_cast(game.fly.cast_power())
		else:
			game.message = "Hold trigger, sweep back then forward, and release."
		print("CAST_RESULT ",JSON.stringify({"monotonic_us":Time.get_ticks_usec(),"strokes":measured_strokes,"back_m":cast_motion.stroke_back,"forward_m":cast_motion.stroke_forward,"raised":cast_motion.raised,"head_aim":head_aimed_casting,"launched":game.state==Session.State.CASTING,"swing":cast_motion.swing_travel,"swing_speed_m_s":cast_motion.swing_speed,"axis":cast_swing_axis,"message":game.message}))
		if not cast_trace.is_empty():print("CAST_TRACE ",JSON.stringify(cast_trace))
		casting = false

func _primary_action() -> void:
	match game.state:
		Session.State.READY:
			game.message = "Hold trigger, sweep back then forward, and release." if xr else "Hold SPACE for the backswing, then release to cast."
		Session.State.WAITING, Session.State.BITE:
			game.strike()
		Session.State.LANDED, Session.State.LOST:
			game.reset()
			fish_display.visible = false
			catch_in_hand = false
			motor.catch_controls = false
			_update_line()

func _cast_direction() -> Vector3:
	var direction := -head.global_basis.z if xr else -rod.global_basis.z
	if xr and not head_aimed_casting:
		direction = preload("res://scripts/cast_motion.gd").controller_axis(controller_pose(1) * rod_holster.HELD_POSE)
	direction.y = 0
	if direction.length() < 0.1:
		direction = -origin.global_basis.z
		direction.y = 0
	return direction.normalized() if direction.length() > 0.01 else Vector3.FORWARD

func _tracked_cast_tip() -> Vector3:
	return (controller_local_pose(1) * rod_holster.HELD_POSE) * Vector3(0, 0, -1.68)

func _strike_tip() -> Vector3:
	# Feeder strikes follow the physical rod, without avatar lag or quiver knocks.
	if xr and game.is_feeder_fishing():return _tracked_cast_tip()
	return origin.to_local(tip.global_position) if xr else tip.global_position

func _sample_cast_swing(delta: float) -> void:
	# Avatar IK can damp/lag the rendered tip. Cast from actual controller
	# translation and wrist rotation, in tracking-origin space like fly mending.
	var at := _tracked_cast_tip()
	var movement := at - cast_last_tip
	cast_last_tip = at
	cast_sample_us = Time.get_ticks_usec()
	if delta <= 0.0 or delta > .1 or not movement.is_finite() or movement.length() > maxf(.5, delta * 35.0):
		# Ignore discontinuities, retaining an already completed gesture.
		return
	var pose: Transform3D = controller_local_pose(1) * rod_holster.HELD_POSE
	var travel: float
	if head_aimed_casting:
		travel = cast_motion.sample(movement, pose, head.position.y, cast_swing_axis, game.fly.strokes > 0)
	else:
		travel = cast_motion.sample_controller(movement, delta, pose, cast_swing_axis, game.fly.strokes > 0)
	if "--vr-test-capture" in OS.get_cmdline_user_args():
		cast_trace.append({"us":cast_sample_us,"dt":delta,"tip":[at.x,at.y,at.z],"movement":[movement.x,movement.y,movement.z],"travel":travel,"raised":cast_motion.raised,"forward_m":cast_motion.stroke_forward,"back_m":cast_motion.stroke_back,"strokes":game.fly.strokes})
		if cast_trace.size()>360:cast_trace.pop_front()
	var speed := travel / delta
	peak_speed = maxf(peak_speed, maxf(0.0, speed))
	var previous_strokes: int = game.fly.strokes
	game.fly.stroke(delta, speed)
	if previous_strokes == 0 and game.fly.strokes > 0:
		game.message = "Swing ready — release trigger to cast."
		rod_status.show_notice("cast")
	elif game.fly.strokes > previous_strokes:
		_extend_fly_cast()
		cast_motion.retreat=0.0

func _extend_fly_cast() -> void:
	if xr and not head_aimed_casting: return
	if not casting or not game.is_fly_fishing() or not cast_aim_target.is_finite(): return
	var offset := cast_aim_target - cast_aim_anchor
	var candidate := cast_aim_anchor + offset.normalized() * minf(24.0, offset.length() + 2.0)
	if candidate.is_equal_approx(cast_aim_target) or not _cast_target_valid(candidate):
		rod_status.show_notice("stop")
		return
	cast_aim_target=candidate
	game.message="Cast extended — release trigger to cast."
	rod_status.show_notice("extend")

func _landing_distance(anchor: Vector3, direction: Vector3, reach := 24.0) -> float:
	# Trace at water level from the fish back to the bank/pier. A railing or
	# distant visual obstruction must not award a catch out in open water.
	var space := get_world_3d().direct_space_state
	var landing := .35
	# Raised decks can have air beneath them: also trace just below the deck.
	for height in [anchor.y, maxf(anchor.y, motor.global_position.y-.03)]:
		var start := anchor + direction * reach;start.y=height
		var end := anchor - direction * 2.0;end.y=height
		var ray := PhysicsRayQueryParameters3D.create(start,end,1)
		for i in 24:
			var hit := space.intersect_ray(ray)
			if hit.is_empty():break
			if hit.collider.get_meta("role", "") == "floor":
				landing=maxf(landing,(hit.position-anchor).dot(direction)+.25)
				break
			var ignored := ray.exclude
			ignored.append(hit.rid);ray.exclude=ignored
	# Match landing to the complete body clearance, including submerged slopes
	# and raised decks; a fish can reach the boundary without swimming under it.
	var radius := _fish_clearance()
	if not boundary_landing_direction.is_finite() or boundary_landing_direction.distance_to(direction) > .002 or not boundary_landing_anchor.is_equal_approx(anchor) or not is_equal_approx(radius,boundary_landing_radius):
		var start := fish_boundary.recover(anchor + direction * maxf(reach, 30.0), direction, radius)
		var edge := fish_boundary.clip_motion(start, anchor, radius)
		boundary_landing = maxf(.35, (edge-anchor).dot(direction) + .03)
		boundary_landing_direction = direction; boundary_landing_anchor = anchor; boundary_landing_radius = radius
	return maxf(landing, boundary_landing)

func _configure_fishing_grid(id: String) -> void:
	# Keep every feeding centre outside the full body/dive envelope of local
	# regular fish. Relocate sectors, not the player's free water-surface aim.
	var length_ := .0
	for index in Session.species_for_location(id, false):
		length_ = maxf(length_, float(Session.SPECIES[index].length)*.01)
	fish_boundary.set_minimum_height(water_level-(maxf(.18,length_*.36)+length_*.30+.36))
	var clearance := maxf(1.25, length_*.60+.35)
	var spawn: Vector3 = foreground.get_meta("spawn")
	var anchor := Vector3(spawn.x+.3,water_level+.05,spawn.z-.35)
	var view := spawn+Vector3(0,1.65,0)
	var centres: Array[Vector3] = []
	for sector in Session.Population.SECTOR_COUNT:
		var desired := Session.Population.sector_center(sector,water_level+.05)
		var best := Vector3(INF,INF,INF)
		var best_score := INF
		# Search the castable disc. Retain original centres where they fit and
		# choose nearby open-water cells around irregular banks and boulders.
		for x in range(-23,24):
			for z in range(-25,2):
				var at := Vector3(float(x),water_level+.05,float(z))
				var distance := anchor.distance_to(at)
				if distance < 5.5 or distance > 23.0: continue
				var score := at.distance_squared_to(desired)
				if score >= best_score: continue
				var separated := true
				for centre in centres:
					if centre.distance_to(at)<3.0: separated=false;break
				if not separated or fish_boundary.blocked(at,clearance) or cast_water_boundary.blocked(at,.05): continue
				if cast_water_boundary.segment_obstructed(view,at) or cast_water_boundary.segment_obstructed(spawn+Vector3(0,1.1,0),at): continue
				# Geometry is immediately available here; physics colliders settle
				# on the next tick. The surface boundary includes decks and rocks.
				best=at;best_score=score
		if best.is_finite(): centres.append(best)
	if centres.size()==Session.Population.SECTOR_COUNT:
		game.population.set_layout(id,centres)
	else:
		push_error("Unable to place every fishing sector in open water: " + id)
	fish_boundary.set_minimum_height(water_level-.45)

func _casting_anchor() -> Vector3:
	var at := rod.global_position
	if xr and not head_aimed_casting: at = controller_pose(1).origin
	return Vector3(at.x, water_level + .05, at.z)

func _begin_cast() -> void:
	if casting: return
	cast_aim_target = _projected_cast_target()
	cast_aim_anchor = _casting_anchor()
	cast_swing_axis = origin.global_basis.inverse() * _cast_direction()
	cast_motion = preload("res://scripts/cast_motion.gd").new()
	cast_trace.clear()
	casting = true
	cast_last_tip = _tracked_cast_tip() if xr else Vector3.ZERO
	cast_sample_us = Time.get_ticks_usec()
	desktop_cast_extensions=0
	game.fly.begin_cast(game.is_fly_fishing())

func _projected_cast_target() -> Vector3:
	if xr and not head_aimed_casting:
		# There is no headset target to lock; preview the measured forward swing.
		if not casting or game.fly.strokes == 0 or cast_motion.swing_travel.length_squared() < .000001:
			return Vector3(INF, INF, INF)
		var direction: Vector3 = origin.global_basis * cast_motion.swing_travel
		direction.y = 0.0
		if direction.length_squared()<.000001:return Vector3(INF,INF,INF)
		return cast_aim_anchor + direction.normalized() * cast_motion.swing_distance()
	# Trigger-down freezes both the visible marker and the release destination.
	if casting: return cast_aim_target
	var ray_origin := head.global_position
	var ray := -head.global_basis.z
	if not xr:
		# Desktop right-drag controls yaw and downward aim independently of the
		# animated backswing. The initial rod pose aims about twelve metres out.
		var pitch := clampf(rod.rotation.x - .23, .045, 1.2)
		ray = Basis(Vector3.UP, rod.global_rotation.y) * Vector3(0, -sin(pitch), -cos(pitch))
	var hit = Plane(Vector3.UP, water_level + .05).intersects_ray(ray_origin, ray)
	if hit == null:
		# A level/upward view has a valid far cast; overhand preparation often
		# raises the gaze before trigger-down.
		var forward := Vector3(ray.x,0,ray.z)
		if forward.length_squared()<.001: return Vector3(INF,INF,INF)
		return _casting_anchor()+forward.normalized()*24.0
	var anchor := _casting_anchor()
	var offset: Vector3 = hit - anchor
	if offset.length_squared() < .001: return Vector3(INF, INF, INF)
	return anchor + offset.normalized() * clampf(offset.length(), 5.0, 24.0)

func _cast_target_valid(target: Vector3) -> bool:
	# Target only the water surface. The larger underwater fish envelope must
	# not hide valid aiming space or impose arbitrary world-axis cutoffs.
	if not target.is_finite() or cast_water_boundary.blocked(target, .05): return false
	var space := get_world_3d().direct_space_state
	# A visible target must be in open water, not inside a deck, rock or bank.
	var sight_origin := controller_pose(1).origin if xr and not head_aimed_casting else head.global_position
	var sight := PhysicsRayQueryParameters3D.create(sight_origin,target,1,cast_barriers)
	var surface := PhysicsRayQueryParameters3D.create(target+Vector3.UP*4.0,target,1,cast_barriers)
	return space.intersect_ray(sight).is_empty() and space.intersect_ray(surface).is_empty()

func _update_cast_aim() -> void:
	if not is_instance_valid(aim_marker):
		var ring := TorusMesh.new()
		ring.inner_radius = .17; ring.outer_radius = .21; ring.rings = 24; ring.ring_segments = 8
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(.65, .88, .74, .55)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		aim_marker = mesh_node(ring, self, Vector3.ZERO, mat)
		aim_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var target := _projected_cast_target()
	aim_marker.visible = game.state == Session.State.READY and not rod_holster.stowed and not menu_open and not fish_guide.held and _cast_target_valid(target)
	if aim_marker.visible: aim_marker.global_position = target

func _cast(_power: float) -> void:
	if game.state != Session.State.READY or rod_holster.stowed: return
	var endpoint := _projected_cast_target()
	if not _cast_target_valid(endpoint):
		game.message = "Swing toward open water, then release the trigger." if xr and not head_aimed_casting else "Aim at open water until the casting marker appears."
		return
	fish_safe_position = endpoint
	boundary_landing_direction = Vector3(INF, INF, INF)
	cast_anchor = cast_aim_anchor if casting else _casting_anchor()
	var direction := (endpoint - cast_anchor).normalized()
	var reach := cast_anchor.distance_to(endpoint)
	var landing := _landing_distance(cast_anchor, direction, reach)
	game.landing_distance = landing
	game.cast(reach, endpoint, cast_anchor)
	cast_start = tip.global_position
	cast_target = endpoint
	escape_offset = Vector3.ZERO
	fishing_feedback.cast_swish()

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(golf_activity) and golf_activity.active: return
	if is_instance_valid(bbq) and bbq.handle_input(event):return
	if not xr and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_J and not menu_open:
			rod_holster.set_stowed(not rod_holster.stowed)
			return
		if event.keycode == KEY_G and not menu_open:
			fish_guide.held = not fish_guide.held and fish_guide.can_grab()
			fish_guide.screen.queue_redraw()
			return
		if fish_guide.held:
			if event.keycode == KEY_C: fish_guide.photo_camera.toggle()
			elif event.keycode == KEY_SPACE: fish_guide.photo_camera.capture()
			elif event.keycode == KEY_F: fish_guide.photo_camera.toggle_selfie()
			elif event.keycode == KEY_LEFT: fish_guide.page(-1)
			elif event.keycode == KEY_RIGHT: fish_guide.page(1)
			elif event.keycode == KEY_ESCAPE: fish_guide.dock()
			return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_V:
		_toggle_avatar_menu()
		return
	if menu_open:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE: _toggle_avatar_menu()
		return
	if not xr and event is InputEventKey and event.keycode==KEY_TAB and not event.echo:
		if event.pressed:rig_radial.toggle()
		return
	if rig_radial.opened:return
	if not xr and game.state==Session.State.READY and not rod_holster.stowed and event is InputEventKey and event.keycode==KEY_SPACE and not event.echo:
		if event.pressed:
			_begin_cast()
		elif game.fly.charging:
			game.fly.charging=false
			if game.fly.charge_age>=.2:_cast(game.fly.cast_power())
			else:game.message="Hold SPACE briefly for the backcast, then release forward."
			casting = false
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE: _primary_action()
			KEY_1: _select_bait(0)
			KEY_2: _select_bait(1)
			KEY_3: _select_bait(2)
			KEY_4: _select_bait(3)
			KEY_5: _select_bait(4)
			KEY_6: _select_bait(5)
			KEY_ESCAPE: _quit_game()
	if not xr and not rod_holster.stowed and event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		rod.rotation.y = clampf(rod.rotation.y - event.relative.x * 0.004, -0.8, 0.8)
		rod.rotation.x = clampf(rod.rotation.x - event.relative.y * 0.004, -0.3, 1.2)
	if not xr and event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		motor.turn(-event.relative.x * 0.003)
		head.rotation.x = clampf(head.rotation.x - event.relative.y * 0.003, -1.0, 0.75)

func _update_tracking_warning(delta: float) -> void:
	# Focus loss is a compositor pause, not evidence of lost controllers.
	# Refresh before menu/guide/holster early returns so a stale warning clears.
	var missing: bool = xr and tracking_manager.focused and (not left.get_has_tracking_data() or not right.get_has_tracking_data())
	if missing and not menu_open and not fish_guide.held and not rod_holster.stowed:
		tracking_warning_time += maxf(delta, 0.0)
	else:
		tracking_warning_time = 0.0
	var show_warning := tracking_warning_time >= .5
	if hud.tracking_lost != show_warning:
		hud.tracking_lost = show_warning
		hud.queue_redraw()

func _process(delta: float) -> void:
	if is_instance_valid(golf_activity) and golf_activity.active:
		golf_activity.update_player(delta)
		return
	if is_instance_valid(rod_visual): rod_visual.equip(game.tackle.equipped,game.is_fly_fishing(),game.is_feeder_fishing(),game.is_lure_fishing())
	if server_only: return
	if menu_open or fish_guide.held or rig_radial.opened or (xr and not tracking_was_valid) or game.state!=Session.State.WAITING:
		game.lure.reset_motion()
	rod_holster.update_holster()
	fish_guide.update_device()
	if is_instance_valid(tracking_manager): tracking_manager.sample(delta)
	shoulder_radio.update()
	rig_radial.update()
	_update_tracking_warning(delta)
	rod_visual.visible = true
	rod.visible = rod_holster.stowed or not xr or right.get_has_tracking_data()
	catch_in_hand = _catch_grip_active()
	motor.catch_controls = fish_guide.held or catch_in_hand or (is_instance_valid(bbq) and (bbq.holds(0) or bbq.holds(1)) and not xr)
	if not xr: hud.visible = not menu_open and not fish_guide.held
	time += delta
	if not xr:
		var backswing: float = 1.35 * smoothstep(0.0, .3, game.fly.charge_age) if game.fly.charging else 0.0
		rod_visual.rotation.x = move_toward(rod_visual.rotation.x, backswing, delta * 7.0)
		tip.position = rod_visual.basis * Vector3(0, 0, -1.68)
	if fish_display.visible: catch_twitch.tick(delta)
	_update_avatar(delta)
	if avatar_loading: return
	if rig_radial.opened:
		casting=false;game.fly.charging=false;reel_tracker.engaged=false;_update_line();return
	if fish_guide.held:
		game.fly.charging=false;game.fly.release_strip(true)
		fight_input.reset()
		casting = false
		reel_tracker.engaged = false
		last_tip = _strike_tip()
		if fish_display.visible: _update_catch(0)
		_update_line()
		return
	if menu_open:
		game.fly.charging=false;game.fly.release_strip(true)
		fight_input.reset()
		_layout_avatar_menu()
		_update_menu_pointer()
		if xr and right.get_has_tracking_data():
			var scroll_axis := right.get_vector2("primary").y
			if absf(scroll_axis) > 0.2: avatar_menu.scroll_page(-scroll_axis * 650.0 * delta)
		last_tip = _strike_tip()
		_update_line()
		return
	if rod_holster.stowed:
		game.fly.charging=false;game.fly.release_strip(true)
		_update_line()
		return
	gesture_cooldown = maxf(0.0, gesture_cooldown - delta)
	var reel := 0.0
	if xr:
		# The offhand commonly leaves the cameras during a backswing. It is
		# required for fighting/reeling, but cannot cancel a one-handed cast.
		var tracked: bool = right.get_has_tracking_data() and (left.get_has_tracking_data() or game.state in [Session.State.READY, Session.State.CASTING]) and (not is_instance_valid(tracking_manager) or tracking_manager.focused)
		rod.visible = right.get_has_tracking_data()
		if not tracked:
			game.fly.charging=false;game.fly.release_strip(true)
			fight_input.reset()
			tracking_was_valid = false
			casting = false
			reel_tracker.engaged = false
			if game.state == Session.State.LANDED and fish_display.visible:
				_update_catch(delta)
				_update_line()
			hud.queue_redraw()
			return
		if not tracking_was_valid:
			last_tip = _strike_tip()
			tracking_was_valid = true
		# Locomotion is not a fishing gesture. Use origin-local tracked motion.
		velocity = origin.global_basis * ((_strike_tip() - last_tip) / maxf(delta, 0.001))
		if casting:
			_sample_cast_swing(delta)
		var tracked_rod: Transform3D = controller_local_pose(1) * rod_holster.HELD_POSE
		var reel_pos := tracked_rod.affine_inverse() * controller_local_pose(0).origin - crank.position
		if reel_tracker.engaged:
			reel = reel_tracker.sample(reel_pos + reel_tracking_offset, _reel_grab_pressed(), delta, game.is_fly_fishing())
		else:
			# Acquire the visible handle, then measure raw relative tracking only.
			var visible_reel_pos := rod.to_local(controller_pose(0).origin) - crank.position
			reel = reel_tracker.sample(visible_reel_pos, _reel_grab_pressed(), delta, game.is_fly_fishing())
			if reel_tracker.engaged: reel_tracking_offset = visible_reel_pos - reel_pos
		if game.is_fly_fishing():
			# Sample current tracking input; cached IK attachments are for rendering.
			# Head motion and locomotion must not become a strip through solver lag.
			var strip_rate:float=_sample_fly_strip(delta)
			# The handle and loose line are separate grips; only one owns the hand.
			if not reel_tracker.engaged: reel=strip_rate
			var raw_tip:Vector3=(controller_local_pose(1)*preload("res://scripts/rod_holster.gd").HELD_POSE)*Vector3(0,0,-1.68)
			var mend:int=game.fly.sample_mend(raw_tip,origin.global_basis,delta,game.state==Session.State.WAITING)
			if mend!=0:_mend_fly(mend)
		if velocity.y > 0.9 and (game.state == Session.State.BITE or (game.is_feeder_fishing() and game.state==Session.State.WAITING and game.feeder.nibbling)):
			game.strike()
		if game.state == Session.State.FIGHT:
			var facing := Basis(Vector3.UP,atan2(head.global_basis.z.x,head.global_basis.z.z))
			var direction := fight_input.sample(game.cue,origin.global_basis.inverse()*(tip.global_position-head.global_position),origin.global_basis.inverse()*facing, -rod.global_basis.z.y)
			game.gesture(direction)
			if game.jump_time>0.0:
				game.tug(fight_input.sample_tug(game.jump_count,game.cue,origin.global_basis.inverse()*(tip.global_position-head.global_position),delta,origin.global_basis.inverse()*facing))
		else: fight_input.reset()
	else:
		if game.fly.charging:
			game.fly.stroke(delta,0)
			if game.is_fly_fishing():
				var extensions := mini(8, int(maxf(0, game.fly.charge_age-.5)/.5))
				while desktop_cast_extensions < extensions:
					_extend_fly_cast();desktop_cast_extensions+=1
		if game.is_fly_fishing() and game.state==Session.State.WAITING:
			if Input.is_action_just_pressed("ui_left"):_mend_fly(-1)
			elif Input.is_action_just_pressed("ui_right"):_mend_fly(1)
		reel = (1.8 if Input.is_key_pressed(KEY_SHIFT) else 1.0) if Input.is_key_pressed(KEY_R) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) else 0.0
		game.gesture(0 if Input.is_key_pressed(KEY_LEFT) else 1 if Input.is_key_pressed(KEY_RIGHT) else 2 if Input.is_key_pressed(KEY_UP) else -1)
		if game.jump_time>0:
			game.tug(0 if Input.is_action_just_pressed("ui_left") else 1 if Input.is_action_just_pressed("ui_right") else -1)
	# Retrieval accepts either winding direction; the handle follows the actual hand.
	crank.rotation.x += reel_tracker.angular_delta if xr else 0.0 if game.is_fly_fishing() else reel * TAU * delta
	if xr and reel_tracker.engaged and is_instance_valid(avatar):
		_update_reel_hand()
		avatar.left_target = desktop_left
		avatar.xr_pose.left = avatar.render_frame.affine_inverse() * desktop_left.global_transform
		avatar.xr_pose.body.erase("left_hand")
		avatar.xr_pose.body.erase("left_curls")
		avatar.left_curl = .8
	fishing_feedback.reel_rate = reel
	if game.state == Session.State.FIGHT and game.cue >= 0:
		if game.jump_time<=0:escape_offset=escape_offset.move_toward(fish_escape_direction() * 1.1, delta * 1.8)
	last_tip = _strike_tip()
	var prior_takeovers: int=game.takeover_count
	if game.is_fly_fishing() and game.state==Session.State.FIGHT:
		game.fly.current_speed=Session.Fly.current(bobber.global_position,game.location_id).length()
	_constrain_fish_to_water()
	var was_jumping: bool=game.jump_time>0
	if game.state in [Session.State.WAITING,Session.State.BITE,Session.State.FIGHT]:
		game.landing_distance=_landing_distance(cast_anchor,(cast_target-cast_anchor).normalized(),game.distance)
	var lure_motion:=_sample_lure_motion(delta)
	game.tick(minf(delta, 0.05), reel, maxf(0.0, -rod.global_basis.z.y), xr and reel_tracker.engaged,lure_motion)
	if game.fly_reel_penalty: rod_status.show_notice("warning")
	if was_jumping and game.jump_time<=0 and game.state==Session.State.FIGHT:
		var landing: Vector3=hooked_fish.landing_position()
		cast_target=Vector3(landing.x,water_level+.05,landing.z)
		game.distance=cast_anchor.distance_to(cast_target)
		escape_offset=Vector3.ZERO
	if game.takeover_count!=prior_takeovers: fight_input.reset()
	hooked_fish.age+=delta
	_settle_fish_escape()
	_constrain_river_fish(delta)
	if game.is_fly_fishing() and last_state==Session.State.BITE and game.state==Session.State.FIGHT:
		cast_target=game.fly.start+game.fly.offset
		game.distance=cast_anchor.distance_to(cast_target)
	_constrain_fish_to_water()
	if game.state != last_state:
		if game.state == Session.State.BITE:
			_tone(880, 0.18)
		elif game.state == Session.State.LANDED:
			_show_fish()
			_save_journal()
			if game.tackle.save_profile() != OK:
				game.message += "\nCould not save shekels."
		elif game.state == Session.State.LOST:
			casting=false;peak_speed=0;fight_input.reset();reel_tracker.engaged=false
			escape_offset=Vector3.ZERO;catch_in_hand=false;fish_display.hide()
			_tone(180, 0.18)
		last_state = game.state
	if fish_display.visible:
		_update_catch(delta)
		hud.queue_redraw()
	_update_line()

func _catch_mesh_bounds(node: Node3D, parent_transform := Transform3D.IDENTITY) -> AABB:
	var transform := parent_transform * node.transform
	var result: AABB = transform * node.get_aabb() if node is MeshInstance3D else AABB()
	for child in node.get_children():
		if child is Node3D:
			var box := _catch_mesh_bounds(child, transform)
			if box.has_volume(): result = result.merge(box) if result.has_volume() else box
	return result

func _catch_mouth() -> Vector3:
	return Vector3(catch_bounds.end.x, catch_bounds.get_center().y, catch_bounds.get_center().z)

func _catch_grip_active() -> bool:
	return xr and game.state == Session.State.LANDED and fish_display.visible and not fish_guide.held and not shoulder_radio.held and left.get_has_tracking_data() and left.get_float("grip") > .55 and tracking_manager.focused

func _update_catch(delta: float) -> void:
	catch_in_hand = _catch_grip_active()
	motor.catch_controls = fish_guide.held or catch_in_hand or (is_instance_valid(bbq) and (bbq.holds(0) or bbq.holds(1)) and not xr)
	if not xr:
		fish_display.global_position = head.global_position - head.global_basis.z * 1.1 - Vector3.UP * 0.08
		fish_display.rotation = Vector3(0, time * 0.35, 0)
		return
	var stick := Vector2.ZERO
	if catch_in_hand:
		for controller in [left, right]:
			if controller.get_has_tracking_data(): stick += motor.deadzone(controller.get_vector2("primary"))
	stick = stick.limit_length()
	# Both stick axes spin around gravity-up; inspection never tips the fish sideways.
	var spin := clampf(-stick.x + stick.y, -1.0, 1.0)
	catch_rotation = (Quaternion(Vector3.UP, spin * delta * 1.8) * catch_rotation).normalized()
	if catch_in_hand:
		var orientation := Basis(catch_rotation) * Basis(Vector3.BACK, PI / 2)
		# Grip the string, leaving a short vertical drop to the mouth.
		var mouth := controller_pose(0).origin - Vector3.UP * 0.08
		fish_display.global_transform = Transform3D(orientation, mouth - orientation * _catch_mouth())
	else:
		# +X is the mouth: keep it attached while the body hangs below the tip.
		var orientation := Basis(catch_rotation) * Basis(Vector3.BACK, PI / 2)
		var hook := tip.global_position - Vector3.UP * 0.28
		fish_display.global_transform = Transform3D(orientation, hook - orientation * _catch_mouth())

func _fish_clearance() -> float:
	# Generous body envelope includes deep-bodied bream, twitch and dive travel.
	var length_: float = float(Session.SPECIES[game.fish_index].length) * .01
	var depth := maxf(.18, length_*.36) + length_*.30 + .36 if game.state == Session.State.FIGHT else .45
	fish_boundary.set_minimum_height(water_level-depth)
	return maxf(.20, length_*.60 + .10) if game.state == Session.State.FIGHT else .25

func _constrain_fish_to_water() -> void:
	if game.state != Session.State.FIGHT:
		game.at_ground_boundary = false
		return
	var direction := (cast_target-cast_anchor).normalized()
	var desired: Vector3 = cast_anchor + direction * game.distance + escape_offset
	var radius := _fish_clearance()
	if not fish_safe_position.is_finite(): fish_safe_position = desired
	fish_safe_position = fish_boundary.recover(fish_safe_position, desired-cast_anchor, radius)
	var safe := fish_boundary.clip_motion(fish_safe_position, desired, radius)
	if not safe.is_equal_approx(desired):
		cast_target = safe; escape_offset = Vector3.ZERO
		game.distance = cast_anchor.distance_to(safe)
	fish_safe_position = safe
	game.set_ground_boundary(fish_boundary.blocked(safe, radius+.20))

func _constrain_river_fish(delta:float)->void:
	if not game.is_fly_fishing() or game.state!=Session.State.FIGHT or game.jump_time>0:return
	var direction:Vector3=(cast_target-cast_anchor).normalized()
	var at:Vector3=cast_anchor+direction*game.distance+escape_offset
	at+=Session.Fly.current(at,game.location_id)*delta*.18
	# Let retrieval reach the actual sloped shoreline; landing uses its collider.
	at.z=clampf(at.z,-18.3,-1.5);at.x=clampf(at.x,-110,110)
	cast_target=at-escape_offset
	game.distance=cast_anchor.distance_to(cast_target)

func _settle_fish_escape() -> void:
	if game.state != Session.State.FIGHT or game.cue >= 0 or escape_offset.is_zero_approx(): return
	# The counter ends where the fish actually swam. Rebase the retrieval ray
	# around the original angler anchor, retaining both lateral and outward runs.
	# Subsequent reeling and counters then start from this new position.
	var direction := (cast_target - cast_anchor).normalized()
	var position_from_anchor: Vector3 = direction * game.distance + escape_offset
	game.distance = position_from_anchor.length()
	cast_target = cast_anchor + position_from_anchor
	escape_offset = Vector3.ZERO

func fish_escape_direction() -> Vector3:
	# Cues name the COUNTER: a left pull opposes a rightward escape.
	var sideways := origin.global_basis.x.normalized()
	if xr:
		sideways = (origin.global_basis * fight_input.cue_basis).x.normalized() if fight_input.previous_cue == game.cue else head.global_basis.x.normalized()
	if game.cue == 0: return sideways
	if game.cue == 1: return -sideways
	var away := cast_target - cast_anchor
	away.y = 0
	return away.normalized() if away.length_squared() > .001 else Vector3.FORWARD

func _sample_fly_strip(delta: float) -> float:
	var outlet := origin.to_local(rod.to_global(Session.Fly.LINE_OUTLET))
	var guide := origin.to_local(rod.to_global(Session.Fly.LINE_GUIDE))
	var available: bool = not shoulder_radio.held and not reel_tracker.engaged and game.state in [Session.State.READY, Session.State.CASTING, Session.State.WAITING, Session.State.BITE, Session.State.FIGHT]
	return game.fly.strip(controller_local_pose(0).origin, left.get_float("grip"), delta, outlet, guide, available)

func _sample_lure_motion(delta:float)->float:
	if not game.is_lure_fishing() or game.state!=Session.State.WAITING:
		game.lure.reset_motion();return 0.0
	# Raw controller input avoids a feedback loop through the solved avatar hand.
	var input_tip:Vector3=(controller_local_pose(1)*rod_holster.HELD_POSE)*Vector3(0,0,-1.68) if xr else origin.to_local(tip.global_position)
	var direction:Vector3=origin.global_basis.inverse()*(game.cast_position-game.retrieve_origin)
	direction.y=0
	var facing:=Basis.looking_at(direction.normalized()) if direction.length_squared()>.001 else Basis.IDENTITY
	return game.lure.sample_motion(input_tip,facing,delta)

func _fly_hand_position() -> Vector3:
	if is_instance_valid(avatar):
		var grip = avatar.hand_grip_pose(true)
		if grip is Transform3D: return grip.origin
	return controller_pose(0).origin

func _append_fly_grip_line() -> void:
	if not game.is_fly_fishing():return
	line_mesh.surface_add_vertex(rod.to_global(Session.Fly.LINE_OUTLET))
	if xr and game.fly.strip_engaged:line_mesh.surface_add_vertex(_fly_hand_position())
	line_mesh.surface_add_vertex(rod.to_global(Session.Fly.LINE_GUIDE))

func _update_line() -> void:
	var feeder_load:float=game.feeder.tip_load(game.state==Session.State.BITE) if game.is_feeder_fishing() and game.state in [Session.State.WAITING,Session.State.BITE] else -1.0
	rod_visual.update_tip(game.state,time,feeder_load)
	bobber.rotation = Vector3.ZERO
	rod_status.bait_visual.pose_lure(Vector3.ZERO,false)
	# Keep the tracked input anchor fixed: visual tip knocks must not set the hook.
	var line_tip:Vector3=rod_visual.to_global(rod_visual.quiver.end) if game.is_feeder_fishing() else tip.global_position
	_update_cast_aim()
	if game.state!=Session.State.FIGHT and is_instance_valid(hooked_fish):hooked_fish.update(0)
	var tension_color := Color("d8f5e5")
	if game.state == Session.State.FIGHT:
		if game.tension < .25: tension_color = Color("53a9ef").lerp(tension_color, game.tension / .25)
		elif game.tension > .75: tension_color = tension_color.lerp(Color("ff5344"), (game.tension - .75) / .25)
	if game.is_fly_fishing() and game.state!=Session.State.FIGHT:tension_color=Color("d9e6a4")
	line_material.albedo_color = tension_color
	var active: bool = game.state in [Session.State.CASTING, Session.State.WAITING, Session.State.BITE, Session.State.FIGHT]
	var ready: bool = game.state == Session.State.READY and not rod_holster.stowed
	bobber.visible = (active or ready) and game.rig==Session.Rig.CLASSIC
	rod_status.feeder_visual.visible=(active or ready) and game.is_feeder_fishing()
	bobber.scale=Vector3.ONE*(.32 if game.is_fly_fishing() else 1.0)
	if game.is_fly_fishing() and game.bait==0:bobber.hide()
	if is_instance_valid(rod_status): rod_status.bait_visual.visible = ready or active
	line_mesh.clear_surfaces()
	if xr and game.state == Session.State.LANDED and fish_display.visible:
		line_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		line_mesh.surface_add_vertex(line_tip)
		if catch_in_hand: line_mesh.surface_add_vertex(controller_pose(0).origin)
		line_mesh.surface_add_vertex(fish_display.to_global(_catch_mouth()))
		line_mesh.surface_end()
		return
	if ready:
		bobber.global_position = line_tip + Vector3.DOWN * .30
		rod_status.feeder_visual.global_position=bobber.global_position
		rod_status.bait_visual.global_position = bobber.global_position + Vector3.DOWN * (.0 if game.is_lure_fishing() or game.is_feeder_fishing() else .18)
		line_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		_append_fly_grip_line()
		line_mesh.surface_add_vertex(line_tip)
		if game.is_fly_fishing() and game.fly.charging:
			for i in 24:
				var t:=i/23.0
				line_mesh.surface_add_vertex(line_tip+Vector3(sin(t*TAU)*.5,sin(t*PI)*1.1,cos(game.fly.charge_age*5)*sin(t*PI)*3.0))
		line_mesh.surface_add_vertex(bobber.global_position)
		if not game.is_feeder_fishing():line_mesh.surface_add_vertex(rod_status.bait_visual.global_position)
		line_mesh.surface_end()
		return
	if not active:
		if is_instance_valid(hooked_fish):hooked_fish.update(0)
		return
	if game.state == Session.State.CASTING:
		var progress: float = 1.0 - game.timer / 0.8
		bobber.position = cast_start.lerp(cast_target, progress) + Vector3.UP * sin(progress * PI) * 2.2
	elif game.state == Session.State.FIGHT:
		# Walking does not teleport the fish to the world origin or win a fight.
		var direction := (cast_target - cast_anchor).normalized()
		bobber.position = cast_anchor + direction * game.distance + escape_offset + Vector3(0, 0.02, 0)
		if game.at_ground_boundary and game.jump_time <= 0:
			# A blocked fish is still fighting. Animate the float independently
			# of fish travel so the shoreline constraint cannot freeze this cue.
			bobber.position.y += maxf(0.0, sin(time * 13.0)) * .07 + sin(time * 31.0) * .012
			bobber.rotation = Vector3(sin(time * 23.0) * .16, 0, sin(time * 29.0) * .20)
		if game.submerge==Session.Submerge.PULL:
			var progress: float = 1.0-game.submerge_time/(Session.SUBMERGE_WARNING+Session.SUBMERGE_DURATION)
			bobber.position.y-=sin(progress*PI)*.28
	else:
		if game.is_fly_fishing():cast_target=game.fly.start+game.fly.offset
		else:cast_target=game.cast_position
		bobber.position = cast_target + Vector3(0, sin(time * 3.0) * 0.025, 0)
		if game.state == Session.State.BITE:
			bobber.position.y -= 0.10 + sin(time * 22) * 0.05
	if game.is_lure_fishing():
		if game.state in [Session.State.WAITING,Session.State.BITE]:bobber.position.y=water_level-game.lure.depth
		rod_status.bait_visual.global_position=bobber.global_position
		rod_status.bait_visual.pose_lure(tip.global_position-bobber.global_position,game.state in [Session.State.WAITING,Session.State.BITE,Session.State.FIGHT])
	elif game.is_feeder_fishing():
		if game.state in [Session.State.WAITING,Session.State.BITE]:bobber.position.y=water_level-game.feeder.drop()
		rod_status.feeder_visual.global_position=bobber.global_position
		rod_status.bait_visual.global_position=bobber.global_position
	elif game.is_fly_fishing():
		rod_status.bait_visual.global_position=bobber.global_position+Vector3.DOWN*(.4 if game.bait==1 else 0.0)
		if game.state==Session.State.BITE and game.bait==0:rod_status.bait_visual.position.y-=.04
	else:
		rod_status.bait_visual.global_position=bobber.global_position+Vector3.DOWN*(.18 if game.state==Session.State.CASTING else .4)
	hooked_fish.update(0)
	if game.jump_time>0:
		bobber.hide()
		rod_status.feeder_visual.hide()
		rod_status.bait_visual.hide()
	var line_end:Vector3=bobber.position
	if game.jump_time>0 and hooked_fish.visible:line_end=hooked_fish.mouth_position()
	line_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	_append_fly_grip_line()
	for i in range(25):
		var t := i / 24.0
		var p := line_tip.lerp(line_end, t)
		if game.is_fly_fishing():
			if game.state==Session.State.CASTING:p.y+=sin(t*TAU)*sin((1.0-game.timer/.8)*PI)*1.1
			elif game.state==Session.State.WAITING:p.x+=sin(t*PI)*(-(1.0-game.fly.drag)*.7+game.fly.mend_bend())
		p.y -= sin(t * PI) * (lerpf(.65, .025, game.tension) if game.state == Session.State.FIGHT else 0.5)
		if game.is_fly_fishing() and game.state==Session.State.WAITING:p.y=maxf(p.y,water_level+.01)
		line_mesh.surface_add_vertex(p)
	if rod_status.bait_visual.visible and not game.is_feeder_fishing():
		line_mesh.surface_add_vertex(rod_status.bait_visual.global_position)
	line_mesh.surface_end()

func _mend_fly(direction:int) -> bool:
	if not game.is_fly_fishing() or game.state!=Session.State.WAITING or game.fly.mend_cooldown>0 or direction==0:return false
	var improved:bool=game.fly.mend(direction)
	game.message="Upstream mend · Natural drift" if improved else "Downstream mend · More drag"
	rod_status.show_notice("mend" if improved else "warning")
	if xr and right.get_has_tracking_data():right.trigger_haptic_pulse("haptic",0.0,.24 if improved else .12,.09 if improved else .045,0.0)
	return true

func _show_fish() -> void:
	for child in fish_display.get_children():
		fish_display.remove_child(child)
		child.queue_free()
	var species: Dictionary = Session.SPECIES[game.fish_index]
	var model_path: String = species.get("model", "res://assets/models/european_perch.glb" if game.fish_index == 0 else "")
	if not model_path.is_empty():
		var scene: PackedScene = load(model_path)
		var model := scene.instantiate() as Node3D
		model.rotate_y(float(species.get("model_yaw", 0.0)))
		fish_display.add_child(model)
	else:
		var body := SphereMesh.new()
		body.radius = 0.12
		body.height = 0.24
		var n := mesh_node(body, fish_display, Vector3.ZERO, material(Color("9d9860") if game.fish_index == 1 else Color("537c5b"), 0.3))
		n.scale = Vector3(2.5, 0.9, 0.65)
		var tail := PrismMesh.new()
		tail.size = Vector3(0.17, 0.22, 0.025)
		mesh_node(tail, fish_display, Vector3(-0.33, 0, 0), material(Color("787648")))
	var length_cm: float=game.journal.back().length if not game.journal.is_empty() else species.length
	catch_bounds=preload("res://scripts/fish_size.gd").fit(fish_display,length_cm)
	catch_twitch.configure(fish_display,catch_bounds,game.fish_index*7919+game.catches)
	catch_rotation = Quaternion.IDENTITY
	catch_in_hand = false
	motor.catch_controls = false
	fish_display.visible = true

func _tone(frequency: float, duration: float) -> void:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var bytes := PackedByteArray()
	var count := int(duration * 22050)
	bytes.resize(count * 2)
	for i in range(count):
		var value := sin(TAU * frequency * i / 22050.0) * 0.15 * sin(PI * i / count)
		bytes.encode_s16(i * 2, int(value * 32767))
	audio.stream = stream
	audio.play()

func _save_journal() -> void:
	if is_instance_valid(fish_guide): fish_guide.ingest(game.journal)
	var file := FileAccess.open("user://journal.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(game.journal, "\t"))

func _load_journal() -> void:
	if FileAccess.file_exists("user://journal.json"):
		var data = JSON.parse_string(FileAccess.get_file_as_string("user://journal.json"))
		if data is Array:
			game.journal = data
			game.catches = data.size()
	if is_instance_valid(fish_guide): fish_guide.ingest(game.journal)

func _build_avatar_menu() -> void:
	avatar_menu = AvatarMenu.new()
	avatar_menu.library = avatars
	avatar_menu.size = Vector2(900, 650)
	if xr:
		avatar_menu_view = SubViewport.new()
		avatar_menu_view.size = Vector2i(1000, 720)
		avatar_menu_view.transparent_bg = true
		avatar_menu_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(avatar_menu_view)
		avatar_menu_view.add_child(avatar_menu)
		avatar_menu.position = Vector2(50, 30)
		var quad := QuadMesh.new()
		quad.size = Vector2(1.8, 1.296)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_texture = avatar_menu_view.get_texture()
		avatar_panel = mesh_node(quad, self, Vector3.ZERO, mat)
		avatar_panel.visible = false
		var sphere := SphereMesh.new()
		sphere.radius = 0.009
		sphere.height = 0.018
		menu_pointer = mesh_node(sphere, self, Vector3.ZERO, material(Color("9fdfbd")))
		menu_pointer.visible = false
		var beam := CylinderMesh.new()
		beam.top_radius = .0012; beam.bottom_radius = .0012; beam.height = 1.0; beam.radial_segments = 6
		var beam_material := material(Color("9fdfbd"))
		beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		menu_laser = mesh_node(beam, self, Vector3.ZERO, beam_material)
		menu_laser.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if is_instance_valid(menu_laser): menu_laser.hide()
	else:
		var layer := CanvasLayer.new()
		layer.layer = 3
		add_child(layer)
		layer.add_child(avatar_menu)
		avatar_menu.set_anchors_preset(Control.PRESET_TOP_LEFT)
	avatar_menu.visible = false
	avatar_menu.selected.connect(_select_avatar)
	avatar_menu.import_requested.connect(_import_avatar)
	avatar_menu.closed.connect(_toggle_avatar_menu)
	avatar_menu.quit_requested.connect(_quit_game)
	avatar_menu.pictograms_toggle.button_pressed=preload("res://scripts/ui/pictograms.gd").enabled
	avatar_menu.pictograms_toggle.toggled.connect(func(enabled:bool): preload("res://scripts/ui/pictograms.gd").enabled=enabled;hud.queue_redraw();_save_player_preferences())
	avatar_menu.turn_mode.button_pressed = motor.smooth_turn
	avatar_menu.head_aimed_casting.button_pressed = head_aimed_casting
	avatar_menu.head_aimed_casting.toggled.connect(func(enabled: bool):
		head_aimed_casting = enabled
		casting = false; game.fly.charging = false
		_save_player_preferences())
	avatar_menu.turn_mode_changed.connect(func(enabled: bool): motor.smooth_turn = enabled; _save_player_preferences())
	avatar_menu.smooth_turn_speed.value=motor.smooth_turn_speed
	avatar_menu.snap_turn_angle.value=motor.snap_turn_angle
	avatar_menu.smooth_turn_speed.value_changed.connect(func(value:float):motor.smooth_turn_speed=value;_save_player_preferences())
	avatar_menu.snap_turn_angle.value_changed.connect(func(value:float):motor.snap_turn_angle=value;_save_player_preferences())
	avatar_menu.bind_controller_calibration(controller_calibration)
	avatar_menu.controller_calibration_changed.connect(func(): _apply_controller_calibration(); _save_player_preferences())
	avatar_menu.location_selected.connect(func(id: String):
		if _select_location(id) and menu_open: _toggle_avatar_menu())

func _panorama_texture(entry: Dictionary) -> Texture2D:
	return ResourceLoader.load(entry.panorama, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D

func _select_location(id: String, persist := true) -> bool:
	if is_instance_valid(golf_activity):golf_activity.cancel_loading()
	if is_instance_valid(golf_activity) and golf_activity.active:
		golf_activity.leave()
		if golf_activity.active:return false
	var diagnostic_started:=Time.get_ticks_usec()
	# Switching never silently discards a cast, fight, or unreleased catch.
	if game.state != Session.State.READY or casting:
		avatar_menu.location_status.text = "Finish this cast and release your catch before travelling."
		return false
	var entry := Locations.find_location(id)
	if entry.is_empty(): return false
	# Avoid caching every full-size sky after browsing locations.
	var texture := _panorama_texture(entry)
	if texture == null:
		avatar_menu.location_status.text = "This location could not be loaded. Your current spot is unchanged."
		return false
	var replacement := Shore.create(id)
	if replacement == null:
		avatar_menu.location_status.text = "This location's foreground could not be loaded."
		return false
	if is_instance_valid(foreground):
		remove_child(foreground)
		foreground.queue_free()
	if is_instance_valid(bbq):bbq.release_all()
	foreground = replacement
	add_child(foreground)
	motor.relocate(foreground.get_meta("spawn"))
	last_tip = _strike_tip()
	tracking_was_valid = false
	panorama_material.panorama = texture
	world_environment.sky_rotation = Vector3(0, deg_to_rad(entry.yaw), 0)
	world_environment.background_energy_multiplier = entry.get("sky_energy", 1.0)
	world_environment.ambient_light_energy = entry.ambient
	location_sun.rotation_degrees = entry.sun_rotation
	location_sun.light_color = entry.sun_color
	location_sun.light_energy = entry.sun_energy
	location_sun.light_angular_distance = entry.get("sun_angular_distance",.53)
	water_material.set_shader_parameter("panorama",texture)
	for setting in ["detail_strength","vibrance","shadow_lift"]:
		water_material.set_shader_parameter(setting,panorama_material.get_shader_parameter(setting))
	water_material.set_shader_parameter("sky_inverse",Basis(Vector3.UP,-deg_to_rad(entry.yaw)))
	water_material.set_shader_parameter("sky_energy",entry.get("sky_energy",1.0))
	water_material.set_shader_parameter("deep_color", entry.water)
	water_material.set_shader_parameter("water_roughness", entry.roughness)
	water_material.set_shader_parameter("ripple_strength", entry.ripples)
	water_level=entry.get("water_level",-.35)
	# Player-only anti-wading/rail proxies must not obstruct the casting ray.
	cast_barriers.clear()
	for body in foreground.find_children("*","StaticBody3D",true,false):
		if body.get_meta("role","")=="barrier": cast_barriers.append(body.get_rid())
	cast_water_boundary.rebuild(foreground, water_level+.01)
	fish_boundary.rebuild(foreground, water_level-.45)
	_configure_fishing_grid(id)
	fish_safe_position = Vector3(INF, INF, INF)
	boundary_landing_direction = Vector3(INF, INF, INF)
	# Cover the submerged ends of the tapered mainland too. A short plane
	# exposes those distant triangles as a second floating strip at the horizon.
	water_surface.mesh.size=Vector2(512,512)
	water_surface.position.y=water_level
	water_material.set_shader_parameter("river_flow",.6 if id=="meadow_bend" else 1.1 if id=="boulder_run" else 0.0)
	water_material.set_shader_parameter("boulder_pockets",id=="boulder_run")
	water_material.set_shader_parameter("blend_start",1000.0 if Session.Fly.river(id) else 14.0)
	water_material.set_shader_parameter("blend_end",1100.0 if Session.Fly.river(id) else 45.0)
	water_material.set_shader_parameter("protect_panorama_foreground",entry.get("protect_panorama_foreground",false))
	water_material.set_shader_parameter("replace_near_jetty",id=="lake_pier")
	water_material.set_shader_parameter("coastal_foreground",id=="simons_town_rocks")
	water_material.set_shader_parameter("beach_sides",entry.get("beach_sides",false))
	water_material.set_shader_parameter("align_beach_projection",id=="fish_hoek_beach")
	water_material.set_shader_parameter("shore_projection_origin",foreground.get_meta("spawn")+Vector3.UP*1.63)
	water_material.set_shader_parameter("coastal_shallows",entry.get("coastal_shallows",false))
	water_material.set_shader_parameter("sheltered_cove",id=="secluded_beach")
	water_material.set_shader_parameter("panorama_water_region",entry.get("panorama_water_region",Vector4(0,1,0,1)))
	if id == "lake_pier": Shore.blend_harbour_ground(foreground, water_material, Vector4(0,1.5,2.5,3))
	elif entry.has("ground_bounds"): Shore.blend_harbour_ground(foreground, water_material, entry.ground_bounds, true, entry.get("ground_transition",Vector2(6,6)))
	if id in ["lake_pier","simons_town_rocks","fish_hoek_beach"]:
		foreground.add_child(preload("res://scripts/rear_parallax.gd").create(id,foreground.get_meta("spawn")+Vector3.UP*1.63,water_material))
	current_location = id
	if is_instance_valid(ambience): ambience.select_location(id)
	game.location_id = id
	game.location_name = entry.name
	game.prepare_population()
	if not Session.rig_supported(game.rig,id):game.rig=Session.Rig.CLASSIC
	game.bait=clampi(game.bait,0,game.bait_count()-1)
	game.fly.reset()
	game.message="Hold trigger: sweep back, forward, release. Strip with left grip; mend upstream." if xr and game.is_fly_fishing() else "Hold SPACE briefly, release to cast. R strips line; LEFT mends upstream." if game.is_fly_fishing() else "Choose your bait, then cast into open water."
	if is_instance_valid(rod_status): rod_status.update_bait()
	hud.location_mood = entry.mood
	hud.queue_redraw()
	avatar_menu.refresh_locations(id, true)
	avatar_menu.location_status.text = "Now fishing at " + str(entry.name) + "."
	if persist and Locations.save_location(id) != OK:
		avatar_menu.location_status.text += " Selection could not be saved."
	preload("res://scripts/client_diagnostics.gd").stage("location",diagnostic_started,{"water":id})
	return true

func _toggle_avatar_menu() -> void:
	if avatar_loading: return
	rig_radial.close()
	menu_open = not menu_open
	menu_filtered_position = Vector2(-1, -1)
	if not menu_open: avatar_menu.close_overlays()
	if not menu_open and menu_mouse_down:
		menu_mouse_down = false
		var release := InputEventMouseButton.new()
		release.button_index = MOUSE_BUTTON_LEFT
		release.position = Vector2(-1,-1)
		avatar_menu_view.push_input(release, true)
	motor.blocked = menu_open
	avatar_menu.visible = menu_open
	if menu_open:
		avatar_menu.refresh_tackle()
		_layout_avatar_menu()
		avatar_menu.refresh_locations(current_location, game.state == Session.State.READY)
	casting = false
	reel_tracker.engaged = false
	if xr:
		avatar_panel.visible = menu_open
		menu_pointer.visible = menu_open
		if is_instance_valid(menu_laser): menu_laser.hide()
		if menu_open:
			var facing := Basis(Vector3.UP, atan2(head.global_basis.z.x, head.global_basis.z.z))
			avatar_panel.global_transform = Transform3D(facing, head.global_position - facing.z * 1.8)
	else:
		hud.visible = not menu_open

func _layout_avatar_menu() -> void:
	avatar_menu.size = Vector2(900, 656)
	if not xr:
		var viewport_size := get_viewport().get_visible_rect().size
		var fit := minf(1.0, minf(viewport_size.x / 960.0, viewport_size.y / 716.0))
		avatar_menu.scale = Vector2.ONE * fit
		avatar_menu.position = (viewport_size - avatar_menu.size * fit) * 0.5

func _select_avatar(path: String) -> void:
	if avatar_loading: return
	avatar_loading = true
	motor.blocked = true
	avatar_menu.status.text = "Loading avatar…"
	await get_tree().process_frame
	var model: Node3D = avatars.load_model(path)
	if not model and not is_instance_valid(avatar) and path != AvatarLibrary.DEFAULTS[0]:
		path = AvatarLibrary.DEFAULTS[0]
		model = avatars.load_model(path)
	if model:
		var candidate := AvatarRig.new()
		candidate.name = "PlayerAvatar"
		# Use the saved physical height; avatar changes while crouched cannot
		# remeasure the user or resize the tracking world.
		candidate.standing_height = tracking_manager.user_height if is_instance_valid(tracking_manager) else AvatarRig.Scale.HEAD_HEIGHT
		candidate.add_child(model)
		add_child(candidate)
		if candidate.configure(model):
			if is_instance_valid(avatar): avatar.queue_free()
			avatar = candidate
			candidate.right_grip_updated.connect(_attach_rod_to_hand.bind(candidate))
			candidate.hand_attachments_updated.connect(fish_guide.update_touch)
			avatars.save_selection(path)
			avatar_menu.status.text = "Avatar equipped · Hands and head follow your controls."
		else:
			candidate.queue_free()
			avatar_menu.status.text = "Avatar needs a valid humanoid skeleton. Previous avatar kept."
	else:
		avatar_menu.status.text = avatars.error
	avatar_menu.refresh()
	avatar_loading = false
	motor.blocked = menu_open

func _import_avatar(path: String) -> void:
	if avatar_loading:return
	avatar_loading=true;avatar_menu.status.text="Importing avatar…"
	if not network.avatars.disk.submit(AvatarLibrary.copy_import.bind(path,AvatarLibrary.CACHE),func(result):
		avatar_loading=false
		if result.has("error"):
			avatar_menu.status.text=result.error
			return
		avatars.accept_import(result)
		avatar_menu.refresh()
		_select_avatar(result.path)):
		avatar_loading=false;avatar_menu.status.text="Avatar import is busy. Try again."

func _attach_rod_to_hand(grip: Transform3D, source: Node3D) -> void:
	if is_instance_valid(golf_activity) and golf_activity.active: return
	if not xr or source != avatar or rod_holster.stowed: return
	rod.top_level = true
	rod.global_transform = grip * rod_holster.HELD_POSE
	# Skeleton modifiers run after ordinary processing; keep tackle and line at
	# the rendered tip rather than leaving them one frame behind the hand.
	_update_line()
	rod_status.label.global_position = rod.to_global(Vector3(0,.16,-.78))

func _reel_grab_pressed() -> bool:
	if menu_open or fish_guide.held or shoulder_radio.held or rod_holster.stowed or (game.is_fly_fishing() and game.fly.strip_engaged) or game.state == Session.State.LANDED:
		return false
	return left.get_has_tracking_data() and right.get_has_tracking_data() and tracking_manager.focused and (maxf(left.get_float("grip"), left.get_float("trigger")) > (.35 if reel_tracker.engaged else .55) or left.is_button_pressed("trigger_click"))

func _update_reel_hand() -> void:
	# Visual IK target only: reel speed continues to use the real controller.
	desktop_left.global_basis = rod.global_basis
	desktop_left.global_position = crank.to_global(rod_visual.crank_grip_position())

func _update_avatar(delta: float) -> void:
	if xr and not _reel_grab_pressed(): reel_tracker.engaged = false
	if xr and not is_instance_valid(avatar) and not rod_holster.stowed:
		rod.global_transform = controller_pose(1) * rod_holster.HELD_POSE
	if not xr:
		_update_reel_hand()
	if is_instance_valid(avatar):
		avatar.grounded = motor.is_on_floor()
		avatar.tracked_leg_animation = tracking_manager.tracked_leg_animation if is_instance_valid(tracking_manager) else false
		avatar.apply_tracking(motor.global_transform, tracking_manager.body if is_instance_valid(tracking_manager) else {}, tracking_manager.face if is_instance_valid(tracking_manager) else {})
		var right_hand:Node3D=calibrated_hands[1] if xr else (bbq.desktop_right if is_instance_valid(bbq) and bbq.holds(1) else rod)
		avatar.update_targets(head, calibrated_hands[0] if xr else desktop_left, right_hand, motor.global_position.y, motor.last_motion, delta)
		avatar.left_curl = left.get_float("grip") * 0.8 if xr else 0.7
		avatar_menu.update_preview(avatar)

func _pointer_position() -> Vector2:
	var ray := preload("res://scripts/menu_ray.gd").sample(self)
	if ray.is_empty(): return Vector2(-1, -1)
	var ray_origin: Vector3 = ray.origin
	var ray_direction: Vector3 = ray.direction
	menu_ray_start = ray_origin
	var plane := Plane(avatar_panel.global_basis.z, avatar_panel.global_position)
	var hit = plane.intersects_ray(ray.get("aim_origin", ray_origin), ray_direction)
	if hit == null: return Vector2(-1, -1)
	var local: Vector3 = avatar_panel.to_local(hit)
	var uv := Vector2(local.x / 1.8 + 0.5, 0.5 - local.y / 1.296)
	if uv.x < 0 or uv.x > 1 or uv.y < 0 or uv.y > 1: return Vector2(-1, -1)
	menu_pointer.global_position = hit + avatar_panel.global_basis.z * 0.01
	return uv * Vector2(1000, 720)

func _update_menu_pointer() -> void:
	if not xr: return
	var pos := _pointer_position()
	menu_pointer.visible = pos.x >= 0
	if is_instance_valid(menu_laser): menu_laser.visible = pos.x >= 0
	if pos.x < 0:
		menu_filtered_position = Vector2(-1, -1)
		if menu_mouse_down: _menu_click(false, true)
		return
	if menu_filtered_position.x >= 0:
		pos = menu_filtered_position.lerp(pos, 1.0-exp(-24.0*clampf(get_process_delta_time(),1.0/180.0,1.0/30.0)))
	menu_filtered_position = pos
	menu_pointer.global_position = avatar_panel.to_global(Vector3((pos.x/1000.0-.5)*1.8,(.5-pos.y/720.0)*1.296,.01))
	if is_instance_valid(menu_laser):
		var segment := menu_pointer.global_position - menu_ray_start
		var up := segment.normalized()
		var axis := Vector3.RIGHT if absf(up.dot(Vector3.UP)) > .99 else up.cross(Vector3.UP).normalized()
		menu_laser.global_transform = Transform3D(Basis(axis,segment,axis.cross(up)),menu_ray_start+segment*.5)
	var event := InputEventMouseMotion.new()
	event.position = pos
	event.global_position = pos
	event.relative = pos-menu_last_position
	menu_last_position = pos
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if menu_mouse_down else 0
	avatar_menu_view.push_input(event, true)

func _menu_click(pressed: bool, cancel := false) -> void:
	if pressed and menu_filtered_position.x < 0: _update_menu_pointer()
	if pressed and menu_filtered_position.x < 0: return
	if not pressed and not menu_mouse_down: return
	# Click the displayed cursor; do not resample a newly curled trigger finger.
	var pos := Vector2(-100,-100) if cancel else menu_last_position
	menu_mouse_down = pressed
	var event := InputEventMouseButton.new()
	event.position = pos
	event.global_position = pos
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	avatar_menu_view.push_input(event, true)

func _start_network() -> void:
	network = preload("res://scripts/network/session.gd").new()
	network.name = "Network"
	add_child(network)
	network.setup(self, server_only)
	if not server_only:
		avatar_menu.attach_multiplayer(network)
		tracking_manager=preload("res://scripts/tracking/manager.gd").new()
		add_child(tracking_manager); tracking_manager.setup(self)
		avatar_menu.attach_tracking(tracking_manager)
		avatar_menu.attach_sound(ambience)
		avatar_menu.attach_leaderboard(network)
	network.command_line()
