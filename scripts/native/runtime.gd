extends RefCounted
## Optional acceleration; all platforms retain the reference implementation.
static var attempted:=false
static func create():
	if "--gdscript-native" in OS.get_cmdline_user_args():return null
	if not attempted:
		attempted=true
		var path:="res://addons/fishing_native/fishing_native.gdextension"
		if not ClassDB.class_exists("FishingNative") and FileAccess.file_exists(path):
			GDExtensionManager.load_extension(path)
	return ClassDB.instantiate("FishingNative") if ClassDB.class_exists("FishingNative") else null
