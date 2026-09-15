extends SceneTree
## Run with Godot --main-pack <export.pck> --script <absolute path to this file>.
var failures: Array[String] = []
var entries: Dictionary = {}
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message); push_error(message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var stack: Array[String] = ["res://"]
	while not stack.is_empty():
		var folder: String = stack.pop_back()
		for name in DirAccess.get_files_at(folder):
			var path := folder.path_join(name)
			var file := FileAccess.open(path, FileAccess.READ)
			if file: entries[path] = file.get_length()
			check(not name.to_lower().begins_with("readme"), "README leaked: " + path)
			check(name != "export_presets.cfg" and name != "plugin.cfg", "Editor config leaked: " + path)
		for child in DirAccess.get_directories_at(folder):
			var path := folder.path_join(child)
			check(path not in ["res://docs", "res://source", "res://tests", "res://tools", "res://builds", "res://data", "res://.release-signing", "res://addons/godot_ai", "res://addons/fishing_export"], "Private/development folder leaked: " + path)
			stack.append(path)
	var desktop := not OS.get_cmdline_user_args().has("--mobile-textures")
	var metrics: Dictionary = {}
	for entry in load("res://scripts/locations.gd").CATALOG:
		var texture := load(entry.panorama) as Texture2D
		check(texture != null, "Missing panorama " + entry.id)
		if texture == null: continue
		check(texture.get_size() == Vector2(8192,4096), "Panorama is not native 8K " + entry.id)
		var pixels := texture.get_image()
		check(pixels.has_mipmaps(), "Missing panorama mipmaps " + entry.id)
		check(pixels.get_format() == (Image.FORMAT_BPTC_RGBFU if desktop else Image.FORMAT_RGBE9995), "Wrong HDR format " + entry.id + ": " + str(pixels.get_format()))
		metrics[entry.id] = {"size": str(texture.get_size()), "format": pixels.get_format()}
		if entry.id in ["meadow_bend","boulder_run"]: continue # Procedural banks use shared river textures.
		for name in ["irradiance", "sky", "ao"]:
			check(load("res://assets/textures/lighting/" + entry.id + "_" + name + (".png" if name == "ao" else ".exr")) != null, "Missing lighting " + entry.id + " " + name)
	# Exercise every dynamically addressed model and each packaged shore material.
	for fish in load("res://scripts/fishing_session.gd").SPECIES:
		var path: String = fish.get("model", "res://assets/models/european_perch.glb")
		var scene = load(path)
		check(scene != null, "Missing fish " + path)
		if scene:
			var model = scene.instantiate();model.free()
	var game = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	await create_timer(.4).timeout
	for entry in game.Locations.CATALOG:
		game._select_location(entry.id, false)
		await process_frame
	game.queue_free();await process_frame;await create_timer(.3).timeout
	var total := 0
	for size in entries.values(): total += size
	var report := {"files": entries, "total_bytes": total, "panoramas": metrics, "failures": failures}
	var args := OS.get_cmdline_user_args()
	var index := args.find("--report")
	if index >= 0 and index + 1 < args.size():
		var out := FileAccess.open(args[index+1], FileAccess.WRITE);out.store_string(JSON.stringify(report,"  "))
	print("RELEASE_PACK ", JSON.stringify({"count":entries.size(), "bytes":total,"panoramas":metrics,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
