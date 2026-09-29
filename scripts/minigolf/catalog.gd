extends RefCounted
const ACTIVE = ["lakeside","lake_pier","gray_pier","bell_park_pier","simons_town_rocks","blouberg_sunrise_2","secluded_beach","fish_hoek_beach","meadow_bend","boulder_run","cedar_creek","glacier_run"]
const ALL = ACTIVE
# Only save validation knows archived IDs. They are never loaded or advertised.
const ARCHIVED = ["spyglass","pebble","cypress","poppy","dalkey","alpine"]
const NAMES = {"lakeside":"Cove & Pebble","lake_pier":"Mooring Masters","gray_pier":"Reedwalk","bell_park_pier":"Reservoir Regatta","simons_town_rocks":"Granite Galleys","blouberg_sunrise_2":"Dawn Dunes","secluded_beach":"Smuggler’s Cove","fish_hoek_beach":"Driftwood Strand","meadow_bend":"Meadow Meanders","boulder_run":"Rapids & Ricochets","cedar_creek":"Cedar Canopy","glacier_run":"Glacier Express"}
static var cache:Dictionary={}
static func course(id:String)->Dictionary:
	if id not in ALL:return {}
	if not cache.has(id):cache[id]=JSON.parse_string(FileAccess.get_file_as_string("res://assets/minigolf/courses/%s.json"%id))
	return cache[id]
static func origin(hole:int)->Vector3:
	# Three connected rows, serpentine walking order. Fishing occupies Z < 8.
	var row:=floori(hole/6.0)
	var column:=hole%6 if row%2==0 else 5-hole%6
	return Vector3((column-2.5)*8,2,24+row*19)
static func point(value:Array)->Vector2:return Vector2(float(value[0]),float(value[1]))

static func needs_boat(id:String)->bool:
	# Stereo shoreline audit: these platforms extend over rendered water.
	# Lake Pier's distant photo apron is not a usable quay connection.
	return id in ["lakeside","lake_pier","gray_pier","bell_park_pier"]
