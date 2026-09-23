extends RefCounted
## Course coordinates are metres: +X east, -Z north. Never depend on active hole.
var data:Dictionary={}
var poses:Array[Transform3D]=[]
var inverses:Array[Transform3D]=[]
var bounds:=Rect2()

func configure(course:Dictionary)->void:
	data=course.get("layout",{})
	poses.clear();inverses.clear()
	for hole in course.holes:
		var route:Dictionary=hole.get("routing",{})
		var at:Array=route.get("origin",[0,0])
		var pose:=Transform3D(Basis(Vector3.UP,deg_to_rad(float(route.get("yaw",0)))),Vector3(at[0],0,at[1]))
		poses.append(pose);inverses.append(pose.affine_inverse())
	var box:Array=data.get("bounds",[-132,-600,264,648])
	bounds=Rect2(box[0],box[1],box[2],box[3])

func to_world(point:Vector3,hole:int)->Vector3:return poses[hole]*point
func to_hole(point:Vector3,hole:int)->Vector3:return inverses[hole]*point
func hole_bounds(course:Dictionary,hole:int,margin:=40.0)->Rect2:
	if course.holes[hole].routing.has("path"):
		var routing:Dictionary=course.holes[hole].routing
		var route:Array=routing.get("play_path",routing.path)
		var box:=Rect2(Vector2(route[0][0],route[0][1]),Vector2.ZERO)
		for p in route:box=box.expand(Vector2(p[0],p[1]))
		for branch in routing.get("tee_paths",{}).values():
			for p in branch:box=box.expand(Vector2(p[0],p[1]))
		return box.grow(margin)
	var length:float=course.holes[hole].length
	var result:=Rect2()
	var first:=true
	var half_width:=90.0+absf(float(course.holes[hole].bend))
	for x in [-half_width,half_width]:
		for z in [margin,-length-margin]:
			var point:=to_world(Vector3(x,0,z),hole)
			var p:=Vector2(point.x,point.z)
			if first:result=Rect2(p,Vector2.ZERO);first=false
			else:result=result.expand(p)
	return result

func background_height(x:float,z:float)->float:
	var slope:Array=data.get("slope",[0,0])
	return 4.0+x*float(slope[0])+z*float(slope[1])+sin(x*.008)*1.1+sin(z*.01)*.6

func hazard_distance(hazard:Dictionary,point:Vector2)->float:
	var vertices:PackedVector2Array=[]
	for p in hazard.get("points",[]):vertices.append(Vector2(p[0],p[1]))
	if vertices.is_empty():return INF
	var nearest:=point.distance_to(vertices[0])
	for i in range(1,vertices.size()):
		nearest=minf(nearest,point.distance_to(Geometry2D.get_closest_point_to_segment(point,vertices[i-1],vertices[i])))
	return nearest

func hazard_at(point:Vector2)->Dictionary:
	for hazard in data.get("hazards",[]):
		if hazard_distance(hazard,point)<float(hazard.width):return hazard
	return {}

func carve_height(x:float,z:float,height:float)->float:
	var point:=Vector2(x,z)
	for hazard in data.get("hazards",[]):
		var d:=hazard_distance(hazard,point)
		var radius:=float(hazard.width)
		var bank:=float(hazard.get("bank",4.0))
		if d>=radius+bank:continue
		var bottom:float=float(hazard.level)-float(hazard.get("depth",1.5)) if hazard.kind=="water" else background_height(x,z)-float(hazard.get("depth",2.0))
		height=lerpf(minf(height,bottom),height,smoothstep(radius*.65,radius+bank,d))
	return height
