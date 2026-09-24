extends RefCounted
## The visible head and contact surface share the same rounded triangle mesh.
const BALL_RADIUS:=.021335
const TRACKING_TOLERANCE:=.002
const FACE_TRIANGLES:=224
var triangles:=PackedVector3Array()
var surface_points:=PackedVector3Array()
var mesh:ArrayMesh
var tree:Array[Dictionary]=[]
var bounds:Array[AABB]=[]
var radius:=0.0
var mass:=.2
var inertia:=Vector3.ONE
var restitution:=.8
var friction:=.35
var depth:=.09
var loft:=0.0
var face_center:=Vector3.ZERO
static var cache:Dictionary={}
static func for_club(index:int)->RefCounted:
	if not cache.has(index):
		var shape=load("res://addons/golfminus/scripts/golf/club_head.gd").new();shape._build(index);cache[index]=shape
	return cache[index]
func _build(index:int)->void:
	var width:float=.122 if index<2 else .106
	var height:float=.058 if index<2 else .045 if index<7 else .028
	depth=.096 if index<2 else .026 if index<7 else .047
	mass=[.200,.215,.255,.270,.285,.300,.305,.350][index]
	restitution=[.82,.80,.78,.76,.74,.72,.70,.75][index]
	friction=.30 if index<2 else .42 if index<7 else .32
	loft=deg_to_rad([11.0,15.0,27.0,34.0,42.0,47.0,56.0,2.0][index])
	# Diagonal engineering approximation, kg m²; driver shell mass is perimeter weighted.
	var inertia_factor:=.18 if index<2 else 1.0/12.0
	inertia=Vector3(height*height+depth*depth,width*width+depth*depth,width*width+height*height)*mass*inertia_factor
	face_center=Vector3(0,0,-depth*.5)
	var rings:Array[PackedVector3Array]=[]
	var segments:=32
	# Front rings resolve driver bulge/roll; irons/putter have a flat striking face.
	for fraction in [.25,.5,.75,1.0]:
		var ring:=PackedVector3Array()
		for i in segments:
			var angle:=TAU*i/segments
			var exponent:float=1.0 if index<2 else .35
			var x:float=signf(cos(angle))*pow(absf(cos(angle)),exponent)*width*.5*fraction
			var y:float=signf(sin(angle))*pow(absf(sin(angle)),exponent)*height*.5*fraction
			# Rounded, slightly toe-high iron profile, not a cuboid proxy.
			if index>=2 and index<7:y*=.92+.08*x/(width*.5)
			var z:float=-depth*.5+(x*x/(2*.30)+y*y/(2*.32) if index<2 else 0.0)
			ring.append(Vector3(x,y,z))
		rings.append(ring)
	for i in segments:_triangle(face_center,rings[0][(i+1)%segments],rings[0][i])
	for ring_index in range(1,rings.size()):_join(rings[ring_index-1],rings[ring_index])
	var front:PackedVector3Array=rings[-1]
	for profile in [Vector2(1.04,-.20),Vector2(.95,.25),Vector2(.66,.48),Vector2(.25,.5)]:
		var ring:=PackedVector3Array()
		for vertex in front:ring.append(Vector3(vertex.x*profile.x,vertex.y*profile.x,depth*profile.y))
		_join(rings[-1],ring);rings.append(ring)
	for i in segments:_triangle(Vector3(0,0,depth*.5),rings[-1][i],rings[-1][(i+1)%segments])
	var normal_sums:Dictionary={}
	for i in range(0,triangles.size(),3):
		var area_normal:Vector3=(triangles[i+1]-triangles[i]).cross(triangles[i+2]-triangles[i])
		for point in [triangles[i],triangles[i+1],triangles[i+2]]:
			var key:=Vector4(point.x,point.y,point.z,0 if i<224*3 else 1)
			normal_sums[key]=normal_sums.get(key,Vector3.ZERO)+area_normal
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0,triangles.size(),3):
		var a:=triangles[i];var b:=triangles[i+1];var c:=triangles[i+2]
		var is_face:=i<224*3
		surface.set_color(Color(1 if is_face else 0,0,0,1))
		for point in [a,c,b]:
			var key:=Vector4(point.x,point.y,point.z,0 if is_face else 1)
			surface.set_normal(normal_sums[key].normalized())
			surface.set_uv(Vector2(point.x/width+.5,(point.y/height if is_face else point.z/depth)+.5))
			surface.add_vertex(point);radius=maxf(radius,point.length())
		bounds.append(AABB(a,Vector3.ZERO).expand(b).expand(c))
	mesh=surface.commit()
	var unique:Dictionary={}
	for point in triangles:unique[point]=true
	for point in unique:surface_points.append(point)
	var ids:Array[int]=[]
	for i in bounds.size():ids.append(i)
	_build_branch(ids)
func _triangle(a:Vector3,b:Vector3,c:Vector3)->void:
	# Store outward geometric winding; rendering reverses it for Godot front faces.
	triangles.append(a);triangles.append(b);triangles.append(c)
func _join(a:PackedVector3Array,b:PackedVector3Array)->void:
	for i in a.size():
		var j:=(i+1)%a.size()
		_triangle(a[i],a[j],b[i]);_triangle(a[j],b[j],b[i])
func install(club:Node3D,index:int)->MeshInstance3D:
	for child in club.find_children("*","MeshInstance3D",true,false):
		var key:String=child.name.to_lower()
		if "head" in key or "face" in key or "inlay" in key:
			child.get_parent().remove_child(child);child.queue_free()
	var visual:=MeshInstance3D.new();visual.name="PhysicalClubHead";visual.mesh=mesh
	var material:=ShaderMaterial.new();material.shader=preload("res://addons/golfminus/shaders/club_finish.gdshader")
	material.set_shader_parameter("club_kind",0 if index<2 else 2 if index==7 else 1)
	material.set_shader_parameter("head_depth",depth)
	material.set_shader_parameter("carbon",load("res://addons/golfminus/assets/textures/equipment/carbon_albedo.png"))
	material.set_shader_parameter("brushed_rough",load("res://addons/golfminus/assets/textures/equipment/brushed_roughness.png"))
	visual.material_override=material;club.add_child(visual)
	return visual
static func closest_triangle(p:Vector3,a:Vector3,b:Vector3,c:Vector3)->Vector3:
	var ab:=b-a;var ac:=c-a;var ap:=p-a
	var d1:=ab.dot(ap);var d2:=ac.dot(ap)
	if d1<=0 and d2<=0:return a
	var bp:=p-b;var d3:=ab.dot(bp);var d4:=ac.dot(bp)
	if d3>=0 and d4<=d3:return b
	var vc:=d1*d4-d3*d2
	if vc<=0 and d1>=0 and d3<=0:return a+ab*d1/(d1-d3)
	var cp:=p-c;var d5:=ab.dot(cp);var d6:=ac.dot(cp)
	if d6>=0 and d5<=d6:return c
	var vb:=d5*d2-d1*d6
	if vb<=0 and d2>=0 and d6<=0:return a+ac*d2/(d2-d6)
	var va:=d3*d6-d5*d4
	if va<=0 and d4-d3>=0 and d5-d6>=0:return b+(c-b)*(d4-d3)/((d4-d3)+(d5-d6))
	var inverse:=1.0/(va+vb+vc)
	return a+ab*(vb*inverse)+ac*(vc*inverse)
func nearest(point:Vector3)->Dictionary:
	var best:=INF;var closest:=Vector3.ZERO;var triangle:=0
	var pending:Array[int]=[0]
	while not pending.is_empty():
		var branch:Dictionary=tree[pending.pop_back()]
		var box:AABB=branch.bounds
		if point.distance_squared_to(point.clamp(box.position,box.end))>best:continue
		if branch.has("left"):
			var left_box:AABB=tree[branch.left].bounds
			var right_box:AABB=tree[branch.right].bounds
			var left_distance:=point.distance_squared_to(point.clamp(left_box.position,left_box.end))
			var right_distance:=point.distance_squared_to(point.clamp(right_box.position,right_box.end))
			pending.append(branch.right if left_distance<right_distance else branch.left)
			pending.append(branch.left if left_distance<right_distance else branch.right)
			continue
		for id in branch.ids:
			var i:int=id*3
			var candidate:=closest_triangle(point,triangles[i],triangles[i+1],triangles[i+2])
			var distance:=candidate.distance_squared_to(point)
			if distance<best:best=distance;closest=candidate;triangle=id
	var offset:=triangle*3
	var outward:Vector3=(triangles[offset+1]-triangles[offset]).cross(triangles[offset+2]-triangles[offset]).normalized()
	return {"point":closest,"distance":sqrt(best),"triangle":triangle,"inside":(point-closest).dot(outward)<-.000001,"outward":outward}
func sweep(from:Transform3D,to:Transform3D,ball:Vector3,ball_motion:=Vector3.ZERO)->Dictionary:
	return _sweep(from,to,ball,ball_motion,0.0)
func sweep_tracked(from:Transform3D,to:Transform3D,ball:Vector3,ball_motion:=Vector3.ZERO,tolerance:=TRACKING_TOLERANCE)->Dictionary:
	# Exact whole-head contact always wins. The fallback never changes the mesh,
	# ball radius, surface point or lever arm used by the impulse solver.
	var hit:=sweep(from,to,ball,ball_motion)
	if not hit.is_empty():
		hit.merge({"contact_policy":"exact","tracking_correction_m":0.0,"tracking_tolerance_m":clampf(tolerance,0,TRACKING_TOLERANCE)})
		return hit
	if not is_finite(tolerance) or tolerance<=0:return {}
	hit=_sweep(from,to,ball,ball_motion,minf(tolerance,TRACKING_TOLERANCE))
	if hit.is_empty() or int(hit.get("triangle",FACE_TRIANGLES))>=FACE_TRIANGLES:return {}
	# Only a closing approach to the front face is eligible; the tracker also
	# checks actual point velocity, tracking continuity and control state.
	var face:Vector3=hit.head_basis*Vector3.FORWARD
	if face.dot(hit.normal)<=.65:return {}
	hit.merge({"contact_policy":"tracking_tolerance","tracking_correction_m":maxf(0,float(hit.contact_distance_m)-BALL_RADIUS),"tracking_tolerance_m":minf(tolerance,TRACKING_TOLERANCE)})
	return hit
func _sweep(from:Transform3D,to:Transform3D,ball:Vector3,ball_motion:Vector3,tolerance:float)->Dictionary:
	var travel:=(to.origin-from.origin)-ball_motion
	var angle:=from.basis.get_rotation_quaternion().angle_to(to.basis.get_rotation_quaternion())
	var bound:=travel.length()+angle*radius
	if Geometry3D.get_closest_point_to_segment(ball,from.origin,to.origin-ball_motion).distance_to(ball)>radius+BALL_RADIUS+tolerance:return {}
	if bound<.000001:return {}
	var fraction:=0.0
	# Conservative advancement: distance is Lipschitz bounded by linear + angular travel.
	for iteration in 96:
		var pose:=from.interpolate_with(to,fraction)
		var centre:=ball+ball_motion*fraction
		var near:=nearest(pose.affine_inverse()*centre)
		var separation:float=near.distance-BALL_RADIUS
		if near.inside or separation<=(.00001 if tolerance==0 else tolerance):
			var point:Vector3=pose*near.point
			var normal:Vector3=pose.basis*near.outward if near.inside or near.distance<.000001 else (centre-point).normalized()
			if normal.length_squared()<.9:return {"initial_overlap":true}
			return {"contact":point,"contact_local":near.point,"normal":normal,"head_pose":pose,"head_basis":pose.basis,"head_center":pose.origin,"ball_center":centre,"fraction":fraction,"contact_distance_m":near.distance,"penetration_m":BALL_RADIUS+near.distance if near.inside else maxf(0,-separation),"triangle":near.triangle}
		fraction+=maxf((separation-tolerance)/bound*.90,.000001)
		if fraction>1.0:return {}
	return {}

func _build_branch(ids:Array[int])->int:
	var index:=tree.size()
	var box:AABB=bounds[ids[0]]
	for id in ids:box=box.merge(bounds[id])
	tree.append({"bounds":box})
	if ids.size()<=8:
		tree[index].ids=ids;return index
	var axis:=box.size.max_axis_index()
	ids.sort_custom(func(a:int,b:int):return bounds[a].get_center()[axis]<bounds[b].get_center()[axis])
	var half:int=ids.size()/2
	tree[index].left=_build_branch(ids.slice(0,half))
	tree[index].right=_build_branch(ids.slice(half))
	return index
