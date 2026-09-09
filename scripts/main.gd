extends Node3D

const Session = preload("res://scripts/fishing_session.gd")
const ReelTracker = preload("res://scripts/reel_tracker.gd")
const HUD = preload("res://scripts/hud.gd")
const Motor = preload("res://scripts/locomotion.gd")
const Shore = preload("res://scripts/shore.gd")
const AvatarLibrary = preload("res://scripts/avatar_library.gd")
const AvatarRig = preload("res://scripts/avatar_rig.gd")
const AvatarMenu = preload("res://scripts/avatar_menu.gd")
var motor: CharacterBody3D
var avatars = AvatarLibrary.new()
var avatar: Node3D
var avatar_menu: PanelContainer
var avatar_menu_view: SubViewport
var avatar_panel: MeshInstance3D
var menu_pointer: MeshInstance3D
var menu_open := false
var avatar_loading := false
var desktop_left: Node3D
var vr_status: MeshInstance3D
var cast_anchor := Vector3.ZERO
var game = Session.new()
var reel_tracker = ReelTracker.new()
var xr := false
var origin: XROrigin3D
var head: Camera3D
var left: XRController3D
var right: XRController3D
var rod: Node3D
var tip: Node3D
var crank: Node3D
var bobber: MeshInstance3D
var line_mesh: ImmediateMesh
var fish_display: Node3D
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
var tracking_was_valid := false
var audio: AudioStreamPlayer

func _ready() -> void:
	_build_environment()
	_build_rig()
	_build_rod()
	_build_ui()
	_build_avatar_menu()
	avatars.initialize()
	avatar_menu.refresh()
	_select_avatar(avatars.selected_path)
	_load_journal()
	audio = AudioStreamPlayer.new()
	add_child(audio)
	last_tip = origin.to_local(tip.global_position) if xr else tip.global_position
	print("Real AI Fishing ready | ", "OpenXR" if xr else "Desktop", " | panorama + scanned shore loaded")

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
	var sky := Sky.new()
	var pano := PanoramaSkyMaterial.new()
	pano.panorama = load("res://assets/environment/lakeside_2k.hdr")
	sky.sky_material = pano
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -40, 0)
	sun.light_color = Color("ffe2b5")
	sun.light_energy = 1.4
	add_child(sun)
	var water := PlaneMesh.new()
	water.size = Vector2(160, 160)
	water.subdivide_width = 64
	water.subdivide_depth = 64
	var wm := ShaderMaterial.new()
	wm.shader = load("res://assets/environment/water.gdshader")
	mesh_node(water, self, Vector3(0, -0.35, -40), wm)
	for i in range(20):
		box(self, Vector3(0, -0.09, 1.8 - i * 0.22), Vector3(3.2, 0.16, 0.205), material(Color("72563e").lightened(float(i % 3) * 0.035)))
	for x in [-1.48, 1.48]:
		for z in [-2.25, 1.8]:
			cylinder(self, Vector3(x, -0.1, z), 0.09, 1.0, material(Color("493e30")))
	var rock_scene: PackedScene = load("res://assets/models/boulder.glb")
	for i in range(9):
		var rock := rock_scene.instantiate() as Node3D
		add_child(rock)
		rock.position = Vector3(-4.0 + i, -0.4, 3.4 + sin(i) * 0.4)
		rock.position = Vector3(-11.0 + (i % 3) * 1.0, -0.1, 6.0 + (i / 3) * 3.0)
		rock.rotation.y = i * 1.7
		rock.scale = Vector3.ONE * (0.65 + (i % 3) * 0.12)
		Shore.collider(self, rock.position + Vector3(0, 0.4, 0), Vector3(0.8, 0.8, 0.8))
	Shore.build(self)
	box(self, Vector3(-1.0, 0.18, -0.4), Vector3(0.55, 0.36, 0.35), material(Color("254c48")))
	box(self, Vector3(-1.0, 0.38, -0.4), Vector3(0.58, 0.05, 0.38), material(Color("c9b98c")))
	var sphere := SphereMesh.new()
	sphere.radius = 0.045
	sphere.height = 0.14
	bobber = mesh_node(sphere, self, Vector3(0, 0, -3), material(Color("ff784e")))
	line_mesh = ImmediateMesh.new()
	var lm := material(Color("d8f5e5"))
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
	var carbon := material(Color("182b2a"), 0.5)
	var cork := material(Color("c89e69"))
	var grip := cylinder(rod, Vector3(0, 0, 0.05), 0.022, 0.34, cork)
	grip.rotation.x = PI / 2
	for i in range(8):
		var segment := cylinder(rod, Vector3(0, 0, -0.22 - i * 0.19), 0.014 - i * 0.0013, 0.195, carbon)
		segment.rotation.x = PI / 2
	tip = Node3D.new()
	rod.add_child(tip)
	tip.position = Vector3(0, 0, -1.68)
	var spool := cylinder(rod, Vector3(0, -0.075, 0.04), 0.06, 0.07, material(Color("bac5ba"), 0.85))
	spool.rotation.z = PI / 2
	crank = Node3D.new()
	rod.add_child(crank)
	crank.position = Vector3(-0.085, -0.075, 0.04)
	box(crank, Vector3(0, 0.04, 0), Vector3(0.012, 0.08, 0.012), material(Color("a8b4ac"), 0.8))
	var knob := cylinder(crank, Vector3(-0.015, 0.08, 0), 0.018, 0.04, carbon)
	knob.rotation.z = PI / 2

func _build_ui() -> void:
	hud = HUD.new()
	hud.game = game
	hud.vr_mode = xr
	if xr:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(1000, 640)
		viewport.transparent_bg = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(viewport)
		viewport.add_child(hud)
		var quad := QuadMesh.new()
		quad.size = Vector2(1.2, 0.768)
		var panel_mat := StandardMaterial3D.new()
		panel_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		panel_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		panel_mat.albedo_texture = viewport.get_texture()
		vr_status = mesh_node(quad, self, Vector3(-0.8, 1.55, -2.1), panel_mat)
	else:
		var layer := CanvasLayer.new()
		add_child(layer)
		layer.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.bait_selected.connect(func(index: int): game.select_bait(index))
	hud.action_pressed.connect(_primary_action)
	hud.avatar_requested.connect(_toggle_avatar_menu)

func _left_button(button: String) -> void:
	if menu_open: return
	if button == "ax_button":
		game.select_bait((game.bait + 1) % 3)
	elif button == "by_button":
		_primary_action()

func _right_pressed(button: String) -> void:
	if button == "by_button":
		_toggle_avatar_menu()
		return
	if menu_open:
		if button == "trigger_click": _menu_click(true)
		return
	if button == "trigger_click" and game.state == Session.State.READY:
		casting = true
		peak_speed = 0.0
	elif button == "ax_button" and game.state in [Session.State.LANDED, Session.State.LOST]:
		_primary_action()

func _right_released(button: String) -> void:
	if menu_open:
		if button == "trigger_click": _menu_click(false)
		return
	if button == "trigger_click" and casting:
		casting = false
		if peak_speed > 0.55:
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

func _cast(power: float) -> void:
	var direction := -rod.global_basis.z
	direction.y = 0
	if direction.length() < 0.1:
		direction = Vector3.FORWARD
	direction = direction.normalized()
	cast_anchor = Vector3(rod.global_position.x, -0.3, rod.global_position.z)
	var endpoint := cast_anchor + direction * power
	if endpoint.z > 1.5:
		game.message = "Aim out over the lake, away from the shore."
		return
	game.cast(power)
	cast_start = tip.global_position
	cast_target = cast_anchor + direction * game.cast_distance
	_tone(460, 0.07)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_V:
		_toggle_avatar_menu()
		return
	if menu_open:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE: _toggle_avatar_menu()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE: _primary_action()
			KEY_1: game.select_bait(0)
			KEY_2: game.select_bait(1)
			KEY_3: game.select_bait(2)
			KEY_LEFT: game.gesture(0)
			KEY_RIGHT: game.gesture(1)
			KEY_UP: game.gesture(2)
			KEY_ESCAPE: get_tree().quit()
	if not xr and event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		rod.rotation.y = clampf(rod.rotation.y - event.relative.x * 0.004, -0.8, 0.8)
		rod.rotation.x = clampf(rod.rotation.x - event.relative.y * 0.004, -0.3, 1.2)
	if not xr and event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		motor.turn(-event.relative.x * 0.003)
		head.rotation.x = clampf(head.rotation.x - event.relative.y * 0.003, -1.0, 0.75)

func _process(delta: float) -> void:
	time += delta
	_update_avatar(delta)
	if avatar_loading: return
	if menu_open:
		_layout_avatar_menu()
		_update_menu_pointer()
		last_tip = origin.to_local(tip.global_position) if xr else tip.global_position
		return
	gesture_cooldown = maxf(0.0, gesture_cooldown - delta)
	var reel := 0.0
	if xr:
		var tracked := right.get_has_tracking_data() and left.get_has_tracking_data()
		rod.visible = right.get_has_tracking_data()
		if not tracked:
			tracking_was_valid = false
			casting = false
			reel_tracker.engaged = false
			hud.tracking_lost = true
			hud.queue_redraw()
			return
		hud.tracking_lost = false
		if not tracking_was_valid:
			last_tip = origin.to_local(tip.global_position)
			tracking_was_valid = true
		# Locomotion is not a fishing gesture. Use origin-local tracked motion.
		velocity = origin.global_basis * ((origin.to_local(tip.global_position) - last_tip) / maxf(delta, 0.001))
		if casting:
			peak_speed = maxf(peak_speed, maxf(0.0, velocity.dot(-rod.global_basis.z)))
		var reel_pos := rod.to_local(left.global_position) - crank.position
		reel = reel_tracker.sample(reel_pos, left.get_float("grip") > 0.55, delta)
		if game.state == Session.State.BITE and velocity.y > 0.9:
			game.strike()
		if game.state == Session.State.FIGHT and gesture_cooldown <= 0.0:
			var local_velocity := origin.global_basis.inverse() * velocity
			var direction := -1
			if local_velocity.x < -0.8: direction = 0
			elif local_velocity.x > 0.8: direction = 1
			elif local_velocity.y > 0.9: direction = 2
			if direction >= 0 and game.gesture(direction):
				gesture_cooldown = 0.5
				right.trigger_haptic_pulse("haptic", 0.0, 0.4, 0.10, 0.0)
	else:
		reel = 1.0 if Input.is_key_pressed(KEY_R) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) else 0.0
	crank.rotation.x += reel * TAU * delta
	last_tip = origin.to_local(tip.global_position) if xr else tip.global_position
	game.tick(minf(delta, 0.05), reel, maxf(0.0, -rod.global_basis.z.y))
	if game.state != last_state:
		if game.state == Session.State.BITE:
			_tone(880, 0.18)
			if xr: right.trigger_haptic_pulse("haptic", 0.0, 0.65, 0.22, 0.0)
		elif game.state == Session.State.LANDED:
			_show_fish()
			_save_journal()
			_tone(660, 0.35)
		elif game.state == Session.State.LOST:
			_tone(180, 0.18)
		last_state = game.state
	_update_line()
	if fish_display.visible:
		fish_display.global_position = head.global_position - head.global_basis.z * 1.1 - Vector3.UP * 0.3
		fish_display.rotation.y = time * 0.35
		hud.queue_redraw()

func _update_line() -> void:
	var active: bool = game.state in [Session.State.CASTING, Session.State.WAITING, Session.State.BITE, Session.State.FIGHT]
	bobber.visible = active
	line_mesh.clear_surfaces()
	if not active:
		return
	if game.state == Session.State.CASTING:
		var progress: float = 1.0 - game.timer / 0.8
		bobber.position = cast_start.lerp(cast_target, progress) + Vector3.UP * sin(progress * PI) * 2.2
	elif game.state == Session.State.FIGHT:
		# Walking does not teleport the fish to the world origin or win a fight.
		var direction := (cast_target - cast_anchor).normalized()
		bobber.position = cast_anchor + direction * game.distance + Vector3(sin(time * 1.7) * game.stamina, 0.02, 0)
	else:
		bobber.position = cast_target + Vector3(0, sin(time * 3.0) * 0.025, 0)
		if game.state == Session.State.BITE:
			bobber.position.y -= 0.10 + sin(time * 22) * 0.05
	line_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in range(25):
		var t := i / 24.0
		var p := tip.global_position.lerp(bobber.position, t)
		p.y -= sin(t * PI) * (0.15 if game.state == Session.State.FIGHT else 0.5)
		line_mesh.surface_add_vertex(p)
	line_mesh.surface_end()

func _show_fish() -> void:
	for child in fish_display.get_children():
		child.queue_free()
	if game.fish_index == 0:
		var scene: PackedScene = load("res://assets/models/european_perch.glb")
		fish_display.add_child(scene.instantiate())
	else:
		var body := SphereMesh.new()
		body.radius = 0.12
		body.height = 0.24
		var n := mesh_node(body, fish_display, Vector3.ZERO, material(Color("9d9860") if game.fish_index == 1 else Color("537c5b"), 0.3))
		n.scale = Vector3(2.5, 0.9, 0.65)
		var tail := PrismMesh.new()
		tail.size = Vector3(0.17, 0.22, 0.025)
		mesh_node(tail, fish_display, Vector3(-0.33, 0, 0), material(Color("787648")))
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
	var file := FileAccess.open("user://journal.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(game.journal, "\t"))

func _load_journal() -> void:
	if FileAccess.file_exists("user://journal.json"):
		var data = JSON.parse_string(FileAccess.get_file_as_string("user://journal.json"))
		if data is Array:
			game.journal = data
			game.catches = data.size()

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
	avatar_menu.turn_mode_changed.connect(func(enabled: bool): motor.smooth_turn = enabled)

func _toggle_avatar_menu() -> void:
	if avatar_loading: return
	menu_open = not menu_open
	motor.blocked = menu_open
	avatar_menu.visible = menu_open
	if menu_open: _layout_avatar_menu()
	casting = false
	reel_tracker.engaged = false
	if xr:
		avatar_panel.visible = menu_open
		menu_pointer.visible = menu_open
		if menu_open:
			var facing := Basis(Vector3.UP, atan2(head.global_basis.z.x, head.global_basis.z.z))
			avatar_panel.global_transform = Transform3D(facing, head.global_position - facing.z * 1.8)
		vr_status.visible = not menu_open
	else:
		hud.visible = not menu_open

func _layout_avatar_menu() -> void:
	avatar_menu.size = Vector2(900, 610)
	if not xr:
		var viewport_size := get_viewport().get_visible_rect().size
		var fit := minf(1.0, minf(viewport_size.x / 960.0, viewport_size.y / 670.0))
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
		candidate.standing_height = clampf(head.global_position.y - motor.global_position.y, 1.2, 2.1)
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
		avatar.update_targets(head, left if xr else desktop_left, right if xr else rod, motor.global_position.y, motor.last_motion, delta)
		avatar.left_curl = left.get_float("grip") * 0.8 if xr else 0.7
		avatar_menu.update_preview(avatar)
	if xr and is_instance_valid(vr_status) and not menu_open:
		var facing := Basis(Vector3.UP, atan2(head.global_basis.z.x, head.global_basis.z.z))
		vr_status.global_transform = Transform3D(facing, head.global_position + facing * Vector3(-0.8, -0.05, -2.1))

func _pointer_position() -> Vector2:
	var ray_origin := right.global_position
	var ray_direction := -right.global_basis.z
	var plane := Plane(avatar_panel.global_basis.z, avatar_panel.global_position)
	var hit = plane.intersects_ray(ray_origin, ray_direction)
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
	if pos.x < 0: return
	var event := InputEventMouseMotion.new()
	event.position = pos
	event.global_position = pos
	avatar_menu_view.push_input(event, true)

func _menu_click(pressed: bool) -> void:
	var pos := _pointer_position()
	if pos.x < 0: return
	var event := InputEventMouseButton.new()
	event.position = pos
	event.global_position = pos
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	avatar_menu_view.push_input(event, true)
