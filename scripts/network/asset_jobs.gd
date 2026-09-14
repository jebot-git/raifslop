## Adapted from jebot-git/FPSloppa, commit 5105fb8cfa38c76aa1d5d172af3047fe2d12ae0d.
extends RefCounted
## Pure disk/metadata work: never accesses the scene tree or shared resources.
const Models=preload("res://scripts/network/avatar_library.gd")
static func model_file(path: String,hash: String,directory: String,copy: bool=true) -> Dictionary:
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=hash:return {"error":"Model checksum failed."}
	var info:=Models.inspect(path)
	if info.has("error"):return info
	var destination:=directory+hash+".vrm" if copy else path
	if copy and not FileAccess.file_exists(destination) and not room(directory,"vrm",info.size,Models.CACHE_BUDGET):return {"error":"Avatar cache is full (1 GB)."}
	DirAccess.make_dir_recursive_absolute(directory)
	if path!=destination and DirAccess.copy_absolute(path,destination)!=OK:return {"error":"Cannot save model."}
	info.hash=hash;info.path=destination
	return info

static func room(directory: String,extension: String,required: int,limit: int) -> bool:
	var total:=required
	for filename in DirAccess.get_files_at(directory):
		if filename.get_extension()!=extension:continue
		var file:=FileAccess.open(directory+filename,FileAccess.READ)
		if file:total+=file.get_length()
	return total<=limit

static func verify_models(entries: Array) -> Array:
	var invalid: Array=[]
	for entry in entries:
		if preload("res://scripts/network/disk_worker.gd").size(entry.path)!=entry.size or FileAccess.get_sha256(entry.path)!=entry.hash:invalid.append(entry.hash)
	return invalid

static func local_model(path: String) -> Dictionary:
	var info:=Models.inspect(path)
	if info.has("error"): return info
	info.hash=FileAccess.get_sha256(path)
	if not Models.valid_hash(info.hash): return {"error":"Cannot read selected avatar."}
	info.path=path
	return info
