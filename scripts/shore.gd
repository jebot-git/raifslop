extends RefCounted
## Per-location authored meshes and lightweight collision; panoramas remain distant scenery.
const MANIFEST_PATH := "res://assets/models/locations/manifest.json"
static func catalog() -> Dictionary:
	var data = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	return data if data is Dictionary else {}

static func vector(values: Array) -> Vector3:
	return Vector3(values[0], values[1], values[2])

static func create(id: String) -> Node3D:
	if id in ["meadow_bend","boulder_run"]:return preload("res://scripts/river_foreground.gd").create(id)
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
	if id in ["lakeside", "gray_pier", "bell_park_pier"]:
		slope_distant_land(visual)
	if id=="simons_town_rocks":coastal_footings(visual)
	if id=="fish_hoek_beach":extend_hoek_sand(visual)
	if id in ["lake_pier","simons_town_rocks"]:ground_pier_cleat(visual,id)
	if id=="lake_pier":repair_rail_posts(visual)
	repair_bench_supports(visual,id)
	preload("res://scripts/retired_shore_details.gd").apply(visual,id)
	prepare_lighting(visual, id)
	if preload("res://scripts/locations.gd").find_location(id).get("sand_shore",false):
		# Cast/landing rays must see the curved sand slope, not only the flat
		# walking-area proxy, or a retrieved float can disappear into the shore.
		for node in visual.find_children("*","MeshInstance3D",true,false):
			var sand := ArrayMesh.new()
			for surface in node.mesh.get_surface_count():
				var mat:Material=node.mesh.surface_get_material(surface)
				if mat!=null and mat.resource_name.begins_with("FG_sand"):
					sand.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,node.mesh.surface_get_arrays(surface))
			if sand.get_surface_count()>0:
				var body := StaticBody3D.new()
				body.set_meta("role", "floor")
				var shape := CollisionShape3D.new()
				shape.shape = sand.create_trimesh_shape()
				body.add_child(shape)
				node.add_child(body)
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
	var details=preload("res://scripts/shore_details.gd").create(id)
	if details!=null:root.add_child(details)
	preload("res://scripts/shore_dressing.gd").add_to(root,id)
	return root

static func repair_rail_posts(root:Node3D) -> void:
	# Adjacent baked rail spans each included their endpoint post. At the
	# front corners the .8 m post overlaps the 1 m post; rear posts coincide.
	# Filter indices only, retaining the surviving post's UVs and lightmap.
	for node in root.find_children("*","MeshInstance3D",true,false):
		var rebuilt:=ArrayMesh.new()
		var changed:=false
		for surface in node.mesh.get_surface_count():
			var arrays:Array=node.mesh.surface_get_arrays(surface)
			var mat:Material=node.mesh.surface_get_material(surface)
			if mat and mat.resource_name.begins_with("FG_steel"):
				var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
				var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
				if indices.is_empty():
					for i in vertices.size():indices.append(i)
				var kept:=PackedInt32Array()
				var seen:Dictionary={}
				for i in range(0,indices.size(),3):
					var points:Array[Vector3]=[vertices[indices[i]],vertices[indices[i+1]],vertices[indices[i+2]]]
					var short_post:=true
					var top:=false
					var key:Array[String]=[]
					for p in points:
						short_post=short_post and absf(absf(p.x)-2.5)<.046 and absf(p.z+1.5)<.046 and p.y<=.801
						top=top or absf(p.y-.8)<.001
						key.append("%d,%d,%d"%[roundi(p.x*10000),roundi(p.y*10000),roundi(p.z*10000)])
					key.sort()
					var face_key:=";".join(key)
					if (short_post and top) or seen.has(face_key):changed=true;continue
					seen[face_key]=true
					kept.append_array(indices.slice(i,i+3))
				arrays[Mesh.ARRAY_INDEX]=kept
			rebuilt.add_surface_from_arrays(node.mesh.surface_get_primitive_type(surface),arrays)
			rebuilt.surface_set_material(surface,mat)
		if changed:node.mesh=rebuilt

static func ground_pier_cleat(root: Node3D, id: String = "lake_pier") -> void:
	var center:=Vector2(3.5,-2.5) if id=="simons_town_rocks" else Vector2(1.8,-.9)
	# Older baked assets leave the small cleat's pedestal 6 cm above the quay.
	# Extend just its bottom to deck level, retaining the bake and both UV sets.
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var repaired: ArrayMesh
		for surface in node.mesh.get_surface_count():
			var material: Material=node.mesh.surface_get_material(surface)
			if material==null or not material.resource_name.begins_with("FG_steel"):continue
			var arrays: Array=node.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var changed:=false
			for i in vertices.size():
				var p: Vector3=vertices[i]
				if absf(p.x-center.x)<.091 and absf(p.z-center.y)<.051 and absf(p.y-.06)<.001:
					p.y=0;vertices[i]=p;changed=true
			if not changed:continue
			if repaired==null:repaired=node.mesh.duplicate()
			arrays[Mesh.ARRAY_VERTEX]=vertices
			# Rebuild in order so surface material/atlas assignments stay stable.
			var rebuilt:=ArrayMesh.new()
			for index in node.mesh.get_surface_count():
				rebuilt.add_surface_from_arrays(node.mesh.surface_get_primitive_type(index),arrays if index==surface else repaired.surface_get_arrays(index))
				rebuilt.surface_set_material(index,node.mesh.surface_get_material(index))
			repaired=rebuilt
		if repaired!=null:node.mesh=repaired

static func repair_bench_supports(root: Node3D, id: String) -> void:
	# Older baked benches put the rear uprights on the seating side of the back.
	# Translate only those steel legs, retaining both UV sets and baked textures.
	var centers:Dictionary={"lakeside":[Vector2(-4,7),Vector2(4,9)],"lake_pier":[Vector2(0,3)],"gray_pier":[Vector2(-2.9,8.5)],"simons_town_rocks":[Vector2(-2.5,5.5)],"secluded_beach":[Vector2(-3.5,8.4)]}
	if not centers.has(id):return
	for node in root.find_children("*","MeshInstance3D",true,false):
		var rebuilt:=ArrayMesh.new()
		var changed:=false
		for surface in node.mesh.get_surface_count():
			var arrays:Array=node.mesh.surface_get_arrays(surface)
			var mat:Material=node.mesh.surface_get_material(surface)
			if mat and mat.resource_name.begins_with("FG_steel"):
				var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
				for i in vertices.size():
					var p:Vector3=vertices[i]
					for center in centers[id]:
						if absf(absf(p.x-center.x)-.68)<.036 and absf(p.z-center.y-.23)<.036 and p.y>=-.001 and p.y<=1.071:
							p.z+=.11;vertices[i]=p;changed=true;break
				arrays[Mesh.ARRAY_VERTEX]=vertices
			rebuilt.add_surface_from_arrays(node.mesh.surface_get_primitive_type(surface),arrays)
			rebuilt.surface_set_material(surface,mat)
		if changed:node.mesh=rebuilt

static func slope_distant_land(node: Node, parent_transform := Transform3D.IDENTITY) -> void:
	var transform := parent_transform
	if node is Node3D: transform *= node.transform
	if node is MeshInstance3D:
		var mesh := ArrayMesh.new()
		for surface in node.mesh.get_surface_count():
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			var material: Material = node.mesh.surface_get_material(surface)
			if material and material.resource_name.begins_with("FG_bank"):
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				for i in vertices.size():
					var point: Vector3 = transform * vertices[i]
					# Beyond the protected paths, ease the rising apron down to the
					# water horizon. Preserve the original submerged shoreline toe.
					var weight := smoothstep(14.0, 45.0, maxf(absf(point.x), point.z))
					point.y = lerpf(point.y, minf(point.y, -.85), weight)
					vertices[i] = transform.affine_inverse() * point
				arrays[Mesh.ARRAY_VERTEX] = vertices
			mesh.add_surface_from_arrays(node.mesh.surface_get_primitive_type(surface), arrays)
			mesh.surface_set_material(surface, material)
		node.mesh = mesh
	for child in node.get_children(): slope_distant_land(child, transform)

static func coastal_footings(root:Node3D) -> void:
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

static func prepare_lighting(node: Node, id: String) -> void:
	if node is MeshInstance3D:
		# These separate coarse plant meshes are superseded by grounded cutouts.
		if (id=="lakeside" and str(node.name)=="lakeside_grass") or (id=="gray_pier" and str(node.name)=="gray_pier_reed"):
			node.hide()
		if id=="gray_pier":preload("res://scripts/shore_details.gd").remove_old_seed_heads(node)
		var baked := str(node.name).contains("BakedForeground")
		for index in range(node.mesh.get_surface_count()):
			var source := node.get_active_material(index) as StandardMaterial3D
			if source == null: continue
			if source.resource_name.begins_with("FG_rope"):
				# Spans share the new coil's fibre treatment; old floor coils were removed.
				var rope := ShaderMaterial.new()
				rope.shader=preload("res://assets/environment/shore_details/authored/fibres.gdshader")
				rope.set_shader_parameter("rope",true)
				node.set_surface_override_material(index, rope)
				continue
			if baked:
				var mat := ShaderMaterial.new()
				mat.shader = preload("res://assets/environment/baked_foreground.gdshader")
				var lighting:Dictionary=preload("res://scripts/locations.gd").find_location(id)
				mat.set_shader_parameter("sun_direction",Basis.from_euler(lighting.sun_rotation*PI/180.0).z)
				mat.set_shader_parameter("base_color", source.albedo_color)
				mat.set_shader_parameter("albedo_tex", source.albedo_texture)
				if source.resource_name.begins_with("FG_billboard_print"):
					mat.set_shader_parameter("albedo_tex",load("res://assets/environment/shore_details/fishing_plan_poster.svg"))
					mat.set_shader_parameter("base_color",Color.WHITE)
				mat.set_shader_parameter("normal_tex", source.normal_texture)
				mat.set_shader_parameter("normal_depth", .28 if source.normal_enabled else 0.0)
				if preload("res://scripts/locations.gd").find_location(id).get("sand_shore",false) and source.resource_name.begins_with("FG_sand"):
					mat.set_shader_parameter("normal_depth",.1)
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

static func blend_harbour_ground(root: Node3D, water: ShaderMaterial, bounds := Vector4(0,3,5,6), terrain_only := false, transition_width := Vector2(6,6)) -> void:
	var blend := ShaderMaterial.new()
	blend.shader = preload("res://assets/environment/harbour_ground.gdshader")
	blend.set_shader_parameter("authored_bridge",root.get_meta("location_id","")=="lake_pier")
	blend.set_shader_parameter("far_projection_fade",root.get_meta("location_id","")=="fish_hoek_beach")
	blend.set_shader_parameter("ground_bounds", bounds)
	blend.set_shader_parameter("transition_width", transition_width)
	blend.set_shader_parameter("projection_origin", root.get_meta("spawn",Vector3(0,.02,.65))+Vector3.UP*1.63)
	for setting in ["panorama", "sky_inverse", "sky_energy", "detail_strength", "vibrance", "shadow_lift"]:
		blend.set_shader_parameter(setting, water.get_shader_parameter(setting))
	for node in root.find_children("*", "MeshInstance3D", true, false):
		for index in range(node.mesh.get_surface_count()):
			var mat: Material = node.get_active_material(index)
			var source: Material = node.mesh.surface_get_material(index)
			# Coastal boulders and barrier posts must remain solid outside the walkable
			# footprint; only terrain joins the distant photographic ground.
			if terrain_only and source and not source.resource_name.begins_with("FG_gravel") and not source.resource_name.begins_with("FG_sand") and not source.resource_name.begins_with("FG_grass"):
				continue
			# Printed signs and the bridge retain authored materials beyond the quay.
			if not source: continue
			if str(node.name).contains("BakedForeground") and root.get_meta("location_id","")=="lake_pier":
				if not source.resource_name.begins_with("FG_concrete"):continue
			if mat is ShaderMaterial and root.get_meta("location_id","")=="fish_hoek_beach" and source.resource_name.begins_with("FG_sand"):
				mat.set_shader_parameter("ground_projection",true)
				for setting in ["ground_bounds","transition_width","projection_origin","panorama","sky_inverse","sky_energy","detail_strength","vibrance","shadow_lift"]:
					mat.set_shader_parameter(setting,blend.get_shader_parameter(setting))
			elif mat: mat.next_pass = blend

static func extend_hoek_sand(root:Node3D)->void:
	# The photographed strand bends towards the sea down the left side. Extend
	# the submerged toe and sand apron together outside the playable footprint.
	for node in root.find_children("*","MeshInstance3D",true,false):
		var rebuilt:=ArrayMesh.new()
		for surface in node.mesh.get_surface_count():
			var mat:Material=node.mesh.surface_get_material(surface)
			var arrays:Array=node.mesh.surface_get_arrays(surface)
			if mat and mat.resource_name.begins_with("FG_sand"):
				var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
				for i in vertices.size():
					var p:Vector3=vertices[i]
					var bend:float=smoothstep(10.0,40.0,-p.x)*22.0
					p.z-=bend*(1.0-smoothstep(0.0,10.0,p.z));vertices[i]=p
				arrays[Mesh.ARRAY_VERTEX]=vertices
			rebuilt.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			rebuilt.surface_set_material(rebuilt.get_surface_count()-1,mat)
		node.mesh=rebuilt
