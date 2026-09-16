extends Node3D

var camera: Camera3D
var splat: Node3D
var status: Label
var samples: Array[float] = []
var frame := 0
var benchmark := false
var dataset := "gray_pier_500k.ply"
var loaded_ms := 0
var water: MeshInstance3D
var figures: Node3D
var initial_pose := Transform3D.IDENTITY

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	benchmark = "--benchmark" in args
	for arg in args:
		if arg.begins_with("--asset="): dataset = arg.trim_prefix("--asset=")
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("91a3ad")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.7
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	camera = Camera3D.new()
	camera.near = 0.05
	camera.far = 200.0
	camera.fov = 75.0
	add_child(camera)
	camera.make_current()
	var config: Dictionary = {}
	if FileAccess.file_exists("res://placement.json"):
		config = JSON.parse_string(FileAccess.get_file_as_string("res://placement.json"))
	var before := Time.get_ticks_msec()
	var resource = load("res://" + dataset)
	assert(resource != null, "Splat asset failed to import")
	splat = load("res://addons/gdgs/runtime/nodes/gaussian_splat_node.gd").new()
	splat.gaussian = resource
	add_child(splat)
	# GDGS centers imported points and adds its own orientation correction.
	# Marble API outputs are OpenCV: flip Y/Z, then restore the rotated center.
	# https://docs.worldlabs.ai/marble/export/specs
	var orientation := Basis(Vector3.RIGHT, PI) if dataset != "smoke.ply" else Basis.IDENTITY
	splat.basis = orientation
	var center: Array = config.get(dataset, {}).get("center", [0, 0, 0])
	splat.position = orientation * Vector3(center[0], center[1], center[2])
	loaded_ms = Time.get_ticks_msec() - before
	camera.position = Vector3.ZERO
	initial_pose = camera.transform
	figures = Node3D.new()
	add_child(figures)
	var box := BoxMesh.new()
	box.size = Vector3(0.25, 0.25, 0.25)
	add_mesh(box, Vector3(0.7, -0.3, -2), Color("f2a436"), figures)
	var fish := SphereMesh.new()
	fish.radius = 0.16
	fish.height = 0.25
	var fish_node := add_mesh(fish, Vector3(-0.5, -0.3, -1.5), Color("a4ced2"), figures)
	fish_node.scale = Vector3(1.8, 0.65, 0.6)
	var rod := CylinderMesh.new()
	rod.top_radius = 0.007
	rod.bottom_radius = 0.012
	rod.height = 1.9
	var rod_node := add_mesh(rod, Vector3(0.3, -0.15, -1.2), Color("263733"), figures)
	rod_node.rotation_degrees.x = -45
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	plane.subdivide_width = 32
	plane.subdivide_depth = 32
	water = add_mesh(plane, Vector3(0, -1.0, -15), Color(0.1, 0.28, 0.3, 0.65), self)
	var water_mat := ShaderMaterial.new()
	water_mat.shader = load("res://assets/environment/water.gdshader")
	water_mat.set_shader_parameter("panorama", load("res://assets/environment/locations/gray_pier_8k.hdr"))
	water_mat.set_shader_parameter("blend_start", 1000.0)
	water_mat.set_shader_parameter("blend_end", 1100.0)
	water.material_override = water_mat
	water.visible = false
	var canvas := CanvasLayer.new()
	add_child(canvas)
	status = Label.new()
	status.position = Vector2(16, 16)
	status.add_theme_font_size_override("font_size", 20)
	canvas.add_child(status)
	print("SPLAT_READY ", JSON.stringify({"asset": dataset, "points": resource.point_count,
		"load_ms": loaded_ms, "adapter": RenderingServer.get_video_adapter_name(),
		"renderer": RenderingServer.get_current_rendering_method()}))

func add_mesh(mesh: Mesh, pos: Vector3, color: Color, parent: Node) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if color.a < 1: mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	node.material_override = mat
	parent.add_child(node)
	return node

func _process(delta: float) -> void:
	frame += 1
	if benchmark:
		if frame > 120:
			samples.append(delta * 1000)
			var t := float(frame - 120) / 600.0
			camera.position = Vector3(sin(t * TAU) * 0.7, sin(t * TAU * 2) * 0.25, 0)
			camera.rotation.y = sin(t * TAU) * 0.5
		if frame in [120, 320, 520]: capture("benchmark_%s_%d" % [dataset.get_basename(), frame])
		if frame == 720:
			samples.sort()
			var report := {"asset": dataset, "frames": samples.size(), "load_ms": loaded_ms,
				"frame_ms_median": samples[samples.size()/2],
				"frame_ms_p95": samples[int(samples.size()*0.95)],
				"adapter": RenderingServer.get_video_adapter_name(), "resolution": [1280, 720],
				"scope": "desktop mono; no headset or complete game; vsync disabled",
				"static_memory": OS.get_static_memory_usage(),
				"render_memory": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)}
			FileAccess.open("res://" + dataset.get_basename() + "_metrics.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
			print("SPLAT_RESULT ", JSON.stringify(report))
			get_tree().quit()
	else:
		var direction := Vector3(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
			float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q)),
			float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
		camera.position += camera.basis * direction * delta * (3.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0)
	status.text = "Splat experiment | %s | %d FPS\nWASD move · Q/E height · right mouse look · R reset · F figures · T test water · P capture" % [dataset, Engine.get_frames_per_second()]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		camera.rotation.y -= event.relative.x * 0.003
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * 0.003, -1.5, 1.5)
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_R: camera.transform = initial_pose
			KEY_T: water.visible = not water.visible
			KEY_F: figures.visible = not figures.visible
			KEY_P: capture("inspection")

func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://" + label + ".png")
