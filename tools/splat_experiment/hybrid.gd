extends "res://viewer.gd"

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

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	benchmark = "--benchmark" in args
	for arg in args:
		if arg.begins_with("--mode="): mode = arg.trim_prefix("--mode=")
	assert(mode in ["full", "hybrid", "panorama"])
	dataset = "gray_pier_500k.ply" if mode == "full" else "gray_pier_near.ply"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("91a3ad")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.8
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var before := Time.get_ticks_msec()
	if mode != "panorama":
		var resource = load("res://" + dataset)
		assert(resource != null)
		point_count = resource.point_count
		# Raster uses byte data + positions, not this duplicate float array.
		resource.point_data_float = PackedFloat32Array()
		splat = load("res://addons/gdgs/runtime/nodes/gaussian_splat_node.gd").new()
		splat.gaussian = resource
		add_child(splat)
		var placement: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://placement.json"))
		var c: Array = placement[dataset].center
		var rotation := Basis(Vector3.RIGHT, PI).scaled(Vector3.ONE * eye_scale)
		splat.basis = rotation
		splat.position = rotation * Vector3(c[0], c[1], c[2])
	if mode != "full":
		_build_panorama()
		_build_dock()
		_build_water()
	loaded_ms = Time.get_ticks_msec()-before
	body = CharacterBody3D.new()
	body.name = "Walker"
	body.collision_layer = 2
	body.collision_mask = 1
	body.floor_snap_length = 0.25
	body.position = Vector3(0, -1.61, 0)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.23
	capsule.height = 1.65
	shape.shape = capsule
	shape.position.y = 0.825
	body.add_child(shape)
	add_child(body)
	camera = Camera3D.new()
	camera.name = "View"
	camera.position.y = 1.63
	camera.near = 0.05
	camera.far = 300
	camera.fov = 75
	body.add_child(camera)
	camera.make_current()
	initial_pose = camera.global_transform
	figures = Node3D.new()
	add_child(figures)
	var box := BoxMesh.new()
	box.size = Vector3(0.15,0.15,0.15)
	add_mesh(box, Vector3(0.5,-0.5,-1.8), Color("f2a436"), figures)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	status = Label.new()
	status.position = Vector2(16,16)
	status.add_theme_font_size_override("font_size", 18)
	canvas.add_child(status)
	RenderingServer.call("viewport_set_measure_render_time", get_viewport().get_viewport_rid(), true)
	print("SPLAT_READY ", JSON.stringify({"mode":mode,"points":point_count,"load_ms":loaded_ms,
		"collision_proxies":collision_count,"adapter":RenderingServer.get_video_adapter_name()}))
	last_usec = Time.get_ticks_usec()

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
	mat.set_shader_parameter("panorama", load("res://gray_pier_pano.png"))
	panorama_node.material_override = mat
	add_child(panorama_node)

func _build_dock() -> void:
	dock = Node3D.new()
	dock.name = "AuthoredWalkableDock"
	dock.position = Vector3(0,-1.63,-0.65)
	add_child(dock)
	var model = load("res://assets/models/locations/lit/gray_pier.glb").instantiate()
	dock.add_child(model)
	_build_bank_skirt(model)
	var details = load("res://scripts/shore_details.gd").create("gray_pier")
	dock.add_child(details)
	var reeds: MultiMeshInstance3D = details.get_node("CrossedShorePlants")
	reeds.material_override.shader = load("res://shore_reeds.gdshader")
	for i in reeds.multimesh.instance_count:
		var placement := reeds.multimesh.get_instance_transform(i)
		if placement.origin.y < -0.2:
			# Bury the card base while preserving each original plant tip.
			var height := placement.basis.y.length()
			placement.basis.y *= (height+0.18)/height
			placement.origin.y -= 0.18
			reeds.multimesh.set_instance_transform(i,placement)
			var data := reeds.multimesh.get_instance_custom_data(i)
			data.g = 1.0
			reeds.multimesh.set_instance_custom_data(i,data)
	# Keep authored near geometry. The broad distant bank is replaced by splats/panorama.
	for mesh_node in model.find_children("*", "MeshInstance3D", true, false):
		if str(mesh_node.name).contains("bank_distant") or str(mesh_node.name).ends_with("_reed"):
			mesh_node.hide()
		_remove_seed_heads(mesh_node)
		for surface in mesh_node.mesh.get_surface_count():
			var source := mesh_node.get_active_material(surface) as StandardMaterial3D
			if source == null: continue
			if source.resource_name.begins_with("FG_rope"):
				var rope := StandardMaterial3D.new()
				rope.albedo_color = Color("9b8158")
				rope.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				mesh_node.set_surface_override_material(surface,rope)
			elif str(mesh_node.name).contains("BakedForeground"):
				var mat := ShaderMaterial.new()
				mat.shader = load("res://hybrid_bank.gdshader" if source.resource_name.begins_with("FG_bank") else "res://assets/environment/baked_foreground.gdshader")
				mat.set_shader_parameter("base_color",source.albedo_color)
				if source.resource_name.begins_with("FG_bank"):
					mat.set_shader_parameter("panorama",load("res://gray_pier_pano.png"))
				mat.set_shader_parameter("albedo_tex",source.albedo_texture)
				mat.set_shader_parameter("normal_tex",source.normal_texture)
				mat.set_shader_parameter("normal_depth",0.28 if source.normal_enabled else 0.0)
				mat.set_shader_parameter("irradiance_tex",load("res://assets/textures/lighting/gray_pier_irradiance.exr"))
				mat.set_shader_parameter("sky_tex",load("res://assets/textures/lighting/gray_pier_sky.exr"))
				mat.set_shader_parameter("occlusion_tex",load("res://assets/textures/lighting/gray_pier_ao.png"))
				mesh_node.set_surface_override_material(surface,mat)
	var records: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://gray_pier_manifest.json"))
	for proxy in records.colliders:
		if not proxy.get("enabled",true) or proxy.role == "seat": continue
		var solid := StaticBody3D.new()
		solid.collision_layer = 1
		solid.collision_mask = 2
		solid.position = Vector3(proxy.position[0],proxy.position[1],proxy.position[2])
		solid.rotation.y = proxy.get("yaw",0.0)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(proxy.size[0],proxy.size[1],proxy.size[2])
		shape.shape = box
		solid.add_child(shape)
		dock.add_child(solid)
		collision_count += 1

# Same geometry cleanup used by the main game's shore_details.gd.
func _remove_seed_heads(node: MeshInstance3D) -> void:
	var mesh := ArrayMesh.new()
	for surface in node.mesh.get_surface_count():
		var arrays := node.mesh.surface_get_arrays(surface)
		var mat := node.mesh.surface_get_material(surface)
		if mat and mat.resource_name.begins_with("FG_bank"):
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for i in vertices.size():
				var p := vertices[i]
				# Preserve the full rear floor and its immediate decorated border.
				var outside := Vector2(maxf(absf(p.x)-4.5,0),maxf(absf(p.z-8)-2,0)).length()
				var edge := 2.8 + 0.35*sin(p.x*1.7) + 0.25*sin(p.z*2.3)
				var weight := smoothstep(0.5,edge,outside)
				# Keep mainland connected behind the rear fence; immerse only
				# the side/front apron, with an irregular shoreline contour.
				var mainland := smoothstep(5.5,8.0,p.z)*(1.0-smoothstep(4.5,8.0,absf(p.x)))
				var target := lerpf(-0.55,0.3,mainland)
				var old_y := p.y
				p.y = lerpf(p.y,target,weight)
				if absf(p.y-old_y)>0.00001:
					terrain_changed += 1
					if outside <= 0.5: protected_terrain_changed += 1
				vertices[i] = p
			arrays[Mesh.ARRAY_VERTEX] = vertices
		if mat and mat.resource_name.begins_with("FG_wood_end"):
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var kept := PackedInt32Array()
			for i in range(0,indices.size(),3):
				if vertices[indices[i]].y > 0.05 and vertices[indices[i+1]].y > 0.05 and vertices[indices[i+2]].y > 0.05: continue
				kept.append_array(indices.slice(i,i+3))
			if kept.is_empty(): continue
			arrays[Mesh.ARRAY_INDEX] = kept
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		mesh.surface_set_material(mesh.get_surface_count()-1,mat)
	node.mesh = mesh

# Ground the retained right-bank splats without changing playable terrain.
func _build_bank_skirt(model: Node3D) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(0.43,0.32,0.23)
	for node in model.find_children("*","MeshInstance3D",true,false):
		for surface in node.mesh.get_surface_count():
			var source := node.mesh.surface_get_material(surface) as StandardMaterial3D
			if source and source.resource_name.begins_with("FG_bank"):
				mat.albedo_texture = source.albedo_texture
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz in 51:
		for ix in 8:
			for corner in [Vector2(0,0),Vector2(0,1),Vector2(1,0),Vector2(1,0),Vector2(0,1),Vector2(1,1)]:
				var z: float = -18.0+(float(iz)+corner.y)*0.5
				var x: float = 5.25+(float(ix)+corner.x)*0.5
				var edge := 5.3+0.18*sin(z*1.3)+0.12*sin(z*2.7)
				var rise := smoothstep(edge,7.0,x)
				var ends := smoothstep(-18.0,-14.0,z)*(1.0-smoothstep(5.0,7.5,z))
				var y := lerpf(-2.16,-1.0+0.06*sin(z*0.8),rise*ends)
				st.set_uv(Vector2(x,z)*0.65)
				st.add_vertex(Vector3(x,y,z))
	st.generate_normals()
	var bank := MeshInstance3D.new()
	bank.name = "RightBankShorelineSkirt"
	bank.mesh = st.commit()
	bank.material_override = mat
	add_child(bank)

func _build_water() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(180,180)
	plane.subdivide_width = 32
	plane.subdivide_depth = 32
	water = MeshInstance3D.new()
	water.mesh = plane
	water.position = Vector3(0,-1.98,-50)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://lake_water.gdshader")
	mat.set_shader_parameter("panorama",load("res://gray_pier_pano.png"))
	mat.set_shader_parameter("sky_inverse",Basis(Vector3.UP, PI))
	mat.set_shader_parameter("sky_energy",1.0)
	mat.set_shader_parameter("shadow_lift",0.0)
	mat.set_shader_parameter("vibrance",1.0)
	mat.set_shader_parameter("ripple_strength",0.22)
	mat.set_shader_parameter("water_roughness",0.28)
	mat.set_shader_parameter("deep_color",Color("263332"))
	mat.set_shader_parameter("blend_start",18.0)
	mat.set_shader_parameter("blend_end",42.0)
	water.material_override = mat
	add_child(water)

func _physics_process(delta: float) -> void:
	if benchmark or body == null or mode == "full": return
	var move := Vector3(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),0,
		float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
	move = Basis(Vector3.UP,camera.rotation.y)*move.limit_length()
	body.velocity = Vector3(move.x*2, -0.5 if body.is_on_floor() else body.velocity.y-9.8*delta, move.z*2)
	body.move_and_slide()
	if body.position.y < -5: body.position = Vector3(0,-1.61,0)

func _check_collisions() -> Dictionary:
	var space := get_world_3d().direct_space_state
	var floor_hits: Array = []
	for p in [Vector3(0,0,0),Vector3(0,0,-5),Vector3(0,0,7)]:
		var q := PhysicsRayQueryParameters3D.create(p,p+Vector3.DOWN*4,1)
		var hit := space.intersect_ray(q)
		floor_hits.append({"at":str(p),"hit":not hit.is_empty(),"y":hit.get("position",Vector3.ZERO).y})
	var collision := body.move_and_collide(Vector3(4,0,0),true)
	return {"floor_hits":floor_hits,"side_barrier_blocks":collision != null,
		"side_distance":collision.get_travel().length() if collision else -1,"proxies":collision_count,
		"terrain_vertices_adjusted":terrain_changed,"protected_terrain_vertices_changed":protected_terrain_changed,
		"reed_instances":dock.get_node("ShoreTransitionDetails/CrossedShorePlants").multimesh.instance_count,
		"ground_cover_patches":dock.get_node("ShoreTransitionDetails").get_child_count()-1}

func _process(delta: float) -> void:
	frame += 1
	var now := Time.get_ticks_usec()
	var wall_ms := float(now-last_usec)/1000.0
	last_usec = now
	if benchmark:
		if frame == 60 and mode != "full":
			var checks := _check_collisions()
			FileAccess.open("res://hybrid_collision_checks.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"\t"))
			print("COLLISION_RESULT ",JSON.stringify(checks))
		if frame > 120:
			samples.append(delta*1000)
			wall_samples.append(wall_ms)
			gpu_samples.append(float(RenderingServer.call("viewport_get_measured_render_time_gpu",get_viewport().get_viewport_rid())))
			var t := float(frame-120)/600.0
			camera.global_position = Vector3(sin(t*TAU)*0.7,sin(t*TAU*2)*0.25,0)
			camera.rotation.y = sin(t*TAU)*0.5
		if frame == 720:
			wall_samples.sort(); gpu_samples.sort(); samples.sort()
			var report := {"mode":mode,"points":point_count,"frames":600,
				"wall_frame_ms_median":wall_samples[300],"wall_frame_ms_p95":wall_samples[570],
				"gpu_ms_median":gpu_samples[300],"gpu_ms_p95":gpu_samples[570],
				"engine_delta_ms_median":samples[300],"load_ms":loaded_ms,
				"render_memory":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
				"static_memory":OS.get_static_memory_usage(),"collision_proxies":collision_count,
				"resolution":[1280,720],"adapter":RenderingServer.get_video_adapter_name(),
				"scope":"desktop mono, matching camera path, vsync disabled, no capture stalls during samples"}
			FileAccess.open("res://hybrid_"+mode+"_metrics.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
			print("SPLAT_RESULT ",JSON.stringify(report))
			await capture("hybrid_"+mode+"_benchmark_end")
			get_tree().quit()
	status.text = "Gray Pier | %s | %s splats | %d FPS\nWASD walk · right mouse look · R reset · T water · F object · P screenshot" % [mode,point_count,Engine.get_frames_per_second()]

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
			KEY_P: _capture_inspection()

func _capture_inspection() -> void:
	# Keep every user capture, with its reproducible camera pose.
	var label := "inspection_%s_%d" % [mode,int(Time.get_unix_time_from_system()*1000)]
	var report := {"mode":mode,"points":point_count,
		"body_position":[body.position.x,body.position.y,body.position.z],
		"camera_position":[camera.global_position.x,camera.global_position.y,camera.global_position.z],
		"camera_rotation":[camera.rotation.x,camera.rotation.y,camera.rotation.z]}
	FileAccess.open("res://"+label+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	capture(label)

func review_saved_views() -> void:
	status.hide()
	var saved_body := body.position
	var saved_rotation := camera.rotation
	set_process_unhandled_input(false)
	set_physics_process(false)
	var captures: Array[String] = []
	for stamp in ["1789553370834","1789553375580","1789553380101","1789553387480","1789553392171","1789553397548","1789553455932"]:
		var pose: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://inspection_hybrid_"+stamp+".json"))
		var p: Array = pose.body_position
		var r: Array = pose.camera_rotation
		body.position = Vector3(p[0],p[1],p[2])
		camera.rotation = Vector3(r[0],r[1],r[2])
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		await capture("review_"+stamp)
		captures.append("review_"+stamp+".png")
	body.position = Vector3(0,-1.61,0)
	var checks := _check_collisions()
	status.show()
	checks["captures"] = captures
	checks["points"] = point_count
	FileAccess.open("res://review_checks.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"\t"))
	body.position = saved_body
	camera.rotation = saved_rotation
	set_process_unhandled_input(true)
	set_physics_process(true)
