extends RefCounted
## Keep this dependency-free: no game resources may load before the OBB mounts.

static func metadata_error(record: Dictionary) -> String:
	for key in ["format", "file", "package", "version_code", "bytes", "sha256", "entries"]:
		if not record.has(key): return "Incomplete game download information."
	var expected := "main.%d.%s.obb" % [int(record.version_code), str(record.package)]
	if int(record.format) != 1 or str(record.file) != expected or expected.get_file() != expected:
		return "Invalid game download information."
	if int(record.version_code) <= 0 or int(record.bytes) <= 0 or int(record.bytes) >= 4000000000:
		return "Invalid game download size or version."
	var digest := str(record.sha256)
	if digest.length() != 64 or not digest.is_valid_hex_number(false):
		return "Invalid game download checksum."
	return ""

static func verify_file(path: String, record: Dictionary) -> String:
	var error := metadata_error(record)
	if not error.is_empty(): return error
	if path.get_file() != str(record.file): return "The game download belongs to another version."
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return "The game download is missing."
	if file.get_length() != int(record.bytes): return "The game download is incomplete or belongs to another version."
	file.close()
	# Run on a worker: keep head tracking and the loading message responsive.
	if FileAccess.get_sha256(path) != str(record.sha256): return "The game download is damaged or belongs to another version."
	return ""
