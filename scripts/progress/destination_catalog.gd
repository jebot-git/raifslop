extends RefCounted
const Waters=preload("res://scripts/locations.gd")
const Courses=preload("res://addons/golfminus/scripts/golf/catalog.gd")
static func all()->Dictionary:
	var result:Dictionary={}
	for water in Waters.CATALOG:result["water_"+water.id]={"kind":"water","id":water.id,"name":water.name}
	for course in Courses.ACTIVE:result["course_"+course]={"kind":"course","id":course,"name":Courses.NAMES[course]}
	return result
static func for_location(location:String)->String:
	if all().has("water_"+location):return "water_"+location
	for course in Courses.ACTIVE:
		if location.begins_with("golf_"+course+"_"):return "course_"+course
	return ""
