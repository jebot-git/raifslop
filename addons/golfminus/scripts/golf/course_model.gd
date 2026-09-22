extends RefCounted
## Single source of truth for terrain, rendered lies and ball contact.
var course: Dictionary
var hole: Dictionary
var index := 0
var surface:RefCounted
var layout:RefCounted
var patches:Array=[]
var buckets:Dictionary={}
var shared_patch:=false
var connected:bool:
	get:return layout!=null
func configure(data:Dictionary,hole_index:=0)->void:
	course=data
	index=clampi(hole_index,0,course.holes.size()-1);hole=course.holes[index]
	layout=null;surface=null;patches.clear();buckets.clear()
	if not course.has("layout"):return
	layout=preload("res://addons/golfminus/scripts/golf/course_layout.gd").new();layout.configure(course)
	if course.layout.has("surface"):
		surface=preload("res://addons/golfminus/scripts/golf/course_surface.gd").new();surface.configure(course)
	for i in course.holes.size():
		var patch=get_script().new();patch.course=course;patch.index=i;patch.hole=course.holes[i];patch.shared_patch=true
		patches.append(patch)
		var box:Rect2=layout.hole_bounds(course,i,60)
		for x in range(floori(box.position.x/128),floori(box.end.x/128)+1):
			for z in range(floori(box.position.y/128),floori(box.end.y/128)+1):
				var key:=Vector2i(x,z)
				if not buckets.has(key):buckets[key]=[]
				buckets[key].append(i)
func course_bounds()->Rect2:
	return layout.bounds if connected else Rect2(-132,-float(hole.length)-62,264,float(hole.length)+110)
func map_bounds()->Rect2:
	return layout.hole_bounds(course,index) if connected else Rect2(-125,-float(hole.length)-35,250,float(hole.length)+65)
func to_course(point:Vector3,hole_index:=-1)->Vector3:
	return layout.to_world(point,index if hole_index<0 else hole_index) if connected else point
func to_hole(point:Vector3,hole_index:=-1)->Vector3:
	return layout.to_hole(point,index if hole_index<0 else hole_index) if connected else point
func pin_for(hole_index:int)->Vector3:
	if not connected:return pin()
	if surface!=null:
		var at:Array=course.holes[hole_index].routing.pin
		return Vector3(at[0],height(at[0],at[1]),at[1])
	var p:Vector3=layout.to_world(patches[hole_index].pin(),hole_index)
	p.y=height(p.x,p.z);return p
func tee_for(hole_index:int,kind:="club")->Vector3:
	if not connected:return tee(kind)
	if surface!=null:
		var at:Array=course.holes[hole_index].routing.tees[kind]
		return Vector3(at[0],height(at[0],at[1])+.021335,at[1])
	var p:Vector3=layout.to_world(patches[hole_index].tee(kind),hole_index)
	p.y=height(p.x,p.z)+.021335;return p
func candidates(x:float,z:float)->Array:
	return buckets.get(Vector2i(floori(x/128),floori(z/128)),[])
func _world_lie(x:float,z:float)->String:
	if not layout.bounds.has_point(Vector2(x,z)):return "out"
	var hazard:Dictionary=layout.hazard_at(Vector2(x,z))
	if not hazard.is_empty():return "water" if hazard.kind=="water" else "rough"
	var result:="rough"
	var priority:={"out":0,"rough":0,"fairway":1,"fringe":2,"green":3,"sand":4,"water":5}
	for i in candidates(x,z):
		var p:Vector3=layout.to_hole(Vector3(x,0,z),i)
		var surface:String=patches[i].lie(p.x,p.z)
		if priority[surface]>priority[result]:result=surface
	return result
func _world_height(x:float,z:float)->float:
	var base:float=layout.background_height(x,z)
	var delta:=0.0;var weight_sum:=0.0
	for i in candidates(x,z):
		var p:Vector3=layout.to_hole(Vector3(x,0,z),i)
		var patch:RefCounted=patches[i]
		var longitudinal:float=maxf(p.z,-float(patch.hole.length)-p.z)
		var lateral:float=absf(p.x-patch.center_x(-p.z/float(patch.hole.length)))
		var weight:float=(1-smoothstep(55,90,lateral))*(1-smoothstep(25,60,longitudinal))
		if weight<=0:continue
		var offset:Vector3=layout.poses[i].origin
		delta+=(patch.height(p.x,p.z)-4.0+layout.background_height(offset.x,offset.z)-base)*weight
		weight_sum+=weight
	return layout.carve_height(x,z,base+delta/maxf(1.0,weight_sum))
func load_course(id: String, hole_index := 0) -> void:
	if not course.is_empty() and course.id==id:
		index=clampi(hole_index,0,course.holes.size()-1);hole=course.holes[index];return
	configure(JSON.parse_string(FileAccess.get_file_as_string("res://addons/golfminus/courses/%s.json" % id)),hole_index)
func center_x(t: float) -> float:
	return float(hole.bend) * sin(clampf(t, 0, 1) * PI * .78)
func pin() -> Vector3:
	if connected:return pin_for(index)
	var p := Vector3(center_x(1), 0, -float(hole.length))
	p.y = height(p.x,p.z)
	return p
func tee(kind := "club") -> Vector3:
	if connected:return tee_for(index,kind)
	var d: float = hole.tee_options.get(kind,0)
	return Vector3(center_x(d / float(hole.length)),height(center_x(d / float(hole.length)),-d)+.021335,-d)
func green_distance(x: float,z: float) -> float:
	return Vector2((x-center_x(1))/.92, z+float(hole.length)).length()
func bunker_center(b: Dictionary) -> Vector2:
	return Vector2(center_x(b.t)+b.side*(float(hole.width)*.8 if b.t<.8 else float(hole.green_radius)*1.04),-float(hole.length)*b.t)
func lie(x: float,z: float) -> String:
	if surface!=null:return surface.lie(x,z)
	if connected:return _world_lie(x,z)
	if absf(x)>125 or z>45 or z < -float(hole.length)-60: return "out"
	if not shared_patch and x < -86.0 + sin(z*.022)*6.0: return "water"
	if hole.water and Vector2(x+48, (z+float(hole.length)*.79)*1.65).length()<21: return "water"
	for b in hole.bunkers:
		var center := bunker_center(b)
		if Vector2(x-center.x,(z-center.y)*1.25).length() < float(b.radius): return "sand"
	if green_distance(x,z)<float(hole.green_radius): return "green"
	if green_distance(x,z)<float(hole.green_radius)+3: return "fringe"
	var t := -z/float(hole.length)
	if t >= -.02 and t < .95 and absf(x-center_x(t)) < float(hole.width)*(0.76+.18*sin(t*PI*3)):
		return "fairway"
	return "rough"
func pond_level() -> float:
	return _land_height(-48,-float(hole.length)*.79)-.35
func height(x: float,z: float) -> float:
	if surface!=null:return surface.height(x,z)
	if connected:return _world_height(x,z)
	var h:=_land_height(x,z)
	if hole.water:
		var d:=Vector2(x+48,(z+float(hole.length)*.79)*1.65).length()
		if d<26:h=lerpf(pond_level()-.7,h,smoothstep(18.0,26.0,d))
	return h
func _land_height(x: float,z: float) -> float:
	var t := -z/float(hole.length)
	var baseline := float(hole.elevation)*clampf(t,0,1)
	var roll := sin(x*.043+index)*cos(z*.025)*2.4 + sin(z*.055+x*.023)*1.2
	var lateral := absf(x-center_x(t))
	var playable := baseline+sin(z*.018)*.7+sin(x*.028)*.4
	var h := playable+roll*smoothstep(float(hole.width)*.65,float(hole.width)*2.2,lateral)
	var d := green_distance(x,z)
	var gh := float(hole.elevation)+sin(-float(hole.length)*.018)*.7+sin(center_x(1)*.028)*.4
	gh += (x-center_x(1))*float(hole.green_slope[0])+(z+float(hole.length))*float(hole.green_slope[1])
	h = lerpf(gh,h,smoothstep(float(hole.green_radius),float(hole.green_radius)+9,d))
	for b in hole.bunkers:
		var center := bunker_center(b)
		var bd := Vector2(x-center.x,(z-center.y)*1.25).length()/float(b.radius)
		if bd<1.4: h -= .65*(1-smoothstep(.65,1.4,bd))
	h += 4.0
	var shore := -86.0+sin(z*.022)*6.0
	if not shared_patch and x < shore+45: h=minf(h,-1.3+(x-shore)*.28)
	return h
func normal_at(x: float,z: float) -> Vector3:
	var e := .12
	return Vector3(height(x-e,z)-height(x+e,z),2*e,height(x,z-e)-height(x,z+e)).normalized()
func wind() -> Vector3:
	return Vector3(course.wind[0],course.wind[1],course.wind[2])
