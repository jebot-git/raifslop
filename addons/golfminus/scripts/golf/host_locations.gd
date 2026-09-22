extends RefCounted
static var cached:Dictionary={}
static var shared_courses:Dictionary={}
const Model=preload("res://addons/golfminus/scripts/golf/course_model.gd")
static func location(course:String,hole:int)->String:return "golf_%s_%02d"%[course,hole]
static func clubhouse(course:String)->String:return "golf_%s_clubhouse"%course
static func is_clubhouse(value:String)->bool:return value in [clubhouse("spyglass"),clubhouse("pebble"),clubhouse("dalkey"),clubhouse("alpine")]
static func same_world(a:String,b:String)->bool:
	if a==b:return true
	if not valid(a) or not valid(b):return false
	var course_id:=a.split("_")[1]
	if course_id!=b.split("_")[1]:return false
	# Never reveal overlapping local-coordinate holes from a legacy course.
	if not shared_courses.has(course_id):
		var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://addons/golfminus/courses/%s.json"%course_id))
		shared_courses[course_id]=data.has("layout")
	return shared_courses[course_id]
static func valid(value:String)->bool:
	if is_clubhouse(value):return true
	var parts:=value.split("_")
	return parts.size()==3 and parts[0]=="golf" and parts[1] in ["spyglass","pebble","dalkey","alpine"] and parts[2].is_valid_int() and int(parts[2])>=0 and int(parts[2])<18 and value==location(parts[1],int(parts[2]))
static func surface(model:RefCounted,x:float,z:float)->float:
	if model.connected:
		var x0:=floorf(x/2)*2;var z0:=floorf(z/2)*2
		var u:=(x-x0)/2;var v:=(z-z0)/2
		var a:float=model.height(x0,z0);var b:float=model.height(x0+2,z0)
		var c:float=model.height(x0,z0+2);var d:float=model.height(x0+2,z0+2)
		return a+(b-a)*u+(c-a)*v if u+v<=1 else d+(c-d)*(1-u)+(b-d)*(1-v)
	var x0:=floorf((x+132)/2)*2-132;var z0:=48-floorf((48-z)/2)*2
	var u:=(x-x0)/2;var v:=(z0-z)/2
	var a:float=model.height(x0,z0);var b:float=model.height(x0+2,z0)
	var c:float=model.height(x0,z0-2);var d:float=model.height(x0+2,z0-2)
	return a+(b-a)*u+(c-a)*v if u+v<=1 else d+(c-d)*(1-u)+(b-d)*(1-v)
static func pose(value:String)->Transform3D:
	if cached.has(value):return cached[value]
	var model=Model.new();model.load_course(value.split("_")[1],0)
	# Same perimeter samples and oak-deck top as course_world.ground_pavilion.
	var corners:=[Vector2(37,13.5),Vector2(49,13.5),Vector2(49,20.5),Vector2(37,20.5)]
	var center:=Vector2(43,17)
	if model.connected:
		var at:Array=model.layout.data.get("clubhouse",[43,17])
		center=Vector2(at[0],at[1])
		for i in corners.size():corners[i]+=center-Vector2(43,17)
	var height:float=-INF
	for side in 4:
		for i in 16:
			var point:Vector2=corners[side].lerp(corners[(side+1)%4],i/16.0)
			height=maxf(height,surface(model,point.x,point.y))
	cached[value]=Transform3D(Basis.IDENTITY,Vector3(center.x,height+.415,center.y+1.5))
	return cached[value]
