extends RefCounted
## Generated cutouts sit on authored ground, clear of the casting apron.
static func create(id: String) -> Node3D:
	var root := Node3D.new()
	root.name = "CoastalShoreDetails"
	var cove := id == "secluded_beach"
	var rng := RandomNumberGenerator.new()
	rng.seed = 217 if cove else 419
	var mesh := preload("res://scripts/shore_details.gd").crossed_mesh(false, 2)
	# Sample the opaque clump's bounds; transparent padding must not float its roots.
	var arrays := mesh.surface_get_arrays(0)
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	for i in uvs.size(): uvs[i] = Vector2(lerpf(.036,.976,uvs[i].x),lerpf(.277,.778,uvs[i].y))
	mesh.clear_surfaces()
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_custom_data = true
	multi.mesh = mesh
	multi.instance_count = 16 if cove else 24
	for i in multi.instance_count:
		var x := (-5.5 if cove else -9.5) + i * (11.0 if cove else 19.0) / (multi.instance_count - 1)
		var height := rng.randf_range(.3,.6)
		var at := Vector3(x,0,10.6+rng.randf_range(0,.8))
		multi.set_instance_transform(i,Transform3D(Basis(Vector3.UP,rng.randf_range(-PI,PI)).scaled_local(Vector3(height*1.9,height,height*1.9)),at))
		multi.set_instance_custom_data(i,Color(rng.randf_range(.8,1),0,0,1))
	var grass := MultiMeshInstance3D.new()
	grass.name = "DuneGrass"
	grass.multimesh = multi
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/environment/rivers/vegetation.gdshader")
	material.set_shader_parameter("foliage",preload("res://assets/environment/shore_details/coastal_dune_grass.png"))
	material.set_shader_parameter("exposure",.6 if cove else .75)
	material.set_shader_parameter("sway",.012)
	grass.material_override = material
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(grass)
	var wrack_material := StandardMaterial3D.new()
	wrack_material.albedo_texture = preload("res://assets/environment/shore_details/coastal_wrack.png")
	wrack_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	wrack_material.alpha_scissor_threshold = .42
	wrack_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wrack_material.albedo_color = Color(.65,.65,.65) if cove else Color(.8,.8,.8)
	wrack_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	for side in [-1.0,1.0]:
		for z in [-1.5,2.5,6.5]:
			var wrack := MeshInstance3D.new()
			wrack.name = "TideWrack"
			var plane := PlaneMesh.new()
			plane.size = Vector2(1.3,1.3)
			wrack.mesh = plane
			wrack.material_override = wrack_material
			wrack.position = Vector3(side*(4.8 if cove else 8.8),.012,z)
			wrack.rotation.y = rng.randf_range(-PI,PI)
			wrack.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(wrack)
	return root
