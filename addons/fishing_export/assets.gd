@tool
extends EditorExportPlugin
const HDR = preload("res://addons/fishing_export/hdr.gd")
var textures: Dictionary = {}
var emitted: Dictionary = {}
var desktop := false

func _get_name() -> String: return "FishingRuntimeAssets"

func _export_begin(features: PackedStringArray, _debug: bool, _path: String, _flags: int) -> void:
	textures.clear()
	emitted.clear()
	desktop = features.has("pc")
	_scan_textures("res://assets", features)

func _scan_textures(folder: String, features: PackedStringArray) -> void:
	for name in DirAccess.get_files_at(folder):
		if not name.ends_with(".import"): continue
		var config := ConfigFile.new()
		if config.load(folder.path_join(name)) != OK or config.get_value("remap", "importer", "") != "texture": continue
		var imported: String = config.get_value("remap", "path", "")
		for feature in features:
			if config.has_section_key("remap", "path." + feature):
				imported = config.get_value("remap", "path." + feature)
		if imported.is_empty(): continue
		var source := folder.path_join(name.trim_suffix(".import"))
		textures[source] = imported
	for child in DirAccess.get_directories_at(folder):
		_scan_textures(folder.path_join(child), features)

func _export_file(path: String, _type: String, _features: PackedStringArray) -> void:
	if path.ends_with(".vrm"):
		skip()
		add_file(path, FileAccess.get_file_as_bytes(path), false)
	elif textures.has(path):
		var imported: String = textures[path]
		if desktop and path.get_extension() in ["hdr", "exr"]:
			var compressed := HDR.prepare(imported)
			if compressed.is_empty(): return # Error is reported; build tooling rejects it.
			imported = compressed
		# Hash the final imported bytes: different colour-space/normal/mipmap settings
		# cannot accidentally alias, even when their source image bytes are identical.
		var digest := FileAccess.get_sha256(imported)
		var packed := "res://.godot/fishing_export/" + digest + "." + imported.get_extension()
		skip()
		if not emitted.has(packed):
			add_file(packed, FileAccess.get_file_as_bytes(imported), false)
			emitted[packed] = true
		var remap := ConfigFile.new()
		var suffix := ".remap"
		if imported.ends_with(".ctex"):
			# Preserve the importer type adapter: material dependencies request
			# Texture2D, while the raw .ctex loader handles CompressedTexture2D.
			var original := ConfigFile.new()
			original.load(path + ".import")
			remap.set_value("remap", "importer", "texture")
			remap.set_value("remap", "type", "CompressedTexture2D")
			if original.has_section_key("remap", "uid"):
				remap.set_value("remap", "uid", original.get_value("remap", "uid"))
			suffix = ".import"
		remap.set_value("remap", "path", packed)
		add_file(path + suffix, remap.encode_to_text().to_utf8_buffer(), false)
