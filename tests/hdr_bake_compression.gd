extends SceneTree
## Audit the actual desktop export cache, plus the unchanged mobile imports.
const HDR = preload("res://addons/fishing_export/hdr.gd")
const LOCATIONS = preload("res://scripts/locations.gd")
var failures: Array = []
var results: Dictionary = {}

func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label); push_error(label)

func vector(color: Color) -> Vector3:
	return Vector3(color.r, color.g, color.b)

func _initialize() -> void:
	for entry in LOCATIONS.CATALOG:
		if entry.id in ["meadow_bend", "boulder_run"]: continue
		var originals: Array[Image] = []
		var compressed: Array[Image] = []
		for kind in ["irradiance", "sky"]:
			var path: String = "res://assets/textures/lighting/" + entry.id + "_" + kind + ".exr"
			var cfg := ConfigFile.new(); cfg.load(path + ".import")
			var imported: String = cfg.get_value("remap", "path")
			var source: Image = load(path).get_image()
			check(source.get_format() in [Image.FORMAT_RGBE9995, Image.FORMAT_RGBH, Image.FORMAT_RGBAH, Image.FORMAT_RGBF, Image.FORMAT_RGBAF], "Mobile bake remains HDR: " + path)
			check(not cfg.get_value("params", "process/hdr_as_srgb", false) and not cfg.get_value("params", "process/hdr_clamp_exposure", false), "Linear unclamped bake import: " + path)
			var packed := HDR.export_path(path, imported, true)
			check(not packed.is_empty(), "Compression succeeds: " + path)
			if packed.is_empty(): quit(1); return
			var decoded: Image = load(packed).get_image()
			check(decoded.get_format() == source.get_format() and decoded.get_data() == source.get_data(), "Desktop bake preserves every HDR texel: " + path)
			check(HDR.export_path(path, imported, false) == imported, "Mobile bake preserves imported bytes: " + path)
			check(decoded.get_size() == source.get_size() and decoded.get_mipmap_count() == source.get_mipmap_count(), "Bake dimensions and mipmaps preserved: " + path)
			if decoded.is_compressed(): check(decoded.decompress() == OK, "Decode compressed bake: " + path)
			originals.append(source); compressed.append(decoded)
		# Check both former shadow paths, including full and partial actor shadow.
		# Runtime now always uses the complete irradiance bake (soft contact blobs).
		var metrics: Dictionary = {}
		for mode in ["baked", "legacy_dynamic_lit", "legacy_dynamic_partial", "legacy_dynamic_shadow"]:
			var error := 0.0; var energy := 0.0; var source_peak := 0.0; var result_peak := 0.0
			for y in range(1, originals[0].get_height(), 7):
				for x in range(1, originals[0].get_width(), 7):
					var original := vector(originals[0].get_pixel(x, y))
					var decoded := vector(compressed[0].get_pixel(x, y))
					if mode != "baked":
						var sky := vector(originals[1].get_pixel(x, y))
						var packed_sky := vector(compressed[1].get_pixel(x, y))
						var attenuation := 0.0 if mode.ends_with("shadow") else .5 if mode.ends_with("partial") else 1.0
						original = sky + (original - sky).max(Vector3.ZERO) * attenuation
						decoded = packed_sky + (decoded - packed_sky).max(Vector3.ZERO) * attenuation
					error += (decoded - original).length_squared()
					energy += original.length_squared()
					source_peak = maxf(source_peak, maxf(original.x, maxf(original.y, original.z)))
					result_peak = maxf(result_peak, maxf(decoded.x, maxf(decoded.y, decoded.z)))
			var relative_error := sqrt(error / maxf(energy, .00001))
			metrics[mode] = {"relative_rms_error": relative_error, "source_peak": source_peak, "compressed_peak": result_peak}
			check(relative_error < .04, "Lighting energy preserved within 4% RMS: " + entry.id + "/" + mode)
			check(result_peak > source_peak * .9 and result_peak < source_peak * 1.1, "HDR peaks preserved: " + entry.id + "/" + mode)
		results[entry.id] = metrics
		print("HDR_BAKE ", entry.id, " ", JSON.stringify(metrics))
	DirAccess.make_dir_recursive_absolute("res://test-results/fishing-update")
	var file := FileAccess.open("res://test-results/fishing-update/hdr-bakes.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "  "))
	print("HDR_BAKE_RESULT ", failures)
	quit(0 if failures.is_empty() else 1)
