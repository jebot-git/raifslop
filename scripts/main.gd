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
var tracking_manager: Node
var ambience: Node
var network: Node
var server_only := false
var fish_guide: Node3D
var foreground: Node3D
var current_location := Locations.DEFAULT_ID
var world_environment: Environment
var panorama_material: ShaderMaterial
var location_sun: DirectionalLight3D
var water_material: ShaderMaterial
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
var game = Session.new()
var reel_tracker = ReelTracker.new()
var xr := false
var origin: XROrigin3D
var head: Camera3D
var left: XRController3D
var right: XRController3D
var rod_holster: Node3D
var rod_visual: Node3D
var rod: Node3D
var tip: Node3D
var crank: Node3D
var bobber: MeshInstance3D
var line_mesh: ImmediateMesh
var line_material: StandardMaterial3D
var fish_display: Node3D
var catch_bounds := AABB()
var catch_rotation := Quaternion.IDENTITY
var catch_in_hand := false
var hud: Control
var last_tip := Vector3.ZERO
var velocity := Vector3.ZERO
var casting := false
var peak_speed := 0.0
var desktop_reel := false
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
var escape_offset := Vector3.ZERO
var quitting := false

func _ready() -> void:
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
	last_tip = origin.to_local(tip.global_position) if xr else tip.global_position
	ambience=preload("res://scripts/ambience.gd").new()
	add_child(ambience);ambience.setup(self)
	fishing_feedback=preload("res://scripts/fishing_feedback.gd").new()
	add_child(fishing_feedback);fishing_feedback.setup(self)
	shadow_policy=preload("res://scripts/shadow_policy.gd").new()
	add_child(shadow_policy);shadow_policy.setup(self)
	avatar_menu.attach_shadow_controls(shadow_policy)
	_start_network()
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
	sun.shadow_enabled = true
	sun.shadow_blur = 3.0
	sun.light_angular_distance = 4.0
	sun.light_specular = 0.45
	sun.directional_shadow_max_distance = 24.0
	add_child(sun)
	var water := PlaneMesh.new()
	water.size = Vector2(160, 160)
	water.subdivide_width = 64
	water.subdivide_depth = 64
	var wm := ShaderMaterial.new()
	water_material = wm
	wm.shader = load("res://assets/environment/water.gdshader")
	mesh_node(water, self, Vector3(0, -0.35, -40), wm)
	var sphere := SphereMesh.new()
	sphere.radius = 0.045
	sphere.height = 0.14
	bobber = mesh_node(sphere, self, Vector3(0, 0, -3), material(Color("ff784e")))
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
	motor = Motor.new()
	add_child(motor)
	origin = XROrigin3D.new()
	origin.name = "XROrigin3D"
	motor.add_child(origin)
	var interface := XRServer.find_interface("OpenXR")
	xr = interface != null and interface.is_initialized()
	if xr:
		get_viewport().use_xr = true
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
	rod_visual = preload("res://scripts/rod_visual.gd").new()
	rod.add_child(rod_visual)
	rod_visual.equip(game.tackle.equipped)
	crank = rod_visual.crank
	tip = Node3D.new()
	rod.add_child(tip)
	tip.position = Vector3(0, 0, -1.68)
	rod_holster = preload("res://scripts/rod_holster.gd").new()
	rod_holster.game_root=self
	add_child(rod_holster)

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
	var smooth = cfg.get_value("controls", "smooth_turn", false)
	motor.smooth_turn = smooth if smooth is bool else false
	var bait = cfg.get_value("tackle", "bait", 0)
	game.bait = clampi(int(bait), 0, Session.BAITS.size()-1) if (bait is int or bait is float) and is_finite(bait) else 0

func _save_player_preferences() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("controls", "smooth_turn", motor.smooth_turn)
	cfg.set_value("tackle", "bait", game.bait)
	var error := cfg.save("user://player.cfg")
	if error != OK: push_warning("Cannot save player settings: " + error_string(error))

func _save_user_settings() -> void:
	_save_player_preferences()
	ambience.save()
	tracking_manager.save()
	network.save_preferences()
	network.voice.save_preferences()
	shadow_policy.save()
	avatars.save_selection(avatars.selected_path)
	var error := Locations.save_location(current_location)
	if error != OK: push_warning("Cannot save location: " + error_string(error))

func _quit_game() -> void:
	if quitting: return
	quitting = true
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

func _select_bait(index: int) -> void:
	game.select_bait(index)
	_save_player_preferences()
	hud.queue_redraw()

func _left_button(button: String) -> void:
	if fish_guide.held:
		if button == "trigger_click": fish_guide.photo_camera.toggle(); return
		if button == "ax_button": fish_guide.page(1)
		elif button == "by_button": fish_guide.page(-1)
		return
	if menu_open: return
	if button == "ax_button":
		_select_bait((game.bait + 1) % Session.BAITS.size())
	elif button == "by_button":
		_primary_action()

func _right_pressed(button: String) -> void:
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
	if button == "trigger_click" and game.state == Session.State.READY and not rod_holster.stowed:
		casting = true
		peak_speed = 0.0
	elif button == "ax_button" and game.state in [Session.State.LANDED, Session.State.LOST]:
		_primary_action()

func _right_released(button: String) -> void:
	if fish_guide.held: return
	if menu_open:
		if button == "trigger_click": _menu_click(false)
		return
	if button == "trigger_click" and casting:
		casting = false
		if left.get_has_tracking_data() and right.get_has_tracking_data() and peak_speed > 0.55:
			_cast(clampf(peak_speed * 3.0, 5.0, 24.0))
		else:
			game.message = "Hold trigger, swing forward, then release."

func _primary_action() -> void:
	match game.state:
		Session.State.READY:
			_cast(12.0)
		Session.State.WAITING, Session.State.BITE:
			game.strike()
		Session.State.LANDED, Session.State.LOST:
			game.reset()
			fish_display.visible = false
			motor.catch_controls = false

func _cast_direction() -> Vector3:
	# Center-of-view head direction supplies VR aim; no eye tracking. Rod motion supplies power.
	var direction := -head.global_basis.z if xr else -rod.global_basis.z
	direction.y = 0
	if direction.length() < 0.1:
		direction = -origin.global_basis.z
		direction.y = 0
	return direction.normalized() if direction.length() > 0.01 else Vector3.FORWARD

func _landing_distance(anchor: Vector3, direction: Vector3) -> float:
	# Find the first foreground obstruction while retrieving from open water.
	# The view ray catches decks above water as well as railings. Reserve room
	# for lateral fight movement and stop .65 m before the float is hidden.
	var space := get_world_3d().direct_space_state
	var sideways := direction.cross(Vector3.UP).normalized()
	for step in range(225):
		var distance := 24.0 - step * .1
		for lateral in [-1.1, 0.0, 1.1]:
			var at: Vector3 = anchor + direction * distance + sideways * lateral + Vector3.UP * .02
			var ray := PhysicsRayQueryParameters3D.create(head.global_position, at, 1)
			if not space.intersect_ray(ray).is_empty(): return maxf(1.6, distance + .65)
	return 1.6

func _cast(power: float) -> void:
	if game.state != Session.State.READY or rod_holster.stowed: return
	var direction := _cast_direction()
	cast_anchor = Vector3(rod.global_position.x, -0.3, rod.global_position.z)
	var endpoint := cast_anchor + direction * power
	if endpoint.z > 1.5:
		game.message = "Aim out over the lake, away from the shore."
		return
	var landing := _landing_distance(cast_anchor, direction)
	if clampf(power, 5.0, 24.0) < landing + .5:
		game.message = "Cast farther into open water, or move closer to the edge."
		return
	game.landing_distance = landing
	game.cast(power)
	cast_start = tip.global_position
	cast_target = cast_anchor + direction * game.cast_distance
	escape_offset=Vector3.ZERO
	fishing_feedback.cast_swish()

func _unhandled_input(event: InputEvent) -> void:
	if not xr and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_J and not menu_open:
			rod_holster.set_stowed(not rod_holster.stowed)
			return
		if event.keycode == KEY_G and not menu_open:
			fish_guide.held = not fish_guide.held
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
	if is_instance_valid(rod_visual): rod_visual.equip(game.tackle.equipped)
	if server_only: return
	rod_holster.update_holster()
	fish_guide.update_device()
	if is_instance_valid(tracking_manager): tracking_manager.sample(delta)
	_update_tracking_warning(delta)
	rod_visual.visible = true
	rod.visible = rod_holster.stowed or not xr or right.get_has_tracking_data()
	motor.catch_controls = fish_guide.held or (xr and game.state == Session.State.LANDED)
	if not xr: hud.visible = not menu_open and not fish_guide.held
	time += delta
	_update_avatar(delta)
	if avatar_loading: return
	if fish_guide.held:
		fight_input.reset()
		casting = false
		reel_tracker.engaged = false
		last_tip = origin.to_local(tip.global_position) if xr else tip.global_position
		if fish_display.visible: _update_catch(0)
		_update_line()
		return
	if menu_open:
		fight_input.reset()
		_layout_avatar_menu()
		_update_menu_pointer()
		if xr and right.get_has_tracking_data():
			var scroll_axis := right.get_vector2("primary").y
			if absf(scroll_axis) > 0.2: avatar_menu.scroll_page(-scroll_axis * 650.0 * delta)
		last_tip = origin.to_local(tip.global_position) if xr else tip.global_position
		return
	if rod_holster.stowed:
		_update_line()
		return
	gesture_cooldown = maxf(0.0, gesture_cooldown - delta)
	var reel := 0.0
	if xr:
		var tracked: bool = right.get_has_tracking_data() and left.get_has_tracking_data() and (not is_instance_valid(tracking_manager) or tracking_manager.focused)
		rod.visible = right.get_has_tracking_data()
		if not tracked:
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
			last_tip = origin.to_local(tip.global_position)
			tracking_was_valid = true
		# Locomotion is not a fishing gesture. Use origin-local tracked motion.
		velocity = origin.global_basis * ((origin.to_local(tip.global_position) - last_tip) / maxf(delta, 0.001))
		if casting:
			peak_speed = maxf(peak_speed, maxf(0.0, velocity.dot(_cast_direction())))
		var reel_pos := rod.to_local(left.global_position) - crank.position
		reel = reel_tracker.sample(reel_pos, left.get_float("grip") > 0.55, delta)
		if game.state == Session.State.BITE and velocity.y > 0.9:
			game.strike()
		if game.state == Session.State.FIGHT:
			var facing := Basis(Vector3.UP,atan2(head.global_basis.z.x,head.global_basis.z.z))
			var direction := fight_input.sample(game.cue,origin.global_basis.inverse()*(tip.global_position-head.global_position),origin.global_basis.inverse()*facing)
			game.gesture(direction)
		else: fight_input.reset()
	else:
		reel = 1.0 if Input.is_key_pressed(KEY_R) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) else 0.0
		game.gesture(0 if Input.is_key_pressed(KEY_LEFT) else 1 if Input.is_key_pressed(KEY_RIGHT) else 2 if Input.is_key_pressed(KEY_UP) else -1)
	# Retrieval accepts either winding direction; the handle follows the actual hand.
	crank.rotation.x += reel_tracker.angular_delta if xr else reel * TAU * delta
	fishing_feedback.reel_rate = reel
	escape_offset=escape_offset.move_toward(fish_escape_direction() * (1.1 if game.cue >= 0 and game.state == Session.State.FIGHT else 0.0), delta * 1.8)
	last_tip = origin.to_local(tip.global_position) if xr else tip.global_position
	game.tick(minf(delta, 0.05), reel, maxf(0.0, -rod.global_basis.z.y))
	if game.state != last_state:
		if game.state == Session.State.BITE:
			_tone(880, 0.18)
		elif game.state == Session.State.LANDED:
			_show_fish()
			_save_journal()
			if game.tackle.save_profile() != OK:
				game.message += "\nCould not save shekels."
		elif game.state == Session.State.LOST:
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

func _update_catch(delta: float) -> void:
	if not xr:
		fish_display.global_position = head.global_position - head.global_basis.z * 1.1 - Vector3.UP * 0.08
		fish_display.rotation = Vector3(0, time * 0.35, 0)
		return
	var stick := Vector2.ZERO
	for controller in [left, right]:
		if controller.get_has_tracking_data(): stick += motor.deadzone(controller.get_vector2("primary"))
	stick = stick.limit_length()
	# Both stick axes spin around gravity-up; inspection never tips the fish sideways.
	var spin := clampf(-stick.x + stick.y, -1.0, 1.0)
	catch_rotation = (Quaternion(Vector3.UP, spin * delta * 1.8) * catch_rotation).normalized()
	catch_in_hand = not fish_guide.held and left.get_has_tracking_data() and left.get_float("grip") > 0.55
	if catch_in_hand:
		var orientation := Basis(catch_rotation) * Basis(Vector3.BACK, PI / 2)
		# Grip the string, leaving a short vertical drop to the mouth.
		var mouth := left.global_position - Vector3.UP * 0.08
		fish_display.global_transform = Transform3D(orientation, mouth - orientation * _catch_mouth())
	else:
		# +X is the mouth: keep it attached while the body hangs below the tip.
		var orientation := Basis(catch_rotation) * Basis(Vector3.BACK, PI / 2)
		var hook := tip.global_position - Vector3.UP * 0.28
		fish_display.global_transform = Transform3D(orientation, hook - orientation * _catch_mouth())

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

func _update_line() -> void:
	var tension_color := Color("d8f5e5")
	if game.state == Session.State.FIGHT:
		if game.tension < .25: tension_color = Color("53a9ef").lerp(tension_color, game.tension / .25)
		elif game.tension > .75: tension_color = tension_color.lerp(Color("ff5344"), (game.tension - .75) / .25)
	line_material.albedo_color = tension_color
	var active: bool = game.state in [Session.State.CASTING, Session.State.WAITING, Session.State.BITE, Session.State.FIGHT]
	bobber.visible = active
	line_mesh.clear_surfaces()
	if xr and game.state == Session.State.LANDED and fish_display.visible:
		line_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		line_mesh.surface_add_vertex(tip.global_position)
		if catch_in_hand: line_mesh.surface_add_vertex(left.global_position)
		line_mesh.surface_add_vertex(fish_display.to_global(_catch_mouth()))
		line_mesh.surface_end()
		return
	if not active:
		return
	if game.state == Session.State.CASTING:
		var progress: float = 1.0 - game.timer / 0.8
		bobber.position = cast_start.lerp(cast_target, progress) + Vector3.UP * sin(progress * PI) * 2.2
	elif game.state == Session.State.FIGHT:
		# Walking does not teleport the fish to the world origin or win a fight.
		var direction := (cast_target - cast_anchor).normalized()
		bobber.position = cast_anchor + direction * game.distance + escape_offset + Vector3(0, 0.02, 0)
	else:
		bobber.position = cast_target + Vector3(0, sin(time * 3.0) * 0.025, 0)
		if game.state == Session.State.BITE:
			bobber.position.y -= 0.10 + sin(time * 22) * 0.05
	line_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in range(25):
		var t := i / 24.0
		var p := tip.global_position.lerp(bobber.position, t)
		p.y -= sin(t * PI) * (lerpf(.65, .025, game.tension) if game.state == Session.State.FIGHT else 0.5)
		line_mesh.surface_add_vertex(p)
	line_mesh.surface_end()

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
	catch_rotation = Quaternion.IDENTITY
	catch_in_hand = false
	motor.catch_controls = xr
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
	avatar_menu.turn_mode.button_pressed = motor.smooth_turn
	avatar_menu.turn_mode_changed.connect(func(enabled: bool): motor.smooth_turn = enabled; _save_player_preferences())
	avatar_menu.location_selected.connect(func(id: String):
		if _select_location(id) and menu_open: _toggle_avatar_menu())

func _panorama_texture(entry: Dictionary) -> Texture2D:
	return ResourceLoader.load(entry.panorama, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D

func _select_location(id: String, persist := true) -> bool:
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
	foreground = replacement
	add_child(foreground)
	motor.relocate(foreground.get_meta("spawn"))
	last_tip = origin.to_local(tip.global_position) if xr else tip.global_position
	tracking_was_valid = false
	panorama_material.panorama = texture
	world_environment.sky_rotation = Vector3(0, deg_to_rad(entry.yaw), 0)
	world_environment.background_energy_multiplier = entry.get("sky_energy", 1.0)
	world_environment.ambient_light_energy = entry.ambient
	location_sun.rotation_degrees = entry.sun_rotation
	location_sun.light_color = entry.sun_color
	location_sun.light_energy = entry.sun_energy
	water_material.set_shader_parameter("panorama",texture)
	for setting in ["detail_strength","vibrance","shadow_lift"]:
		water_material.set_shader_parameter(setting,panorama_material.get_shader_parameter(setting))
	water_material.set_shader_parameter("sky_inverse",Basis(Vector3.UP,-deg_to_rad(entry.yaw)))
	water_material.set_shader_parameter("sky_energy",entry.get("sky_energy",1.0))
	water_material.set_shader_parameter("deep_color", entry.water)
	water_material.set_shader_parameter("water_roughness", entry.roughness)
	water_material.set_shader_parameter("ripple_strength", entry.ripples)
	current_location = id
	if is_instance_valid(shadow_policy): shadow_policy.apply_materials(foreground)
	if is_instance_valid(ambience): ambience.select_location(id)
	game.location_id = id
	game.location_name = entry.name
	hud.location_mood = entry.mood
	hud.queue_redraw()
	avatar_menu.refresh_locations(id, true)
	avatar_menu.location_status.text = "Now fishing at " + str(entry.name) + "."
	if persist and Locations.save_location(id) != OK:
		avatar_menu.location_status.text += " Selection could not be saved."
	return true

func _toggle_avatar_menu() -> void:
	if avatar_loading: return
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
		# FPSloppa normalizes the model independently of the current headset pose.
		# Loading while seated, crouching, or reconnecting must not shrink the body.
		candidate.standing_height = 1.65
		candidate.add_child(model)
		add_child(candidate)
		if candidate.configure(model):
			if is_instance_valid(avatar): avatar.queue_free()
			avatar = candidate
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
	var result := avatars.import_file(path)
	if result.has("error"):
		avatar_menu.status.text = result.error
		return
	avatar_menu.refresh()
	_select_avatar(result.path)

func _update_avatar(delta: float) -> void:
	if not xr:
		var reel_angle := crank.rotation.x
		desktop_left.global_transform = rod.global_transform
		desktop_left.global_position = rod.to_global(crank.position + Vector3(-0.02, cos(reel_angle) * 0.08, sin(reel_angle) * 0.08))
	if is_instance_valid(avatar):
		avatar.grounded = motor.is_on_floor()
		avatar.tracked_leg_animation = tracking_manager.tracked_leg_animation if is_instance_valid(tracking_manager) else false
		avatar.apply_tracking(motor.global_transform, tracking_manager.body if is_instance_valid(tracking_manager) else {}, tracking_manager.face if is_instance_valid(tracking_manager) else {})
		avatar.update_targets(head, left if xr else desktop_left, right if xr else rod, motor.global_position.y, motor.last_motion, delta)
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
		avatar_menu.attach_help()
	network.command_line()
