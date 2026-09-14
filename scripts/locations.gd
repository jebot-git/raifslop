extends RefCounted
## Photographed backdrops paired with authored foreground and lighting presets.
const DEFAULT_ID := "lakeside"
const SAVE_PATH := "user://location.cfg"
const CATALOG = [
	{"id": "lakeside", "name": "Lakeside", "mood": "Open water · Gentle morning", "description": "Gravel cove · Walk the stony shore beneath grassy hills.", "panorama": "res://assets/environment/locations/lakeside_4k.hdr", "preview": "res://assets/environment/locations/lakeside_preview.jpg", "yaw": 0.0, "sun_rotation": Vector3(-35, -40, 0), "sun_color": Color("ffe2b5"), "sun_energy": 0.55, "sky_energy": 0.8, "ambient": 0.42, "water": Color(0.025, 0.15, 0.17), "roughness": 0.3, "ripples": 1.0},
	{"id": "lake_pier", "name": "Lake Pier", "mood": "Harbour water · Soft sunrise", "description": "Harbour quay · Concrete paving, metal rails and mooring posts.", "panorama": "res://assets/environment/locations/lake_pier_4k.hdr", "preview": "res://assets/environment/locations/lake_pier_preview.jpg", "yaw": -100.0, "sun_rotation": Vector3(-12, -20, 0), "sun_color": Color("ffe9ce"), "sun_energy": 0.3, "sky_energy": 0.42, "ambient": 0.35, "water": Color("223e4d"), "roughness": 0.32, "ripples": 0.5},
	{"id": "gray_pier", "name": "Gray Pier", "mood": "Reed-lined lake · Overcast", "description": "Reed boardwalk · Weathered timber over still, sheltered water.", "panorama": "res://assets/environment/locations/gray_pier_4k.hdr", "preview": "res://assets/environment/locations/gray_pier_preview.jpg", "yaw": 108.0, "sun_rotation": Vector3(-50, -40, 0), "sun_color": Color("d8e3ee"), "sun_energy": 0.08, "sky_energy": 0.8, "ambient": 0.48, "water": Color("263332"), "roughness": 0.28, "ripples": 0.22},
	{"id": "bell_park_pier", "name": "Bell Park Pier", "mood": "Hill reservoir · Afternoon", "description": "Moored boat · Walk aboard a fishing boat beneath green hills.", "panorama": "res://assets/environment/locations/bell_park_pier_4k.hdr", "preview": "res://assets/environment/locations/bell_park_pier_preview.jpg", "yaw": -72.0, "sun_rotation": Vector3(-28, 40, 0), "sun_color": Color("fff1d4"), "sun_energy": 0.4, "sky_energy": 0.42, "ambient": 0.38, "water": Color("1b3836"), "roughness": 0.3, "ripples": 0.55},
]

static func find_location(id: String) -> Dictionary:
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
