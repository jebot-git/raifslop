@tool
extends EditorExportPlugin
func _get_name() -> String: return "FishingRuntimeAssets"
func _export_file(path: String, _type: String, _features: PackedStringArray) -> void:
	if path.ends_with(".vrm"):
		skip()
		add_file(path, FileAccess.get_file_as_bytes(path), false)
