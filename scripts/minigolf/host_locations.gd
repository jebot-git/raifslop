extends RefCounted
const Courses=preload("res://scripts/minigolf/catalog.gd")
static func location(course:String,hole:int)->String:return "minigolf_%s_%02d"%[course,hole]
static func clubhouse(course:String)->String:return "minigolf_%s_clubhouse"%course
static func course_id(value:String)->String:
	for id in Courses.ALL:
		if value.begins_with("minigolf_"+id+"_"):return id
	return ""
static func is_clubhouse(value:String)->bool:
	var id:=course_id(value)
	return not id.is_empty() and value==clubhouse(id)
static func valid(value:String)->bool:
	var id:=course_id(value)
	if id.is_empty():return false
	if value==clubhouse(id):return true
	for i in 18:
		if value==location(id,i):return true
	return false
static func same_world(a:String,b:String)->bool:
	return a==b or (valid(a) and valid(b) and course_id(a)==course_id(b))
static func pose(_value:String)->Transform3D:return Transform3D(Basis.IDENTITY,Vector3(0,2,27))
