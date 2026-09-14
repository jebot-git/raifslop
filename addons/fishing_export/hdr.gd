@tool
extends RefCounted
## Desktop-only BC6H cache. Android keeps the original RGBE HDR textures.
static func prepare(imported_path: String) -> String:
	var key := (FileAccess.get_sha256(imported_path) + str(Engine.get_version_info().hex) + "bc6h-v1").sha256_text()
	var dest := "res://.godot/fishing_export/" + key + ".res"
	if FileAccess.file_exists(dest): return dest
	DirAccess.make_dir_recursive_absolute("res://.godot/fishing_export")
	var texture := load(imported_path) as Texture2D
	if texture == null: return ""
	var image := texture.get_image()
	var err := image.compress(Image.COMPRESS_BPTC)
	if err != OK or image.get_format() not in [Image.FORMAT_BPTC_RGBF, Image.FORMAT_BPTC_RGBFU]:
		push_error("HDR compression failed: " + imported_path)
		return ""
	var pending := dest.trim_suffix(".res") + ".pending.res"
	err = ResourceSaver.save(ImageTexture.create_from_image(image), pending, ResourceSaver.FLAG_COMPRESS)
	if err != OK or DirAccess.rename_absolute(pending, dest) != OK:
		push_error("HDR compression failed to save: " + imported_path)
		return ""
	print("HDR_EXPORT ", imported_path.get_file(), " -> ", FileAccess.get_file_as_bytes(dest).size(), " bytes")
	return dest
