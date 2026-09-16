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

var mode := "hybrid"
var body: CharacterBody3D
var dock: Node3D
var panorama_node: MeshInstance3D
var wall_samples: Array[float] = []
var gpu_samples: Array[float] = []
var last_usec := 0
var point_count := 0
var collision_count := 0
var terrain_changed := 0
var protected_terrain_changed := 0
var eye_scale := 2.2351856863698347

func _build_panorama() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 150
	sphere.height = 300
	sphere.radial_segments = 64
	sphere.rings = 32
	panorama_node = MeshInstance3D.new()
	panorama_node.mesh = sphere
	var mat := ShaderMaterial.new()
	mat.shader = load("res://panosphere.gdshader")
	panorama_node.material_override = mat
	add_child(panorama_node)

func _physics_process(delta: float) -> void:
	if benchmark or body == null or mode == "full": return
	var move := Vector3(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),0,
		float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
	move = Basis(Vector3.UP,camera.rotation.y)*move.limit_length()
	body.velocity = Vector3(move.x*2, -0.5 if body.is_on_floor() else body.velocity.y-9.8*delta, move.z*2)
	body.move_and_slide()
	if body.position.y < -5: body.position = Vector3(0,-1.61,0)

func _unhandled_input(event: InputEvent) -> void:
	if benchmark: return
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		camera.rotation.y -= event.relative.x*0.003
		camera.rotation.x = clampf(camera.rotation.x-event.relative.y*0.003,-1.5,1.5)
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_R:
				body.position = Vector3(0,-1.61,0)
				camera.rotation = Vector3.ZERO
			KEY_T:
				if water: water.visible = not water.visible
			KEY_F: figures.visible = not figures.visible
			KEY_P: capture("inspection")

func report_path(name: String) -> String:
	DirAccess.make_dir_recursive_absolute("user://captures")
	return "user://captures/"+name

func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(report_path(label+".png"))
	if error != OK:push_warning("Capture could not be saved: "+error_string(error))
