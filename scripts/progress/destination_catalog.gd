extends RefCounted
const Waters=preload("res://scripts/locations.gd")
const Courses=preload("res://scripts/minigolf/catalog.gd")
static func all()->Dictionary:
	var result:Dictionary={}
	for water in Waters.CATALOG:result["water_"+water.id]={"kind":"water","id":water.id,"name":water.name}
	for course in Courses.ACTIVE:result["course_"+course]={"kind":"course","id":course,"name":Courses.NAMES[course]}
	return result
static func for_location(location:String)->String:
	if all().has("water_"+location):return "water_"+location
	for course in Courses.ACTIVE:
		if preload("res://scripts/minigolf/host_locations.gd").valid(location) and location.begins_with("minigolf_"+course+"_"):return "course_"+course
	return ""
