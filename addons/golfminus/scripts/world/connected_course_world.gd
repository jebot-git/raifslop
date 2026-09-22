extends "res://addons/golfminus/scripts/world/course_world.gd"
## One persistent terrain, collision space and clubhouse for every routed hole.
const TILE:=96.0
const STEP:=2.0
static var mesh_cache:Dictionary={}
var course_key:=""
var hole_markers:Array[Node3D]=[]

func build(m:RefCounted)->void:
	model=m;course_key=str(model.course.id)
	_terrain();_shared_water();_shared_scenery();_all_holes();select_hole()

func select_hole()->void:
	if is_instance_valid(grid):remove_child(grid);grid.queue_free()
	_green_grid()
	flag=hole_markers[model.index]

func _terrain()->void:
	var key:String=JSON.stringify(model.course).sha256_text()
	var mat:=ShaderMaterial.new();mat.shader=load("res://addons/golfminus/shaders/terrain.gdshader")
	mat.set_shader_parameter("ambient_fill",1.1)
	for pair in [["cover","river_bank.png"],["grass","grass.jpg"],["grass_normal","grass_normal.jpg"],["gravel","sand.jpg"],["gravel_normal","sand_normal.jpg"]]:mat.set_shader_parameter(pair[0],load("res://addons/golfminus/assets/shared/"+pair[1]))
	# Old per-hole irradiance UVs cannot be reused on a geographically routed world.
	var tiles:Array=mesh_cache.get(key,[])
	if tiles.is_empty():
		var bounds:Rect2=model.course_bounds()
		for tz in range(floori(bounds.position.y/TILE),ceili(bounds.end.y/TILE)):
			for tx in range(floori(bounds.position.x/TILE),ceili(bounds.end.x/TILE)):
				var origin:=Vector2(tx*TILE,tz*TILE)
				var mesh:=_tile_mesh(origin)
				tiles.append({"mesh":mesh,"shape":mesh.create_trimesh_shape()})
		mesh_cache[key]=tiles
	var ground:=Node3D.new();ground.name="PlayableTerrain";add_child(ground)
	for tile in tiles:
		var instance:=MeshInstance3D.new();instance.mesh=tile.mesh;instance.material_override=mat;ground.add_child(instance)
		var body:=StaticBody3D.new();body.set_meta("role","floor");instance.add_child(body)
		var collision:=CollisionShape3D.new();collision.shape=tile.shape;body.add_child(collision)

func _tile_mesh(origin:Vector2)->ArrayMesh:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count:=int(TILE/STEP)
	for iz in count+1:
		for ix in count+1:
			var x:=origin.x+ix*STEP;var z:=origin.y+iz*STEP
			var lie:String=model.lie(x,z)
			var color:Color=COLORS[lie]
			if model.course.kind=="alpine" and lie=="rough":color=Color("58633e")
			if lie=="fairway":color=color.lightened(.055 if int(floor(z/9))%2==0 else 0)
			color.a=0.0 if lie=="sand" else .2 if lie=="green" else .5 if lie=="fairway" else 1.0
			st.set_color(color.srgb_to_linear());st.set_normal(model.normal_at(x,z));st.set_uv(Vector2(x,z));st.set_uv2(Vector2.ZERO)
			st.add_vertex(Vector3(x,model.height(x,z),z))
	for z in count:
		for x in count:
			var a:=z*(count+1)+x
			for i in [a,a+1,a+count+1,a+1,a+count+2,a+count+1]:st.add_index(i)
	st.generate_tangents();return st.commit()

func surface_height(x:float,z:float)->float:
	# Same diagonal as the shared mesh, with a common grid across chunk boundaries.
	var x0:=floorf(x/STEP)*STEP;var z0:=floorf(z/STEP)*STEP
	var u:=(x-x0)/STEP;var v:=(z-z0)/STEP
	var a:float=model.height(x0,z0);var b:float=model.height(x0+STEP,z0)
	var c:float=model.height(x0,z0+STEP);var d:float=model.height(x0+STEP,z0+STEP)
	return a+(b-a)*u+(c-a)*v if u+v<=1 else d+(c-d)*(1-u)+(b-d)*(1-v)

func _shared_water()->void:
	var mat:=material(Color("347580"));mat.roughness=.22;mat.metallic=.15
	# A capsule footprint is shared by the lie, carved basin and visible water.
	for hazard in model.layout.data.get("hazards",[]):
		if hazard.kind!="water":continue
		var vertices:PackedVector3Array=[]
		var points:Array=hazard.points
		var radius:float=hazard.width
		var level:float=hazard.level
		for i in points.size():
			var point:=Vector3(points[i][0],level,points[i][1])
			for segment in 32:
				var a:=TAU*segment/32;var b:=TAU*(segment+1)/32
				vertices.append_array([point,point+Vector3(cos(a),0,sin(a))*radius,point+Vector3(cos(b),0,sin(b))*radius])
			if i==0:continue
			var previous:=Vector3(points[i-1][0],level,points[i-1][1])
			var side:Vector3=(point-previous).normalized().cross(Vector3.UP)*radius
			vertices.append_array([previous-side,point+side,previous+side,previous-side,point-side,point+side])
		var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for vertex in vertices:st.set_normal(Vector3.UP);st.add_vertex(vertex)
		mesh_node(st.commit(),Vector3.ZERO,mat).name="WaterBasin"
	# Mapped ponds/ocean use their real outline; terrain and penalties use the
	# same offline source. No collision plane covers the basin floor.
	for water in model.layout.data.get("water_polygons",[]):
		var polygon:=PackedVector2Array()
		for p in water.points:polygon.append(Vector2(p[0],p[1]))
		if polygon.size()>1 and polygon[0]==polygon[-1]:polygon.remove_at(polygon.size()-1)
		var indices:=Geometry2D.triangulate_polygon(polygon)
		var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in range(0,indices.size(),3):
			for j in [0,1,2]:
				var p:=polygon[indices[i+j]];st.set_normal(Vector3.UP);st.add_vertex(Vector3(p.x,water.level,p.y))
		if not indices.is_empty():mesh_node(st.commit(),Vector3.ZERO,mat).name="MappedWater"
	# Legacy hole ponds are placed in the same shared coordinate system.
	for i in model.patches.size():
		var patch:RefCounted=model.patches[i]
		if not patch.hole.water:continue
		var point:Vector3=model.to_course(Vector3(-48,0,-float(patch.hole.length)*.79),i)
		point.y=model.height(point.x,point.z)+.7
		var pond:=CylinderMesh.new();pond.top_radius=21;pond.bottom_radius=21;pond.height=.025;pond.radial_segments=64
		var instance:=mesh_node(pond,point,mat);instance.basis=model.layout.poses[i].basis;instance.scale.z=.61

func _shared_scenery()->void:
	var data:Dictionary=model.layout.data
	if model.surface!=null:_mapped_trees(data.get("trees",[]))
	for entry in ([] if model.surface!=null else data.get("trees",[])):
		var tree:=_leaf_tree(hole_markers.size());tree.name="GolfTree";add_child(tree)
		tree.position=Vector3(entry[0],surface_height(entry[0],entry[1]),entry[1])
		tree.scale=Vector3.ONE*(float(entry[2]) if entry.size()>2 else 1.0)
		# The visible canopy is an obstacle as well as the trunk.
		var body:=StaticBody3D.new();body.collision_layer=4;tree.add_child(body)
		var shape:=CollisionShape3D.new();var crown:=SphereShape3D.new();crown.radius=2.8;shape.shape=crown;shape.position.y=7.5;body.add_child(shape)
	for entry in data.get("rocks",[]):
		var rock=load("res://addons/golfminus/assets/models/schist.glb").instantiate();add_child(rock)
		rock.position=Vector3(entry[0],0,entry[1]);ground_prop(rock);_prop_collision(rock)
	var at:Array=data.get("clubhouse",[43,17])
	var pavilion=load("res://addons/golfminus/assets/models/pavilion.glb").instantiate();pavilion.name="Clubhouse";add_child(pavilion)
	pavilion.position=Vector3(at[0],0,at[1]);ground_pavilion(pavilion);_prop_collision(pavilion)
	var sign:=Label3D.new();sign.text="CLUBHOUSE";sign.font_size=64;sign.pixel_size=.008;sign.modulate=Color("ead4a4");pavilion.add_child(sign);sign.position=Vector3(0,2.65,3.63)

func _all_holes()->void:
	for i in model.course.holes.size():
		var pin:Vector3=model.pin_for(i)
		var marker:=Node3D.new();marker.name="Hole%02d"%(i+1);add_child(marker);hole_markers.append(marker)
		var pole:=CylinderMesh.new();pole.top_radius=.011;pole.bottom_radius=.012;pole.height=2.2
		mesh_node(pole,pin+Vector3.UP*1.1,material(Color("eadfc1")))
		var cloth:=PlaneMesh.new();cloth.size=Vector2(.55,.34)
		var flag_mesh:=mesh_node(cloth,pin+Vector3(.27,2.02,0),material(Color("dcaa61")));flag_mesh.rotation.x=PI/2
		var cup:=CylinderMesh.new();cup.top_radius=.054;cup.bottom_radius=.054;cup.height=.002
		mesh_node(cup,pin+Vector3(0,.004,0),material(Color("101d17")))
		var tee:Vector3=model.tee_for(i,tee_kind)
		for side in [-1,1]:
			var pos:Vector3=tee+model.layout.poses[i].basis.x*side*2
			pos.y=surface_height(pos.x,pos.z)+.07
			var box:=BoxMesh.new();box.size=Vector3(.18,.14,.18);mesh_node(box,pos,material(Color("d9c48d"),.4))
		var label:=Label3D.new();label.text="%02d"%(i+1);label.font_size=48;label.pixel_size=.015;label.position=tee+Vector3.UP*1.3;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;marker.add_child(label)

func _mapped_trees(entries:Array)->void:
	# Batch foliage by terrain tile for culling and VR draw-call cost; collision
	# volumes remain individual physical obstacles for shots on every hole.
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for angle in [0.0,PI/3,PI*2/3]:
		var basis:=Basis(Vector3.UP,angle)
		var corners:=[Vector3(-3.75,-.205,0),Vector3(3.75,-.205,0),Vector3(-3.75,11.045,0),Vector3(3.75,11.045,0)]
		var uv:=[Vector2(0,1),Vector2(1,1),Vector2(0,0),Vector2(1,0)]
		for i in [0,2,1,1,2,3]:st.set_normal(basis*Vector3.BACK);st.set_uv(uv[i]);st.add_vertex(basis*corners[i])
	var mesh:=st.commit()
	var mat:=ShaderMaterial.new();mat.shader=load("res://addons/golfminus/shaders/foliage.gdshader");mat.set_shader_parameter("foliage",load("res://addons/golfminus/assets/vegetation/river_alder.png"));mat.set_shader_parameter("exposure",.95)
	var groups:Dictionary={}
	for entry in entries:
		var at:=Vector3(entry[0],surface_height(entry[0],entry[1]),entry[1]);var size:float=entry[2]
		var key:=Vector2i(floori(at.x/96),floori(at.z/96))
		if not groups.has(key):groups[key]=[]
		groups[key].append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*size),at))
		var body:=StaticBody3D.new();body.name="GolfTree";body.collision_layer=5;body.position=at;add_child(body)
		var trunk:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=.3*size;capsule.height=5*size;trunk.shape=capsule;trunk.position.y=2.5*size;body.add_child(trunk)
		var crown:=CollisionShape3D.new();var sphere:=SphereShape3D.new();sphere.radius=2.8*size;crown.shape=sphere;crown.position.y=7.5*size;body.add_child(crown)
	for key in groups:
		var batch:=MultiMeshInstance3D.new();batch.name="CourseFoliage";batch.material_override=mat
		var multi:=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.mesh=mesh;multi.instance_count=groups[key].size()
		for i in groups[key].size():multi.set_instance_transform(i,groups[key][i])
		batch.multimesh=multi;add_child(batch)
		# Solid canopy caps remain readable from Godview where vertical tree cards
		# are edge-on. Shared sphere meshes add one draw per foliage tile.
		var caps:=MultiMeshInstance3D.new();caps.name="CanopyCaps"
		var sphere:=SphereMesh.new();sphere.radius=2.7;sphere.height=4.6;sphere.radial_segments=8;sphere.rings=4
		var crowns:=MultiMesh.new();crowns.transform_format=MultiMesh.TRANSFORM_3D;crowns.mesh=sphere;crowns.instance_count=groups[key].size()
		for i in groups[key].size():
			var pose:Transform3D=groups[key][i];pose.origin+=pose.basis*Vector3(0,7.7,0);crowns.set_instance_transform(i,pose)
		caps.multimesh=crowns;caps.material_override=material(Color("35533a"));add_child(caps)
