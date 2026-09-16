extends RefCounted
const MAX_BYTES := 25_000_000
const Paths=preload("res://scripts/data_paths.gd")
static var CACHE: String:
	get: return Paths.folder("vrm")
const DEFAULTS = ["res://assets/avatars/sharkperson.vrm", "res://assets/avatars/vita.vrm", "res://assets/avatars/victoria.vrm"]
var entries: Array[Dictionary] = []
var selected_path := ""
var error := ""

func initialize() -> void:
	entries.clear()
	var migrated:=Paths.migrate_vrms(CACHE)
	for path in DEFAULTS:
		var info := inspect(path)
		if not info.has("error"): entries.append(info)
	for file in DirAccess.get_files_at(CACHE):
		if file.get_extension().to_lower()=="vrm":
			var info := inspect(CACHE + file)
			if not info.has("error"): entries.append(info)
	var config := ConfigFile.new()
	config.load("user://avatar.cfg")
	selected_path = str(config.get_value("avatar", "path", DEFAULTS[0]))
	if migrated.has(selected_path): save_selection(migrated[selected_path])

static func inspect(path: String) -> Dictionary:
	if path.get_extension().to_lower() != "vrm": return {"error": "Choose a .vrm file."}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file: return {"error": "Cannot open this VRM."}
	var size := file.get_length()
	# Check the limit before reading any model payload, hashing or copying.
	if size > MAX_BYTES: return {"error": "VRM exceeds 25 MB (25,000,000 bytes)."}
	if size < 28: return {"error": "This is not a valid binary VRM."}
	if file.get_32() != 0x46546c67 or file.get_32() != 2 or file.get_32() != size:
		return {"error": "Invalid VRM/GLB header."}
	var json_size := file.get_32()
	if file.get_32() != 0x4e4f534a or json_size > size - 28:
		return {"error": "Invalid VRM JSON chunk."}
	var doc = JSON.parse_string(file.get_buffer(json_size).get_string_from_utf8())
	if not doc is Dictionary: return {"error": "Invalid VRM metadata."}
	var bin_size := file.get_32()
	if file.get_32() != 0x004e4942 or file.get_position() + bin_size != size:
		return {"error": "Use a self-contained VRM with embedded textures."}
	for field in ["nodes", "buffers", "bufferViews", "images", "meshes", "skins", "accessors"]:
		if not doc.get(field, []) is Array: return {"error": "Invalid VRM structure: " + field}
		for item in doc.get(field, []):
			if not item is Dictionary: return {"error": "Invalid VRM object."}
	var ext = doc.get("extensions", {})
	if not ext is Dictionary: return {"error": "Invalid VRM extensions."}
	var vrm = ext.get("VRMC_vrm", ext.get("VRM", {}))
	if not vrm is Dictionary or not vrm.get("humanoid", {}) is Dictionary:
		return {"error": "VRM humanoid metadata is required."}
	var human = vrm.get("humanoid", {}).get("humanBones", {})
	var bones: Dictionary = {}
	if human is Array:
		for item in human:
			if not item is Dictionary: return {"error": "Invalid humanoid bone mapping."}
			bones[item.get("bone", "")] = item.get("node", -1)
	elif human is Dictionary:
		for key in human:
			if not human[key] is Dictionary: return {"error": "Invalid humanoid bone mapping."}
			bones[key] = human[key].get("node", -1)
	else: return {"error": "Invalid humanoid bone mapping."}
	var nodes: Array = doc.get("nodes", [])
	for bone in ["hips", "spine", "head", "leftUpperArm", "leftLowerArm", "leftHand", "rightUpperArm", "rightLowerArm", "rightHand", "leftUpperLeg", "leftLowerLeg", "leftFoot", "rightUpperLeg", "rightLowerLeg", "rightFoot"]:
		var index = bones.get(bone, -1)
		if not (index is float or index is int) or index != int(index) or index < 0 or index >= nodes.size():
			return {"error": "Missing or invalid humanoid bone: " + bone}
	var buffers: Array = doc.get("buffers", [])
	if buffers.size() != 1 or buffers[0].has("uri") or buffers[0].get("byteLength", 0) > bin_size:
		return {"error": "Use embedded VRM buffers."}
	for view in doc.get("bufferViews", []):
		if view.get("buffer", 0) != 0 or view.get("byteOffset", 0) < 0 or view.get("byteLength", 0) < 0 or view.get("byteOffset", 0) + view.get("byteLength", 0) > bin_size:
			return {"error": "Invalid VRM buffer bounds."}
	for image in doc.get("images", []):
		if image.has("uri"): return {"error": "Textures must be embedded in the VRM."}
	var meta = vrm.get("meta", {})
	if not meta is Dictionary: return {"error": "Invalid avatar metadata."}
	var title := str(meta.get("name", meta.get("title", path.get_file().get_basename())))
	if path == DEFAULTS[0]: title = "SharkPerson"
	if path == "res://assets/avatars/vita.vrm": title = "Vita"
	if path == "res://assets/avatars/victoria.vrm": title = "Victoria Rubin"
	return {"path": path, "size": size, "title": title.left(60), "author": str(meta.get("authors", meta.get("author", "Unknown"))).left(100)}

func import_file(path: String) -> Dictionary:
	return accept_import(copy_import(path,CACHE))

func accept_import(info: Dictionary) -> Dictionary:
	if info.has("error"):return info
	for entry in entries:
		if entry.path==info.path:return entry
	entries.append(info)
	return info

static func copy_import(path: String,directory: String) -> Dictionary:
	var info := inspect(path)
	if info.has("error"): return info
	var digest := FileAccess.get_sha256(path)
	if digest.is_empty(): return {"error": "Could not read the avatar."}
	if DirAccess.make_dir_recursive_absolute(directory)!=OK:return {"error":"Cannot create avatar folder: "+directory}
	var destination := directory.path_join(digest + ".vrm")
	if path != destination and DirAccess.copy_absolute(path, destination) != OK:
		return {"error": "Could not copy the avatar into your library."}
	var copied := inspect(destination)
	if copied.has("error"):
		DirAccess.remove_absolute(destination)
		return copied
	return copied

func load_model(path: String) -> Node3D:
	var stage_start:=Time.get_ticks_usec()
	error = ""
	var info := inspect(path)
	if info.has("error"):
		error = info.error
		return null
	preload("res://scripts/client_diagnostics.gd").stage("avatar_validate",stage_start,{"path":path})
	var extensions: Array = [preload("res://addons/vrm/vrm_extension.gd").new(), preload("res://addons/vrm/1.0/VRMC_node_constraint.gd").new(), preload("res://addons/vrm/1.0/VRMC_springBone.gd").new(), preload("res://addons/vrm/1.0/VRMC_materials_mtoon.gd").new(), preload("res://addons/vrm/1.0/VRMC_materials_hdr_emissiveMultiplier.gd").new(), preload("res://addons/vrm/1.0/VRMC_vrm.gd").new()]
	for extension in extensions: GLTFDocument.register_gltf_document_extension(extension, true)
	var gltf := GLTFDocument.new()
	var state := GLTFState.new()
	state.handle_binary_image = GLTFState.HANDLE_BINARY_EMBED_AS_UNCOMPRESSED
	# First/third person meshes are separated by the VRM plugin.
	state.set_additional_data("vrm/head_hiding_method", 3)
	state.set_additional_data("vrm/first_person_layers", 2)
	state.set_additional_data("vrm/third_person_layers", 4)
	var context := {"path":path,"sha256":FileAccess.get_sha256(path)}
	print("AVATAR_LOAD_BEGIN ",JSON.stringify(context))
	stage_start=Time.get_ticks_usec()
	var result := gltf.append_from_file(path, state, 8)
	preload("res://scripts/client_diagnostics.gd").stage("avatar_parse_images",stage_start,context)
	# glTF can return OK with null image placeholders after a decoder failure.
	# Do not equip or cache a partially textured avatar as a successful import.
	if result == OK:
		var images := state.get_images()
		for index in state.json.get("images",[]).size():
			if index>=images.size() or images[index]==null:
				error="Avatar %s: embedded image index %d could not be decoded. Re-export the avatar with valid PNG/JPEG textures." % [path.get_file(),index]
				break
	stage_start=Time.get_ticks_usec()
	var model: Node3D = gltf.generate_scene(state) if result == OK and error.is_empty() else null
	preload("res://scripts/client_diagnostics.gd").stage("avatar_scene",stage_start,context)
	for extension in extensions: GLTFDocument.unregister_gltf_document_extension(extension)
	if model == null:
		if error.is_empty(): error = "The Godot VRM plugin could not load avatar %s (%s)." % [path.get_file(),error_string(result) if result!=OK else "scene generation failed"]
		context["error"]=error
		printerr("AVATAR_LOAD_FAILED ",JSON.stringify(context))
	else:
		var bounds = preload("res://scripts/avatar_rest_bounds.gd")
		model.set_meta(bounds.CACHE_KEY, bounds.measure(model))
	return model

func save_selection(path: String) -> void:
	selected_path = path
	var config := ConfigFile.new()
	config.set_value("avatar", "path", path)
	var error:=config.save("user://avatar.cfg")
	if error!=OK:push_warning("Cannot save avatar selection: "+error_string(error))
