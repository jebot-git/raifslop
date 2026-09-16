extends "res://hybrid.gd"

static var chosen := "lake_pier"
var profile: Dictionary
var location_id := "lake_pier"
var review := false
var started := 0
var lighting_original := false
var validate := false
var xr := false
var xr_interface: XRInterface
var xr_origin: XROrigin3D

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--location="): chosen = arg.trim_prefix("--location=")
		if arg == "--xr": xr = true
		if arg == "--benchmark": benchmark = true
		if arg == "--review": review = true
		if arg == "--validate": validate = true;review = true
	if get_tree().has_meta("location_override"):chosen = get_tree().get_meta("location_override")
	location_id = chosen
	profile = JSON.parse_string(FileAccess.get_file_as_string("res://location_profiles.json"))[location_id]
	mode = "hybrid"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("91a3ad")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.7
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var before := Time.get_ticks_msec()
	dataset = location_id+"_near.ply"
	if ResourceLoader.exists("res://"+dataset):
		var resource = load("res://"+dataset)
		resource.point_data_float = PackedFloat32Array()
		point_count = resource.point_count
		splat = load("res://addons/gdgs/runtime/nodes/gaussian_splat_node.gd").new()
		splat.gaussian = resource
		add_child(splat)
		var placement: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://placement.json"))
		var c: Array = placement[dataset].center
		var basis_cv := Basis(Vector3.RIGHT,PI).scaled(Vector3.ONE*float(profile.scale))
		splat.basis = basis_cv
		splat.position = basis_cv*Vector3(c[0],c[1],c[2])
	_build_panorama()
	_build_dock()
	_build_water()
	loaded_ms = Time.get_ticks_msec()-before
	if xr:
		xr_interface = XRServer.find_interface("OpenXR")
		if xr_interface == null or not xr_interface.is_initialized():
			push_error("WiVRn/OpenXR is not initialized; connect the headset and relaunch with --xr")
			get_tree().quit(1)
			return
		get_viewport().use_xr = true
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		body = load("res://scripts/locomotion.gd").new()
		body.position = Vector3(0,-1.61,0)
		body.set("safe_spawn",body.position)
		add_child(body)
		xr_origin = XROrigin3D.new()
		body.add_child(xr_origin)
		camera = XRCamera3D.new()
		camera.near = .05
		camera.far = 350
		xr_origin.add_child(camera)
		camera.make_current()
		var left := XRController3D.new()
		left.tracker = "left_hand"
		left.pose = "grip"
		var right := XRController3D.new()
		right.tracker = "right_hand"
		right.pose = "grip"
		xr_origin.add_child(left);xr_origin.add_child(right)
		body.set("origin",xr_origin);body.set("head",camera)
		body.set("left",left);body.set("right",right);body.set("xr",true)
		xr_interface.session_focussed.connect(func():body.set("tracking_focused",true))
		xr_interface.session_visible.connect(func():body.set("tracking_focused",false))
		right.button_pressed.connect(func(button:String):
			if button=="ax_button":
				get_tree().set_meta("location_override","simons_town_rocks" if location_id=="lake_pier" else "lake_pier")
				get_tree().reload_current_scene()
			if button=="by_button" and splat:splat.visible=not splat.visible)
		print("LOCATION_XR_READY views=",xr_interface.get_view_count()," target=",xr_interface.get_render_target_size())
	else:
		body = CharacterBody3D.new()
		body.name = "Walker"
		body.collision_layer = 2
		body.collision_mask = 1
		body.floor_snap_length = 0.25
		body.position = Vector3(0,-1.61,0)
		var shape := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = .23
		capsule.height = 1.65
		shape.shape = capsule
		shape.position.y = .825
		body.add_child(shape)
		add_child(body)
		camera = Camera3D.new()
		camera.position.y = 1.63
		camera.near = .05
		camera.far = 350
		camera.fov = 75
		body.add_child(camera)
		camera.make_current()
	figures = Node3D.new()
	add_child(figures)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	status = Label.new()
	status.position = Vector2(16,16)
	status.add_theme_font_size_override("font_size",18)
	canvas.add_child(status)
	RenderingServer.call("viewport_set_measure_render_time",get_viewport().get_viewport_rid(),true)
	last_usec = Time.get_ticks_usec()
	started = Time.get_ticks_msec()
	print("LOCATION_READY ",location_id," points=",point_count," scale=",profile.scale)
	if validate:call_deferred("validate_location")
	elif review:call_deferred("review_location")

func _build_panorama() -> void:
	super._build_panorama()
	panorama_node.material_override.set_shader_parameter("panorama",load("res://"+location_id+"_pano.png"))
	panorama_node.material_override.set_shader_parameter("clean_lake_background",location_id=="lake_pier")

func _build_dock() -> void:
	dock = Node3D.new()
	dock.name = "AuthoredForeground"
	dock.position = Vector3(0,-1.63,-.65)
	add_child(dock)
	var model = load(profile.manifest.model).instantiate()
	dock.add_child(model)
	if location_id == "simons_town_rocks":
		dock.add_child(load("res://scripts/simons_rear_details.gd").create())
		coastal_footings(model)
		_cover_simons_corners()
	for node in model.find_children("*","MeshInstance3D",true,false):
		if str(node.name).contains("_distant"): node.hide()
		for surface in node.mesh.get_surface_count():
			var source := node.get_active_material(surface) as StandardMaterial3D
			if source == null: continue
			if source.resource_name.begins_with("FG_rope"):
				var rope := StandardMaterial3D.new()
				rope.albedo_color = Color("9b8158")
				rope.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				node.set_surface_override_material(surface,rope)
			elif str(node.name).contains("BakedForeground"):
				var mat := ShaderMaterial.new()
				var ground := source.resource_name.begins_with("FG_concrete") or source.resource_name.begins_with("FG_gravel") or source.resource_name.begins_with("FG_grass")
				mat.shader = load("res://location_ground.gdshader" if ground else "res://assets/environment/baked_foreground.gdshader")
				if ground:
					mat.set_shader_parameter("ground_bounds",Vector4(0,1.5,2.8,3.3) if location_id=="lake_pier" else Vector4(0,3.5,8,9))
					mat.set_shader_parameter("ground_rounding",3.0 if location_id=="simons_town_rocks" else 0.0)
				mat.set_shader_parameter("base_color",source.albedo_color)
				mat.set_shader_parameter("albedo_tex",source.albedo_texture)
				mat.set_shader_parameter("normal_tex",source.normal_texture)
				mat.set_shader_parameter("normal_depth",.28 if source.normal_enabled else 0)
				mat.set_shader_parameter("irradiance_tex",load("res://simons_panorama_irradiance.exr") if location_id=="simons_town_rocks" and ResourceLoader.exists("res://simons_panorama_irradiance.exr") else load("res://assets/textures/lighting/"+location_id+"_irradiance.exr"))
				mat.set_shader_parameter("sky_tex",load("res://assets/textures/lighting/"+location_id+"_sky.exr"))
				mat.set_shader_parameter("occlusion_tex",load("res://assets/textures/lighting/"+location_id+"_ao.png"))
				node.set_surface_override_material(surface,mat)
	if location_id == "lake_pier":
		_build_lake_rear_link(model)
		_build_lake_billboard()
	for proxy in profile.manifest.colliders:
		if proxy.role == "seat" or not proxy.get("enabled",true):continue
		var solid := StaticBody3D.new()
		solid.collision_layer = 1
		solid.collision_mask = 2
		solid.position = Vector3(proxy.position[0],proxy.position[1],proxy.position[2])
		solid.rotation.y = proxy.get("yaw",0)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(proxy.size[0],proxy.size[1],proxy.size[2])
		shape.shape = box
		solid.add_child(shape)
		dock.add_child(solid)
		collision_count += 1

func _build_water() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(220,220)
	plane.subdivide_width = 48
	plane.subdivide_depth = 48
	water = MeshInstance3D.new()
	water.mesh = plane
	water.position = Vector3(0,float(profile.water_y),-50)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://location_water.gdshader")
	mat.set_shader_parameter("panorama",load("res://"+location_id+"_pano.png"))
	mat.set_shader_parameter("sky_inverse",Basis(Vector3.UP,PI))
	mat.set_shader_parameter("sky_energy",1.0)
	mat.set_shader_parameter("shadow_lift",0.0)
	mat.set_shader_parameter("vibrance",1.0)
	mat.set_shader_parameter("water_roughness",profile.roughness)
	mat.set_shader_parameter("ripple_strength",profile.ripples)
	mat.set_shader_parameter("deep_color",Color(profile.color))
	mat.set_shader_parameter("water_rear",profile.water_rear)
	mat.set_shader_parameter("clean_lake_background",location_id=="lake_pier")
	mat.set_shader_parameter("blend_start",24.0 if location_id=="lake_pier" else 12.0)
	mat.set_shader_parameter("blend_end",40.0 if location_id=="lake_pier" else 30.0)
	water.material_override = mat
	add_child(water)

func _check_collisions() -> Dictionary:
	var hits: Array = []
	for proxy in profile.manifest.colliders:
		if proxy.role != "floor":continue
		var at := dock.position+Vector3(proxy.position[0],2,proxy.position[2])
		var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at,at+Vector3.DOWN*6,1))
		hits.append(not hit.is_empty())
	var before := body.position
	body.position = Vector3(0,-1.61,0)
	var barrier := body.move_and_collide(Vector3(10,0,0),true)
	body.position = before
	return {"floor_hits":hits,"side_barrier_blocks":barrier != null,"collision_proxies":collision_count,
		"rock_cards":dock.get_node("RearRockTransitions/CurvedRockCards").multimesh.instance_count if location_id=="simons_town_rocks" else 0,"rear_connection":dock.has_node("RearMaintenanceConnection"),"right_billboard":dock.has_node("RightHarbourBillboard"),"water_rear":profile.water_rear}

func _process(delta: float) -> void:
	frame += 1
	var now := Time.get_ticks_usec()
	var interval := float(now-last_usec)/1000
	last_usec = now
	if xr and frame%300==0:
		var target := xr_interface.get_render_target_size()
		var data := {"location":location_id,"views":xr_interface.get_view_count(),"target":[target.x,target.y],"fps":Engine.get_frames_per_second(),"head_position":[camera.global_position.x,camera.global_position.y,camera.global_position.z],"gpu_ms":RenderingServer.call("viewport_get_measured_render_time_gpu",get_viewport().get_viewport_rid())}
		FileAccess.open("res://xr_session.json",FileAccess.WRITE).store_string(JSON.stringify(data,"\t"))
	if benchmark:
		if frame > 120:
			wall_samples.append(interval)
			gpu_samples.append(float(RenderingServer.call("viewport_get_measured_render_time_gpu",get_viewport().get_viewport_rid())))
			var t := float(frame-120)/600
			camera.global_position = Vector3(sin(t*TAU)*.7,sin(t*TAU*2)*.25,0)
			camera.rotation.y = sin(t*TAU)*.7
		if frame == 720:
			wall_samples.sort();gpu_samples.sort()
			var data := {"location":location_id,"points":point_count,"frames":600,"wall_median_ms":wall_samples[300],"wall_p95_ms":wall_samples[570],"gpu_median_ms":gpu_samples[300],"gpu_p95_ms":gpu_samples[570],"render_memory":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),"adapter":RenderingServer.get_video_adapter_name(),"resolution":[1280,720],"scope":"desktop mono; not a stereo headset benchmark","checks":_check_collisions()}
			FileAccess.open("res://"+location_id+"_metrics.json",FileAccess.WRITE).store_string(JSON.stringify(data,"\t"))
			print("LOCATION_RESULT ",JSON.stringify(data))
			await capture(location_id+"_benchmark")
			get_tree().quit()
	status.text = "%s | %d splats | %d FPS\n1 Lake Pier · 2 Simons Rocks · B splats on/off · WASD walk · right mouse look · R reset · P capture · L lighting" % [profile.name,point_count,Engine.get_frames_per_second()]

func _unhandled_input(event: InputEvent) -> void:
	if benchmark or review:return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_P:
			_capture_location_inspection()
			return
		if event.physical_keycode == KEY_L and location_id=="simons_town_rocks":
			lighting_original = not lighting_original
			_set_lighting(lighting_original)
			return
		if event.physical_keycode == KEY_B:
			if splat: splat.visible = not splat.visible
			return
		if event.physical_keycode in [KEY_1,KEY_2]:
			chosen = "lake_pier" if event.physical_keycode==KEY_1 else "simons_town_rocks"
			# CLI selection applies only at first launch, not during interactive switching.
			get_tree().set_meta("location_override",chosen)
			get_tree().reload_current_scene()
			return
	if xr:
		if event is InputEventKey and event.pressed and event.physical_keycode==KEY_R:body.call("relocate",Vector3(0,-1.61,0))
		return
	super._unhandled_input(event)

func review_location() -> void:
	review = true
	set_physics_process(false)
	status.hide()
	var poses := [Vector3(0,0,0),Vector3(0,0,PI),Vector3(-1.8,2.5,-1.0),Vector3(1.8,2.5,1.0)]
	for i in poses.size():
		body.position = Vector3(poses[i].x,-1.63,poses[i].y)
		camera.rotation = Vector3(-.14,poses[i].z,0)
		for enabled in [false,true]:
			if splat:splat.visible = enabled
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			await capture(location_id+("_hybrid_" if enabled else "_baseline_")+str(i))
	var checks := _check_collisions()
	FileAccess.open("res://"+location_id+"_review.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"\t"))
	body.position = Vector3(0,-1.61,0)
	camera.rotation = Vector3.ZERO
	status.show()
	set_physics_process(true)
	review = false

func coastal_footings(root:Node3D) -> void:
	var stone:Material
	for node in root.find_children("*","MeshInstance3D",true,false):
		for surface in node.mesh.get_surface_count():
			var mat:Material=node.mesh.surface_get_material(surface)
			# The scan uses an atlas with empty islands; the terrace material tiles.
			if mat and mat.resource_name.begins_with("FG_stone") and not mat.resource_name.contains("scan"):stone=mat
	if stone==null:return
	# Continuous stone shoulders bridge the terrace-to-boulder gaps. They
	# extend below water and under the rocks instead of ending at their faces.
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var quads:Array=[]
	for side in [-1.0,1.0]:
		quads.append([Vector3(side*4.4,-.015,-3.05),Vector3(side*8.8,-.9,-5.2),Vector3(side*8.8,-.9,9),Vector3(side*4.4,-.015,7.1)])
	quads.append([Vector3(-4.4,-.015,-2.98),Vector3(4.4,-.015,-2.98),Vector3(6,-1.25,-6.5),Vector3(-6,-1.25,-6.5)])
	for quad in quads:
		var normal:Vector3=(quad[1]-quad[0]).cross(quad[2]-quad[0]).normalized()
		if normal.y<0:normal=-normal
		for i in [0,1,2,0,2,3]:
			var p:Vector3=quad[i]
			st.set_normal(normal);st.set_uv(Vector2(p.x,p.z)*.5);st.add_vertex(p)
	var mesh:=MeshInstance3D.new();mesh.name="CoastalStoneFootings";mesh.mesh=st.commit()
	var mat:StandardMaterial3D=stone.duplicate();mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	mesh.mesh.surface_set_material(0,mat);root.add_child(mesh);mesh.create_trimesh_collision()


func _set_lighting(original: bool) -> void:
	for node in dock.find_children("*","MeshInstance3D",true,false):
		for surface in node.mesh.get_surface_count():
			var mat := node.get_active_material(surface) as ShaderMaterial
			if mat and str(node.name).contains("BakedForeground"):
				mat.set_shader_parameter("irradiance_tex",load("res://assets/textures/lighting/simons_town_rocks_irradiance.exr") if original else load("res://simons_panorama_irradiance.exr"))

func compare_lighting() -> void:
	review = true
	set_physics_process(false)
	status.hide()
	for original in [true,false]:
		_set_lighting(original)
		for i in 3:
			body.position = Vector3(0,-1.63,0)
			camera.rotation = Vector3(-.14,i*PI/2,0)
			await RenderingServer.frame_post_draw
			await capture("simons_light_"+("old_" if original else "hdr_")+str(i))
	body.position = Vector3(0,-1.61,0)
	camera.rotation = Vector3.ZERO
	review = false
	set_physics_process(true)
	status.show()

func _capture_location_inspection() -> void:
	var label := location_id+"_inspection_"+str(int(Time.get_unix_time_from_system()*1000))
	var pose := {"location":location_id,"camera_position":[camera.global_position.x,camera.global_position.y,camera.global_position.z],"camera_rotation":[camera.rotation.x,camera.rotation.y,camera.rotation.z],"splats_visible":splat.visible if splat else false,"water_visible":water.visible,"lighting_original":lighting_original}
	FileAccess.open("res://"+label+".json",FileAccess.WRITE).store_string(JSON.stringify(pose,"\t"))
	await capture(label)

func review_culling() -> Dictionary:
	review = true
	set_physics_process(false)
	status.hide()
	# Isolate panorama draw order from water occlusion and scene-specific image masks.
	var water_was_visible := water.visible
	var clean_was_enabled: bool = panorama_node.material_override.get_shader_parameter("clean_lake_background")
	water.hide()
	panorama_node.material_override.set_shader_parameter("clean_lake_background",false)
	var rows: Array = []
	var good: Shader = panorama_node.material_override.shader
	var bad := Shader.new()
	bad.code = good.code.replace("depth_draw_opaque","depth_draw_never")
	for legacy in [true,false]:
		panorama_node.material_override.shader = bad if legacy else good
		for i in 8:
			body.position = Vector3(0,-1.63,0 if i<4 else 2.8)
			camera.rotation = Vector3(-.2,(i%4)*PI/2,0)
			splat.hide()
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var off := get_viewport().get_texture().get_image()
			off.resize(160,90)
			splat.show()
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var on := get_viewport().get_texture().get_image()
			on.resize(160,90)
			var different := 0
			for y in 75:
				for x in 160:
					var a := off.get_pixel(x,y)
					var b := on.get_pixel(x,y)
					if abs(a.r-b.r)+abs(a.g-b.g)+abs(a.b-b.b)>.09:different+=1
			rows.append({"legacy":legacy,"pose":i,"splat_pixels":different})
			if i==2:await capture(location_id+("_cull_before" if legacy else "_cull_fixed"))
	panorama_node.material_override.shader = good
	panorama_node.material_override.set_shader_parameter("clean_lake_background",clean_was_enabled)
	water.visible = water_was_visible
	body.position = Vector3(0,-1.61,0)
	camera.rotation = Vector3.ZERO
	review = false
	set_physics_process(true)
	status.show()
	var recovered := int(rows[10].splat_pixels)-int(rows[2].splat_pixels)
	var report := {"location":location_id,"scope":"isolated panorama/splat order, water hidden and original panorama mask","rows":rows,"rear_pixels_recovered":recovered,"passed":recovered>300,"checks":_check_collisions()}
	FileAccess.open("res://"+location_id+"_culling.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	return report

func _build_lake_rear_link(model: Node3D) -> void:
	# Non-walkable maintenance connection, entirely behind the existing rear fence.
	var concrete: ShaderMaterial
	var floor_triangles: Array = []
	for node in model.find_children("*","MeshInstance3D",true,false):
		for surface in node.mesh.get_surface_count():
			var source := node.mesh.surface_get_material(surface) as StandardMaterial3D
			if not source or not source.resource_name.begins_with("FG_concrete"):continue
			if not node.get_active_material(surface) is ShaderMaterial:continue
			concrete = node.get_active_material(surface).duplicate() as ShaderMaterial
			concrete.shader = load("res://bridge_ground.gdshader")
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var transform: Transform3D = dock.global_transform.affine_inverse()*node.global_transform
			for i in range(0,indices.size(),3):
				var points: Array[Vector2] = []
				var ids := [indices[i],indices[i+1],indices[i+2]]
				var horizontal := true
				for id in ids:
					var v: Vector3 = transform*vertices[id]
					if absf(v.y)>.1:horizontal=false
					points.append(Vector2(v.x,v.z))
				if horizontal and absf((points[1]-points[0]).cross(points[2]-points[0]))>.00001:
					floor_triangles.append({"p":points,"uv":[arrays[Mesh.ARRAY_TEX_UV][ids[0]],arrays[Mesh.ARRAY_TEX_UV][ids[1]],arrays[Mesh.ARRAY_TEX_UV][ids[2]]],"uv2":[arrays[Mesh.ARRAY_TEX_UV2][ids[0]],arrays[Mesh.ARRAY_TEX_UV2][ids[1]],arrays[Mesh.ARRAY_TEX_UV2][ids[2]]]})
	assert(concrete != null and not floor_triangles.is_empty(),"Bridge requires authored floor texture and lightmap coordinates")
	var irradiance: Image = concrete.get_shader_parameter("irradiance_tex").get_image()
	var occlusion: Image = concrete.get_shader_parameter("occlusion_tex").get_image()
	if irradiance.is_compressed():irradiance.decompress()
	if occlusion.is_compressed():occlusion.decompress()
	var root := Node3D.new()
	root.name = "RearMaintenanceConnection"
	dock.add_child(root)
	# The full-width landing seats the platform; a narrower gangway reaches
	# the generated marina at world Z approximately 11m.
	var quads := [
		[Vector3(-2.7,0,4.5),Vector3(2.7,0,4.5),Vector3(2.7,0,6.1),Vector3(-2.7,0,6.1)],
		[Vector3(-2.1,0,6.1),Vector3(.1,0,6.1),Vector3(.1,0,12.2),Vector3(-2.1,0,12.2)]]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Transfer edge irradiance into vertex colors, avoiding interpolation across atlas islands.
	for quad in quads:
		var nx := ceili((quad[1].x-quad[0].x)/.2)
		var nz := ceili((quad[3].z-quad[0].z)/.2)
		for iz in nz:
			for ix in nx:
				for corner in [Vector2(0,0),Vector2(1,1),Vector2(1,0),Vector2(0,0),Vector2(0,1),Vector2(1,1)]:
					var p: Vector3 = quad[0]+Vector3((quad[1].x-quad[0].x)*(ix+corner.x)/nx,0,(quad[3].z-quad[0].z)*(iz+corner.y)/nz)
					st.set_normal(Vector3.UP)
					var mapped := _bridge_uv(Vector2(p.x,p.z),floor_triangles)
					st.set_uv(mapped[0])
					var edge_uv: Vector2 = _bridge_uv(Vector2(clampf(p.x,-2.35,2.35),4.25),floor_triangles)[1]
					var light := _bridge_light_sample(irradiance,edge_uv)
					var ao := lerpf(1.0,_bridge_light_sample(occlusion,edge_uv).r,.25)
					st.set_color(Color(light.r*ao,light.g*ao,light.b*ao,1))
					st.add_vertex(p)
	var top := MeshInstance3D.new()
	top.mesh = st.commit()
	top.material_override = concrete
	root.add_child(top)
	var side := StandardMaterial3D.new()
	side.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	side.albedo_color = Color(.32,.34,.35)
	var steel := StandardMaterial3D.new()
	steel.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	steel.albedo_color = Color("414b4e")
	_lake_link_box(root,Vector3(0,-.27,5.3),Vector3(5.4,.32,1.6),side)
	_lake_link_box(root,Vector3(-1,-.4,9.15),Vector3(2.2,.24,6.1),side)
	for z in [6.1,8.7,12.2]:
		for x in [-2.12,.12]:
			_lake_link_box(root,Vector3(x,-.5,z),Vector3(.08,2.8,.08),steel)
	for x in [-2.12,.12]:
		for y in [.45,.9]:
			_lake_link_box(root,Vector3(x,y,9.15),Vector3(.055,.055,6.1),steel)
	root.set_meta("outside_walkable",true)

func _bridge_uv(point: Vector2,triangles: Array) -> Array[Vector2]:
	var closest := INF
	var result: Array[Vector2] = [Vector2.ZERO,Vector2.ZERO]
	for triangle in triangles:
		var a: Vector2 = triangle.p[0]
		var b: Vector2 = triangle.p[1]-a
		var c: Vector2 = triangle.p[2]-a
		var v := (point-a).cross(c)/b.cross(c)
		var w := b.cross(point-a)/b.cross(c)
		var weights := Vector3(1-v-w,v,w)
		var clamped := weights.max(Vector3.ZERO)
		clamped /= clamped.x+clamped.y+clamped.z
		var nearest: Vector2 = a*clamped.x+triangle.p[1]*clamped.y+triangle.p[2]*clamped.z
		var distance := point.distance_squared_to(nearest)
		if distance<closest:
			closest=distance
			result=[triangle.uv[0]*weights.x+triangle.uv[1]*weights.y+triangle.uv[2]*weights.z,triangle.uv2[0]*clamped.x+triangle.uv2[1]*clamped.y+triangle.uv2[2]*clamped.z]
		if distance<.000001:break
	return result

func _lake_link_box(root: Node3D,at: Vector3,size: Vector3,mat: Material) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = at
	mesh.material_override = mat
	root.add_child(mesh)

func validate_location() -> void:
	await review_location()
	await review_reported_poses()
	if location_id=="simons_town_rocks":await compare_lighting()
	var result := await review_culling()
	print("LOCATION_VALIDATION ",JSON.stringify(result))
	get_tree().quit(0 if result.passed else 1)

func _cover_simons_corners() -> void:
	var cards: MultiMeshInstance3D = dock.get_node("RearRockTransitions/CurvedRockCards")
	var multi := cards.multimesh
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for i in multi.instance_count:
		transforms.append(multi.get_instance_transform(i))
		colors.append(multi.get_instance_custom_data(i))
	multi.instance_count = 9
	for i in transforms.size():
		multi.set_instance_transform(i,transforms[i])
		multi.set_instance_custom_data(i,colors[i])
	for i in 2:
		var side := -1.0 if i==0 else 1.0
		var basis := Basis(Vector3.UP,side*.45).scaled_local(Vector3(6.0,2.8,6.0))
		multi.set_instance_transform(6+i,Transform3D(basis,Vector3(side*6.8,-.55,11.0)))
		multi.set_instance_custom_data(6+i,Color(.95,0,0,1))

	multi.set_instance_transform(8,Transform3D(Basis(Vector3.UP,-.85).scaled_local(Vector3(6.5,2.8,6.5)),Vector3(-7.5,-.35,7.8)))
	multi.set_instance_custom_data(8,Color(.95,0,0,1))

func _build_lake_billboard() -> void:
	var root := Node3D.new()
	root.name = "RightHarbourBillboard"
	dock.add_child(root)
	var frame := StandardMaterial3D.new()
	frame.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	frame.albedo_color = Color("414b49")
	var board := StandardMaterial3D.new()
	board.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	board.albedo_color = Color("b7b5a5")
	# Double-height original fishing-plan parody, beyond the right fence.
	_lake_link_box(root,Vector3(3.2,1.38,1.6),Vector3(.10,2.60,4.5),frame)
	_lake_link_box(root,Vector3(3.14,1.38,1.6),Vector3(.025,2.44,4.30),board)
	for z in [-.3,3.5]:
		_lake_link_box(root,Vector3(3.2,.65,z),Vector3(.10,4,.10),frame)
	var poster := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(4.3,2.44)
	poster.mesh = quad
	var ink := StandardMaterial3D.new()
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.albedo_texture = load("res://fishing_plan_poster.svg")
	poster.material_override = ink
	poster.position = Vector3(3.115,1.38,1.6)
	poster.rotation.y = -PI/2
	root.add_child(poster)
	# Godot's SVG importer does not rasterize font-dependent text.
	for line in [["THE PEOPLE’S LAKE PIER · FISHERIES BUREAU",29,2.49],["LONG LIVE THE FISHING PLAN!",48,2.18],["EXCEED THE FIVE-YEAR FISH QUOTA!",33,.34]]:
		var label := Label3D.new()
		label.text = line[0]
		label.font_size = line[1]
		label.pixel_size = 4.3/1120
		label.modulate = Color("e8d7aa")
		label.outline_size = 0
		label.position = Vector3(3.105,line[2],1.6)
		label.rotation.y = -PI/2
		root.add_child(label)

func review_reported_poses() -> void:
	review = true
	set_physics_process(false)
	status.hide()
	var names := ["simons_town_rocks_inspection_1789557786711","lake_pier_inspection_1789557987597","lake_pier_inspection_1789557996446","lake_pier_inspection_1789558011836","simons_town_rocks_inspection_1789557149057","simons_town_rocks_inspection_1789557177739","lake_pier_inspection_1789557204615","lake_pier_inspection_1789557217849","lake_pier_inspection_1789557236097"]
	for name in names:
		if not name.begins_with(location_id):continue
		if not FileAccess.file_exists("res://"+name+".json"):continue
		var pose: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://"+name+".json"))
		var p: Array = pose.camera_position
		var r: Array = pose.camera_rotation
		body.position = Vector3(p[0],p[1]-1.63,p[2])
		camera.rotation = Vector3(r[0],r[1],r[2])
		await RenderingServer.frame_post_draw
		await capture("detail_fixed_"+name)
	if location_id=="lake_pier":
		body.position = Vector3(-.5,-1.61,.95)
		camera.rotation = Vector3(-.05,-PI/2,0)
		await RenderingServer.frame_post_draw
		await capture("lake_pier_poster_full")
	body.position = Vector3(0,-1.61,0)
	camera.rotation = Vector3.ZERO
	status.show()
	set_physics_process(true)
	review = false

func _physics_process(delta: float) -> void:
	if not xr:super._physics_process(delta)

func _bridge_light_sample(source: Image,uv: Vector2) -> Color:
	var at := uv*Vector2(source.get_size())-Vector2(.5,.5)
	var x := floori(at.x)
	var y := floori(at.y)
	var a := source.get_pixel(clampi(x,0,source.get_width()-1),clampi(y,0,source.get_height()-1))
	var b := source.get_pixel(clampi(x+1,0,source.get_width()-1),clampi(y,0,source.get_height()-1))
	var c := source.get_pixel(clampi(x,0,source.get_width()-1),clampi(y+1,0,source.get_height()-1))
	var d := source.get_pixel(clampi(x+1,0,source.get_width()-1),clampi(y+1,0,source.get_height()-1))
	return a.lerp(b,at.x-x).lerp(c.lerp(d,at.x-x),at.y-y)
