extends SceneTree
const Paths=preload("res://scripts/data_paths.gd")
const Library=preload("res://scripts/avatar_library.gd")
const Photo=preload("res://scripts/guide_camera.gd")
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func run():
	check(Library.CACHE==Paths.folder("vrm") and preload("res://scripts/network/avatar_library.gd").CACHE==Library.CACHE,"Local and downloaded VRMs share external folder")
	check(not Paths.root().begins_with("user://") and not Paths.root().begins_with("res://"),"Asset root is a real external filesystem directory")
	DirAccess.make_dir_recursive_absolute("user://avatars")
	var old:="user://avatars/previous.vrm"
	check(DirAccess.copy_absolute(Library.DEFAULTS[1],old)==OK,"Legacy avatar fixture created")
	var cfg:=ConfigFile.new();cfg.set_value("avatar","path",old);cfg.save("user://avatar.cfg")
	var library=Library.new();library.initialize()
	check(FileAccess.file_exists(old) and FileAccess.file_exists(Library.CACHE+"previous.vrm"),"Migration preserves original VRM and creates external copy")
	check(library.selected_path==Library.CACHE+"previous.vrm","Migration preserves avatar selection")
	var imported: Dictionary=library.import_file(Library.DEFAULTS[2])
	check(not imported.has("error") and imported.path.begins_with(Library.CACHE),"New imports are content-addressed in external folder")
	var count: int=library.entries.size();library.import_file(Library.DEFAULTS[2])
	check(library.entries.size()==count,"Repeated import does not duplicate library entries")
	var photo:=Image.create(16,16,false,Image.FORMAT_RGB8);photo.fill(Color.CORNFLOWER_BLUE)
	var destination:=Photo.PHOTO_DIR.path_join("storage-test.png")
	var disk=preload("res://scripts/network/disk_worker.gd").new();root.add_child(disk)
	var result: Array=[]
	disk.submit(Photo.save_photo.bind(photo,destination),func(error):result.append(error))
	var deadline:=Time.get_ticks_msec()+4000
	while result.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
	check(result==[OK] and FileAccess.file_exists(destination),"PNG saves asynchronously to configured Pictures folder")
	check(Image.load_from_file(destination).get_size()==Vector2i(16,16),"Saved PNG decodes intact")
	disk.queue_free();await process_frame
	print("EXTERNAL_DATA_RESULT ",failures);quit(0 if failures.is_empty() else 1)
