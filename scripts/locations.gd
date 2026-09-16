extends RefCounted
## Photographed backdrops paired with authored foreground and lighting presets.
const DEFAULT_ID := "lakeside"
const SAVE_PATH := "user://location.cfg"
# Legacy sun values are fallbacks; the measured bake data is applied on lookup.
static var CATALOG:Array = [
	{"id": "lakeside", "name": "Lakeside", "mood": "Open water · Gentle morning", "description": "Gravel cove · Rope-lined paths along the stony shore beneath grassy hills.", "panorama": "res://assets/environment/locations/lakeside_8k.hdr", "preview": "res://assets/environment/locations/lakeside_preview.jpg", "yaw": 0.0, "sun_rotation": Vector3(-35, -40, 0), "sun_color": Color("ffe2b5"), "sun_energy": 0.55, "sky_energy": 0.8, "ambient": 0.42, "water": Color(0.025, 0.15, 0.17), "roughness": 0.3, "ripples": 1.0},
	{"id": "lake_pier", "name": "Lake Pier", "water_level": -.85, "protect_panorama_foreground": true, "panorama_water_region": Vector4(.72,.84,.505,.558), "mood": "Harbour water · Soft sunrise", "description": "Harbour quay · Concrete paving, metal rails and mooring posts.", "panorama": "res://assets/environment/locations/lake_pier_8k.hdr", "preview": "res://assets/environment/locations/lake_pier_preview.jpg", "yaw": -100.0, "sun_rotation": Vector3(-12, -20, 0), "sun_color": Color("ffe9ce"), "sun_energy": 0.3, "sky_energy": 0.42, "ambient": 0.35, "water": Color("223e4d"), "roughness": 0.32, "ripples": 0.5},
	{"id": "gray_pier", "name": "Gray Pier", "mood": "Reed-lined lake · Overcast", "description": "Reed boardwalk · Weathered timber and rope barriers over sheltered water.", "panorama": "res://assets/environment/locations/gray_pier_8k.hdr", "preview": "res://assets/environment/locations/gray_pier_preview.jpg", "yaw": 108.0, "sun_rotation": Vector3(-50, -40, 0), "sun_color": Color("d8e3ee"), "sun_energy": 0.08, "sky_energy": 0.8, "ambient": 0.48, "water": Color("263332"), "roughness": 0.28, "ripples": 0.22},
	{"id": "bell_park_pier", "name": "Bell Park Pier", "mood": "Hill reservoir · Afternoon", "description": "Moored boat · Walk aboard a fishing boat beneath green hills.", "panorama": "res://assets/environment/locations/bell_park_pier_8k.hdr", "preview": "res://assets/environment/locations/bell_park_pier_preview.jpg", "yaw": -72.0, "sun_rotation": Vector3(-28, 40, 0), "sun_color": Color("fff1d4"), "sun_energy": 0.4, "sky_energy": 0.42, "ambient": 0.38, "water": Color("1b3836"), "roughness": 0.3, "ripples": 0.55},
	{"id": "simons_town_rocks", "name": "Coastal Rocks", "mood": "Saltwater coast · Clear daylight", "description": "Rock-supported terrace with a weathered rope barrier overlooking a coastal bay.", "panorama": "res://assets/environment/locations/simons_town_rocks_8k.hdr", "preview": "res://assets/environment/locations/simons_town_rocks_preview.jpg", "yaw": 180.0, "sun_rotation": Vector3(-38, -65, 0), "sun_color": Color("fff7e6"), "sun_energy": .5, "sky_energy": .65, "ambient": .4, "water": Color("17333c"), "roughness": .26, "ripples": .9, "protect_panorama_foreground": true, "panorama_water_region": Vector4(.32,.69,.505,.66), "ground_bounds": Vector4(0,2,4.5,5)},
	{"id": "blouberg_sunrise_2", "name": "Sunrise Beach", "mood": "Saltwater coast · Dawn surf", "description": "Walk a modeled sandy shore down to the surf.", "panorama": "res://assets/environment/locations/blouberg_sunrise_2_8k.hdr", "preview": "res://assets/environment/locations/blouberg_sunrise_2_preview.jpg", "yaw": 180.0, "sun_rotation": Vector3(-8, 95, 0), "sun_color": Color("ffd9b8"), "sun_energy": .16, "sky_energy": .8, "ambient": .4, "water": Color("354951"), "roughness": .5, "ripples": .45, "ground_bounds": Vector4(0,4.5,3.5,7.5), "ground_transition": Vector2(12,6)},
 {"id":"meadow_bend","name":"Meadow Bend","mood":"Fly fishing · Gentle river","description":"Gravel bank, slow margins and a clear current seam. Dry flies and nymphs.","panorama":"res://assets/environment/locations/lakeside_8k.hdr","preview":"res://assets/environment/locations/meadow_bend_preview.jpg","yaw":0.0,"sun_rotation":Vector3(-35,-40,0),"sun_color":Color("fff0d5"),"sun_energy":.55,"sky_energy":.8,"ambient":.42,"water":Color("294b40"),"roughness":.35,"ripples":.6},
 {"id":"boulder_run","name":"Boulder Run","mood":"Fly fishing · Fast river","description":"Rocky bank and boulder pockets beside a powerful current. Mend upstream for a natural drift.","panorama":"res://assets/environment/locations/bell_park_pier_8k.hdr","preview":"res://assets/environment/locations/boulder_run_preview.jpg","yaw":-72.0,"sun_rotation":Vector3(-28,40,0),"sun_color":Color("fff1d4"),"sun_energy":.4,"sky_energy":.42,"ambient":.38,"water":Color("1b3836"),"roughness":.3,"ripples":1.2},
]

static var measured_lighting:Dictionary = {}
static func apply_measured_lighting() -> void:
	if not measured_lighting.is_empty():return
	var path := "res://assets/textures/lighting/panorama_lighting.json"
	if not FileAccess.file_exists(path):return
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:return
	measured_lighting=data
	for entry in CATALOG:
		var source:String={"meadow_bend":"lakeside","boulder_run":"bell_park_pier"}.get(entry.id,entry.id)
		if not measured_lighting.has(source):continue
		var light:Dictionary=measured_lighting[source]
		var r:Array=light.sun_rotation
		var c:Array=light.sun_color_linear
		entry.sun_rotation=Vector3(r[0],r[1],r[2])
		entry.sun_color=Color(c[0],c[1],c[2]).linear_to_srgb()
		entry.sun_energy=light.sun_energy
		entry["sun_angular_distance"]=light.sun_angular_diameter_degrees

static func find_location(id: String) -> Dictionary:
	apply_measured_lighting()
	for entry in CATALOG:
		if entry.id == id: return entry
	return {}

static func saved_location() -> String:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK: return DEFAULT_ID
	var id := str(config.get_value("location", "id", DEFAULT_ID))
	return DEFAULT_ID if find_location(id).is_empty() else id

static func save_location(id: String) -> Error:
	if find_location(id).is_empty(): return ERR_INVALID_PARAMETER
	var config := ConfigFile.new()
	config.set_value("location", "id", id)
	return config.save(SAVE_PATH)
