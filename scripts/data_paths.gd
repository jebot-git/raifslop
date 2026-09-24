extends RefCounted
## Writable player assets; explicit roots retain the portable/server convention.
static func root() -> String:
	var args:=OS.get_cmdline_user_args()
	var index:=args.find("--asset-root")
	if index>=0 and index+1<args.size():return ProjectSettings.globalize_path(args[index+1]).simplify_path()
	if OS.has_feature("android"):
		if Engine.has_singleton("AndroidRuntime"):
			var context=Engine.get_singleton("AndroidRuntime").getApplicationContext()
			# Godot's Java bridge requires a String; an empty type selects files/.
			var external=context.getExternalFilesDir("")
			if external!=null:return str(external.getAbsolutePath()).path_join("data")
		var package:="org.jebot.raifslop.pico" if OS.has_feature("pico_xr") else "org.jebot.raifslop.quest"
		return "/sdcard/Android/data/"+package+"/files/data"
	if OS.has_feature("editor"):return ProjectSettings.globalize_path("res://data")
	return ProjectSettings.globalize_path("user://data")
static func folder(kind: String) -> String:
	return root().path_join(kind)+"/"
static func photos() -> String:
	var args:=OS.get_cmdline_user_args()
	var index:=args.find("--photos-root")
	if index>=0 and index+1<args.size():return ProjectSettings.globalize_path(args[index+1]).simplify_path()
	var pictures:=OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
	return pictures.path_join("Ultimate Boomer Simulator") if not pictures.is_empty() else ProjectSettings.globalize_path("user://photos")
static func legacy_vrm_folders() -> Array[String]:
	var folders:Array[String]=["user://avatars/","user://network_avatars/"]
	if not OS.has_feature("editor") and not OS.has_feature("android"):
		folders.append(OS.get_executable_path().get_base_dir().path_join("data/vrm"))
	return folders

static func migrate_vrms(destination: String, sources:Array[String]=[]) -> Dictionary:
	if sources.is_empty():sources=legacy_vrm_folders()
	var migrated: Dictionary={}
	if DirAccess.make_dir_recursive_absolute(destination)!=OK:return migrated
	for legacy in sources:
		if ProjectSettings.globalize_path(legacy).simplify_path()==ProjectSettings.globalize_path(destination).simplify_path():continue
		if not DirAccess.dir_exists_absolute(legacy):continue
		for filename in DirAccess.get_files_at(legacy):
			if filename.get_extension().to_lower()!="vrm":continue
			var source: String=legacy.path_join(filename)
			var target:=destination.path_join(filename)
			# Preserve both files on name collisions, including the equipped model.
			var hash:=FileAccess.get_sha256(source)
			if hash.is_empty():continue
			if FileAccess.file_exists(target) and FileAccess.get_sha256(target)!=hash:
				target=destination.path_join(hash+".vrm")
			if FileAccess.file_exists(target):
				if FileAccess.get_sha256(target)==hash:migrated[source]=target
			elif DirAccess.copy_absolute(source,target)==OK:migrated[source]=target
	return migrated
