extends RefCounted
const Waters=preload("res://scripts/locations.gd")
static func all()->Dictionary:
	var result:Dictionary={}
	for water in Waters.CATALOG:result["water_"+water.id]={"kind":"water","id":water.id,"name":water.name}
	return result
static func for_location(location:String)->String:
	if all().has("water_"+location):return "water_"+location
	return ""
