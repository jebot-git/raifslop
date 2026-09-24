extends Node3D
var model: RefCounted
var tee_kind:="club"
var flag: Node3D
var grid: MeshInstance3D
var occupied:Array[Rect2]=[]
var staging:=false
var staged_collisions:Array[Dictionary]=[]
func stage_collision(body:CollisionObject3D)->void:
	if not staging:return
	staged_collisions.append({"body":body,"layer":body.collision_layer,"mask":body.collision_mask})
	body.collision_layer=0;body.collision_mask=0
func activate_staged()->void:
	for entry in staged_collisions:
		if is_instance_valid(entry.body):entry.body.collision_layer=entry.layer;entry.body.collision_mask=entry.mask
	staged_collisions.clear();staging=false;visible=true;process_mode=Node.PROCESS_MODE_INHERIT
const COLORS := {"fairway":Color("557044"),"green":Color("66854c"),"fringe":Color("4d683a"),"rough":Color("72704b"),"sand":Color("d2c198"),"water":Color("aa9f77"),"out":Color("737354")}
func build(m: RefCounted) -> void:
	model=m
	_terrain();_water();_scenery();_flag();_green_grid()
func material(color: Color,metal:=0.0) -> StandardMaterial3D:
	var mat:=StandardMaterial3D.new();mat.albedo_color=color;mat.roughness=.8;mat.metallic=metal;return mat
func mesh_node(mesh: Mesh,pos: Vector3,mat: Material) -> MeshInstance3D:
	var n:=MeshInstance3D.new();n.mesh=mesh;n.position=pos;n.material_override=mat;add_child(n);return n
func _terrain() -> void:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step:=2.0
	var nx:=132
	var nz:=ceili((float(model.hole.length)+110)/step)
	for iz in nz+1:
		for ix in nx+1:
			var x: float=-132+ix*step
			var z: float=48-iz*step
			var p:=Vector3(x,model.height(x,z),z)
			var lie: String=model.lie(x,z)
			var c: Color=COLORS[lie]
			if model.course.kind=="alpine" and lie=="rough":c=Color("58633e")
			if lie=="fairway":c=c.lightened(.055 if int(floor(z/9))%2==0 else 0)
			c.a=0.0 if lie=="sand" else .20 if lie=="green" else .5 if lie=="fairway" else 1.0
			st.set_color(c.srgb_to_linear());st.set_normal(model.normal_at(x,z));st.set_uv(Vector2(x,z));st.set_uv2(Vector2(float(ix)/nx,float(iz)/nz));st.add_vertex(p)
	for z in nz:
		for x in nx:
			var a:=z*(nx+1)+x
			for idx in [a,a+nx+1,a+1,a+1,a+nx+1,a+nx+2]:st.add_index(idx)
	st.generate_tangents()
	var mat:=ShaderMaterial.new();mat.shader=load("res://addons/golfminus/shaders/terrain.gdshader")
	for pair in [["cover","river_bank.png"],["grass","grass.jpg"],["grass_normal","grass_normal.jpg"],["gravel","sand.jpg"],["gravel_normal","sand_normal.jpg"]]:mat.set_shader_parameter(pair[0],load("res://addons/golfminus/assets/shared/"+pair[1]))
	var prefix:="res://addons/golfminus/assets/textures/lighting/%s_%02d"%[model.course.id,model.index+1]
	if ResourceLoader.exists(prefix+"_irradiance.exr"):
		mat.set_shader_parameter("has_bake",true)
		mat.set_shader_parameter("irradiance",load(prefix+"_irradiance.exr"));mat.set_shader_parameter("sky_light",load(prefix+"_sky.exr"));mat.set_shader_parameter("bank_ao",load(prefix+"_ao.png"))
	var terrain:=mesh_node(st.commit(),Vector3.ZERO,mat)
	terrain.name="PlayableTerrain"
	terrain.create_trimesh_collision()
	terrain.get_child(0).set_meta("role","floor")
func _water() -> void:
	var mat:=ShaderMaterial.new();mat.shader=load("res://addons/golfminus/shaders/water.gdshader")
	mat.set_shader_parameter("panorama",load("res://addons/golfminus/assets/panoramas/%s_8k.hdr"%model.course.panorama))
	mat.set_shader_parameter("sky_energy",.65);mat.set_shader_parameter("blend_start",160.0);mat.set_shader_parameter("blend_end",700.0)
	mat.set_shader_parameter("deep_color",Color("27443e"));mat.set_shader_parameter("water_roughness",.3)
	var noise:=FastNoiseLite.new();noise.seed=731;noise.frequency=.045
	var normal:=NoiseTexture2D.new();normal.width=256;normal.height=256;normal.seamless=true;normal.as_normal_map=true;normal.bump_strength=2.0;normal.noise=noise
	mat.set_shader_parameter("ripple_normal",normal)
	mat.set_shader_parameter("river_bed",load("res://addons/golfminus/assets/shared/sand.jpg"));mat.set_shader_parameter("bank_cover",load("res://addons/golfminus/assets/shared/grass.jpg"))
	var plane:=PlaneMesh.new();plane.size=Vector2(3200,3200)
	mesh_node(plane,Vector3(-1650,-1.3,-220),mat).name="OceanBackdrop"
	if model.hole.water:
		var pond:=CylinderMesh.new();pond.top_radius=21;pond.bottom_radius=21;pond.height=.025;pond.radial_segments=64
		var pos:=Vector3(-48,model.pond_level(),-float(model.hole.length)*.79)
		var n:=mesh_node(pond,pos,mat);n.scale.z=.61
func _scenery() -> void:
	var rng:=RandomNumberGenerator.new();rng.seed=int(model.course.seed)+model.index
	if model.course.kind=="alpine":
		for i in 64:
			var x:=rng.randf_range(38,118);var z:=rng.randf_range(-float(model.hole.length)-40,25)
			if model.lie(x,z)!="rough" or absf(x-model.center_x(-z/float(model.hole.length)))<35:continue
			if absf(x-43)<7 and absf(z-17)<4:continue
			var tree=_leaf_tree(i);tree.name="GolfTree%d"%i
			add_child(tree);tree.position=Vector3(x,surface_height(x,z),z);tree.rotation.y=rng.randf_range(0,TAU);tree.scale=Vector3.ONE*rng.randf_range(.7,1.25)
	for i in 15:
		var x:=rng.randf_range(-82,-72);var z:=rng.randf_range(-float(model.hole.length),30)
		if model.lie(x,z)=="water":continue
		var rock=load("res://addons/golfminus/assets/models/schist.glb").instantiate();add_child(rock)
		rock.position=Vector3(x,0,z);rock.rotation.y=rng.randf_range(0,TAU)
		ground_prop(rock);_reserve_footprint(rock);_prop_collision(rock)
	var pavilion=load("res://addons/golfminus/assets/models/pavilion.glb").instantiate();pavilion.name="Clubhouse";add_child(pavilion)
	pavilion.position=Vector3(43,0,17);ground_pavilion(pavilion);_reserve_footprint(pavilion);_prop_collision(pavilion)
	var sign:=Label3D.new();sign.text="CLUBHOUSE";sign.font_size=64;sign.pixel_size=.008;sign.modulate=Color("ead4a4");pavilion.add_child(sign);sign.position=Vector3(0,2.65,3.63)
	_grass(rng)
	for side in [-1,1]:
		var tee: Vector3=model.tee(tee_kind)+Vector3(side*2,0,0)
		var box:=BoxMesh.new();box.size=Vector3(.18,.14,.18)
		tee.y=model.height(tee.x,tee.z)+.07
		mesh_node(box,tee,material(Color("d9c48d"),.4))
func _leaf_tree(variant: int) -> Node3D:
	var tree:=Node3D.new()
	var mat:=ShaderMaterial.new();mat.shader=load("res://addons/golfminus/shaders/foliage.gdshader");mat.set_shader_parameter("foliage",load("res://addons/golfminus/assets/vegetation/river_alder.png"))
	mat.set_shader_parameter("exposure",.85+variant%3*.08)
	for angle in [0.0,PI/3,PI*2/3]:
		var n:=MeshInstance3D.new();var q:=QuadMesh.new();q.size=Vector2(7.5,11.25);n.mesh=q;n.position.y=5.42;n.rotation.y=angle;n.material_override=mat
		tree.add_child(n)
	var trunk:=StaticBody3D.new();trunk.collision_layer=5;tree.add_child(trunk)
	var shape:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=.3;capsule.height=5.6;shape.shape=capsule;shape.position.y=2.2;trunk.add_child(shape)
	return tree
func _prop_collision(prop: Node3D) -> void:
	for mesh in prop.find_children("*","MeshInstance3D",true,false):
		prop_mesh_collision(mesh)
func prop_mesh_collision(mesh:MeshInstance3D)->void:
	if str(mesh.name).begins_with("Visual_"):return
	mesh.create_trimesh_collision()
	for child in mesh.get_children():
		if child is StaticBody3D:child.collision_layer=5;stage_collision(child)
var ball_shape:SphereShape3D
func sweep_ball(from:Vector3,to:Vector3)->Dictionary:
	if not from.is_finite() or not to.is_finite():return {}
	if ball_shape==null:
		ball_shape=SphereShape3D.new();ball_shape.radius=preload("res://addons/golfminus/scripts/golf/ball_physics.gd").RADIUS
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=ball_shape;query.collision_mask=4;query.margin=.0001
	query.transform=Transform3D(Basis.IDENTITY,from)
	var space:=get_world_3d().direct_space_state
	# cast_motion ignores initial overlap. Resolve it first using penetration
	# witnesses, including deeply embedded saves and stationary starts.
	var centre:=from
	var normal:=Vector3.ZERO
	for iteration in 8:
		query.transform.origin=centre
		var correction:=Vector3.ZERO
		for overlap in space.intersect_shape(query,16):
			var body:CollisionObject3D=overlap.collider
			var owner:int=body.shape_find_owner(overlap.shape)
			var node=body.shape_owner_get_owner(owner)
			if not node is CollisionShape3D or not node.shape is CapsuleShape3D:continue
			# EPA is ambiguous exactly on a long capsule's centre axis and can
			# choose an end cap metres away. Use its nearest surface analytically.
			var capsule:CapsuleShape3D=node.shape
			var scale:Vector3=node.global_basis.get_scale()
			var half:float=maxf(0,capsule.height*.5-capsule.radius)*scale.y
			var up:Vector3=node.global_basis.y.normalized()
			var closest:=Geometry3D.get_closest_point_to_segment(centre,node.global_position-up*half,node.global_position+up*half)
			var offset:=centre-closest
			var radius:float=capsule.radius*maxf(scale.x,scale.z)+ball_shape.radius
			if offset.length()>=radius:continue
			var direction:=offset.normalized()
			if offset.length()<.00001:
				direction=Vector3(from.x-to.x,0,from.z-to.z).normalized()
				if direction.length_squared()<.5:direction=Vector3.RIGHT
			var separation:=direction*(radius-offset.length())
			if separation.length_squared()>correction.length_squared():correction=separation
		if correction.length_squared()<.0000000001:
			var pairs:=space.collide_shape(query,16)
			for i in range(0,pairs.size(),2):
				var separation:Vector3=pairs[i+1]-pairs[i]
				if separation.length_squared()>correction.length_squared():correction=separation
		if correction.length_squared()<.0000000001:break
		normal=correction.normalized();centre+=correction+normal*.001
	if normal.length_squared()>.5:
		return {"center":centre,"position":centre-normal*ball_shape.radius,"normal":normal,"initial_overlap":true}
	query.transform.origin=from;query.motion=to-from
	if query.motion.length_squared()<.0000000001:return {}
	var fractions:=space.cast_motion(query)
	if fractions.size()<2 or fractions[0]>=1:return {}
	centre=from+query.motion*fractions[0]
	query.transform.origin=from+query.motion*fractions[1]
	query.motion=Vector3.ZERO
	var rest:=space.get_rest_info(query)
	if rest.is_empty():
		# Narrowphase tolerance can leave the unsafe pose exactly touching.
		query.margin=.001;rest=space.get_rest_info(query)
	if rest.is_empty():return {}
	normal=rest.normal
	return {"center":centre+normal*.001,"position":rest.point,"normal":normal,"initial_overlap":false}

func _grass(rng: RandomNumberGenerator) -> void:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for angle in [0.0,PI/2]:
		for p in [Vector3(-.035,0,0),Vector3(.035,0,0),Vector3(.012,.20,0)]:
			st.set_uv(Vector2(0,1 if p.y>0 else 0));st.set_normal(Vector3.UP);st.add_vertex(p.rotated(Vector3.UP,angle))
	var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=st.commit();mm.instance_count=15000
	var n:=MultiMeshInstance3D.new();n.multimesh=mm
	var mat:=ShaderMaterial.new();mat.shader=load("res://addons/golfminus/shaders/grass.gdshader");n.material_override=mat
	n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(n)
	var accepted:=0
	for i in 22000:
		if accepted>=mm.instance_count:break
		var x:=rng.randf_range(-81,122);var z:=rng.randf_range(-float(model.hole.length)-35,40)
		if model.lie(x,z)!="rough" or _occupied(x,z):continue
		var scale_factor:=rng.randf_range(.5,1.4)
		mm.set_instance_transform(accepted,Transform3D(Basis(Vector3.UP,rng.randf_range(0,TAU)).scaled(Vector3.ONE*scale_factor),Vector3(x,surface_height(x,z)-.025,z)))
		accepted+=1
	mm.visible_instance_count=accepted
	var tuft_mat:=ShaderMaterial.new();tuft_mat.shader=load("res://addons/golfminus/shaders/foliage.gdshader");tuft_mat.set_shader_parameter("foliage",load("res://addons/golfminus/assets/vegetation/coastal_dune_grass.png"));tuft_mat.set_shader_parameter("exposure",.8)
	# Last opaque grass row is 975 / 1254: centre must sit .416 m above roots, not .75.
	var tuft_mesh:=QuadMesh.new();tuft_mesh.size=Vector2(1.5,1.5)
	var tufts:=MultiMesh.new();tufts.transform_format=MultiMesh.TRANSFORM_3D;tufts.mesh=tuft_mesh;tufts.instance_count=600
	var instance:=MultiMeshInstance3D.new();instance.multimesh=tufts;instance.material_override=tuft_mat;instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(instance)
	var count:=0
	for i in 1600:
		if count>=600:break
		var x:=rng.randf_range(-80,95);var z:=rng.randf_range(-float(model.hole.length)-25,20)
		if model.lie(x,z)!="rough" or _occupied(x,z):continue
		tufts.set_instance_transform(count,Transform3D(Basis(Vector3.UP,rng.randf_range(0,TAU)),Vector3(x,surface_height(x,z)+.375,z)));count+=1
	tufts.visible_instance_count=count
func _flag() -> void:
	var pin: Vector3=model.pin();flag=Node3D.new();add_child(flag);flag.position=pin
	var pole:=CylinderMesh.new();pole.top_radius=.011;pole.bottom_radius=.012;pole.height=2.2
	var n:=mesh_node(pole,pin+Vector3(0,1.1,0),material(Color("eadfc1")))
	n.name="Flagstick"
	var cloth:=PlaneMesh.new();cloth.size=Vector2(.55,.34)
	n=mesh_node(cloth,pin+Vector3(.27,2.02,0),material(Color("dcaa61")));n.rotation.x=PI/2
	var cup:=CylinderMesh.new();cup.top_radius=.054;cup.bottom_radius=.054;cup.height=.002
	mesh_node(cup,pin+Vector3(0,.004,0),material(Color("101d17")))
func _green_grid() -> void:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_LINES)
	var pin: Vector3=model.pin()
	for x in range(-12,13,2):
		for z in range(-12,12):
			for p in [Vector3(x,0,z),Vector3(x,0,z+1),Vector3(z,0,x),Vector3(z+1,0,x)]:
				p+=pin;p.y=model.height(p.x,p.z)+.035;st.add_vertex(p)
	var mat:=material(Color("90bbaa"));mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	grid=mesh_node(st.commit(),Vector3.ZERO,mat);grid.visible=false

# Match the triangles actually rendered/collided, including sharp shore/bunker edges.
func surface_height(x: float,z: float) -> float:
	var x0:=floorf((x+132.0)/2.0)*2.0-132.0
	var z0:=48.0-floorf((48.0-z)/2.0)*2.0
	var u:=(x-x0)/2.0
	var v:=(z0-z)/2.0
	var a:float=model.height(x0,z0)
	var b:float=model.height(x0+2,z0)
	var c:float=model.height(x0,z0-2)
	var d:float=model.height(x0+2,z0-2)
	return a+(b-a)*u+(c-a)*v if u+v<=1 else d+(c-d)*(1-u)+(b-d)*(1-v)

func ground_prop(prop: Node3D) -> void:
	# Seat each component's underside into the slope; imported origins are not feet.
	# Taking the lowest support keeps every rock and foundation corner grounded.
	var support:=INF
	for mesh in prop.find_children("*","MeshInstance3D",true,false):
		var bounds:AABB=mesh.get_aabb()
		var relative:Transform3D=global_transform.affine_inverse()*mesh.global_transform
		for corner in [Vector3(0,0,0),Vector3(1,0,0),Vector3(0,0,1),Vector3(1,0,1)]:
			var foot:Vector3=relative*(bounds.position+bounds.size*corner)
			# Only low parts support the prop (not benches, roof or tree canopy).
			if foot.y-prop.position.y>.3:continue
			support=minf(support,surface_height(foot.x,foot.z)-foot.y)
	if is_finite(support):prop.position.y+=support-.04

func _reserve_footprint(prop:Node3D)->void:
	var bounds:=AABB()
	var first:=true
	for mesh in prop.find_children("*","MeshInstance3D",true,false):
		var local:Transform3D=global_transform.affine_inverse()*mesh.global_transform
		var box:AABB=local*mesh.get_aabb()
		bounds=box if first else bounds.merge(box);first=false
	occupied.append(Rect2(Vector2(bounds.position.x,bounds.position.z),Vector2(bounds.size.x,bounds.size.z)).grow(.15))
func _occupied(x:float,z:float)->bool:
	for footprint in occupied:
		if footprint.has_point(Vector2(x,z)):return true
	return false
func ground_pavilion(prop:Node3D)->void:
	# Keep the deck level and above the highest ground; a stone skirt closes the
	# downhill gap instead of burying the deck or leaving unsupported corners.
	var foundation:MeshInstance3D=prop.find_child("Pavilion foundation*",true,false)
	if foundation==null:ground_prop(prop);return
	var bounds:AABB=(global_transform.affine_inverse()*foundation.global_transform)*foundation.get_aabb()
	var rim:Array[Vector3]=[]
	var corners:=[bounds.position,Vector3(bounds.end.x,bounds.position.y,bounds.position.z),Vector3(bounds.end.x,bounds.position.y,bounds.end.z),Vector3(bounds.position.x,bounds.position.y,bounds.end.z)]
	var highest:=-INF
	for side in 4:
		for i in 16:
			var point:Vector3=corners[side].lerp(corners[(side+1)%4],float(i)/16)
			point.y=surface_height(point.x,point.z)-.04
			highest=maxf(highest,point.y+.04);rim.append(point)
	prop.position.y+=highest-bounds.position.y+.015
	var top:=highest+.03
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in rim.size():
		var a:Vector3=rim[i];var b:Vector3=rim[(i+1)%rim.size()]
		for point in [a,b,Vector3(a.x,top,a.z),b,Vector3(b.x,top,b.z),Vector3(a.x,top,a.z)]:
			var along:float=point.x if absf(b.x-a.x)>absf(b.z-a.z) else point.z
			st.set_uv(Vector2(along,point.y)*.45);st.add_vertex(point)
	st.generate_normals()
	st.generate_tangents()
	var stone:=material(Color("777464"))
	if foundation.get_active_material(0) is StandardMaterial3D:stone=foundation.get_active_material(0).duplicate()
	stone.cull_mode=BaseMaterial3D.CULL_DISABLED
	var skirt:=mesh_node(st.commit(),Vector3.ZERO,stone);skirt.name="PavilionGroundSupport";skirt.create_trimesh_collision();skirt.get_child(0).collision_layer=5
	stage_collision(skirt.get_child(0))
