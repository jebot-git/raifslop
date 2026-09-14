extends RefCounted
## Per-location authored meshes and lightweight collision; panoramas remain distant scenery.
const MANIFEST_PATH := "res://assets/models/locations/manifest.json"
static func catalog() -> Dictionary:
	var data = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	return data if data is Dictionary else {}

static func vector(values: Array) -> Vector3:
	return Vector3(values[0], values[1], values[2])

static func create(id: String) -> Node3D:
	var records := catalog()
	if not records.has(id): return null
	var record: Dictionary = records[id]
	var scene := ResourceLoader.load(record.model, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	if scene == null: return null
	var root := Node3D.new()
	root.name = "LocationForeground"
	root.set_meta("location_id", id)
	root.set_meta("spawn", vector(record.spawn))
	var visual := scene.instantiate()
	root.add_child(visual)
	prepare_lighting(visual, id)
	for proxy in record.colliders:
		if proxy.get("role", "") == "seat" or not proxy.get("enabled", true): continue
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 2
		body.set_meta("role", proxy.role)
		root.add_child(body)
		var shape := CollisionShape3D.new()
		if proxy.has("points"):
			var convex := ConvexPolygonShape3D.new()
			var points := PackedVector3Array()
			for p in proxy.points: points.append(vector(p))
			convex.points = points
			shape.shape = convex
		else:
			body.position = vector(proxy.position)
			body.rotation.y = proxy.get("yaw", 0.0)
			var box := BoxShape3D.new()
			box.size = vector(proxy.size)
			shape.shape = box
		body.add_child(shape)
	var life := preload("res://scripts/environment_life.gd").new()
	root.add_child(life)
	life.configure(id)
	return root

static func prepare_lighting(node: Node, id: String) -> void:
	if node is MeshInstance3D:
		var baked := str(node.name).contains("BakedForeground")
		for index in range(node.mesh.get_surface_count()):
			var source := node.get_active_material(index) as StandardMaterial3D
			if source == null: continue
			if baked:
				var mat := ShaderMaterial.new()
				mat.shader = preload("res://assets/environment/baked_foreground.gdshader")
				mat.set_shader_parameter("base_color", source.albedo_color)
				mat.set_shader_parameter("albedo_tex", source.albedo_texture)
				mat.set_shader_parameter("normal_tex", source.normal_texture)
				mat.set_shader_parameter("normal_depth", .28 if source.normal_enabled else 0.0)
				mat.set_shader_parameter("rough_tex", source.roughness_texture)
				mat.set_shader_parameter("has_roughness", source.roughness_texture != null)
				var channel := Vector4.ZERO
				channel[mini(source.roughness_texture_channel, 3)] = 1
				mat.set_shader_parameter("rough_channel", channel)
				mat.set_shader_parameter("roughness_floor", .68 if source.metallic > .5 else .78)
				mat.set_shader_parameter("metal", minf(source.metallic, .7))
				mat.set_shader_parameter("irradiance_tex", load("res://assets/textures/lighting/" + id + "_irradiance.exr"))
				mat.set_shader_parameter("sky_tex", load("res://assets/textures/lighting/" + id + "_sky.exr"))
				mat.set_shader_parameter("occlusion_tex", load("res://assets/textures/lighting/" + id + "_ao.png"))
				node.set_surface_override_material(index, mat)
			else:
				var mat := source.duplicate() as StandardMaterial3D
				mat.roughness = maxf(mat.roughness, .8)
				mat.metallic_specular = .28
				mat.normal_scale = .28
				mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
				node.set_surface_override_material(index, mat)
	for child in node.get_children(): prepare_lighting(child, id)
