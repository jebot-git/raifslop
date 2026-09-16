extends SceneTree
func _initialize() -> void:
	var helper = load("res://addons/fishing_export/hdr.gd")
	# Lighting atlases stay lossless; only desktop panoramas need BC6H caches.
	for folder in ["res://assets/environment/locations"]:
		for name in DirAccess.get_files_at(folder):
			if not name.ends_with(".hdr.import") and not name.ends_with(".exr.import"): continue
			var config := ConfigFile.new()
			if config.load(folder.path_join(name)) != OK: quit(1); return
			if helper.prepare(config.get_value("remap", "path")).is_empty(): quit(1); return
	quit()
