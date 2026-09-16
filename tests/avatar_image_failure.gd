extends SceneTree
const Library=preload("res://scripts/avatar_library.gd")
const NetworkLibrary=preload("res://scripts/network/avatar_library.gd")
var failures:Array[String]=[]
func check(ok:bool,label:String)->void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize()->void:run.call_deferred()
func run()->void:
	var bytes:=FileAccess.get_file_as_bytes("res://assets/avatars/vita.vrm")
	var json_size:=bytes.decode_u32(12)
	var doc:Dictionary=JSON.parse_string(bytes.slice(20,20+json_size).get_string_from_utf8())
	var view:Dictionary=doc.bufferViews[doc.images[6].bufferView]
	var start:=28+json_size+int(view.get("byteOffset",0))
	# Preserve the signature, IHDR and GLB bounds, but corrupt the IDAT payload.
	var cursor:=start+8
	while cursor<start+int(view.byteLength):
		var size:=NetworkLibrary.be32(bytes,cursor)
		if bytes.slice(cursor+4,cursor+8).get_string_from_ascii()=="IDAT":
			bytes[cursor+8]=bytes[cursor+8]^255;break
		cursor+=12+size
	check(cursor<start+int(view.byteLength),"Fixture corrupts image index 6 without changing headers")
	var path:="user://corrupt_image_6.vrm"
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_buffer(bytes);file.close()
	check(not Library.inspect(path).has("error") and not NetworkLibrary.inspect(path).has("error"),"Fixture reproduces a damaged PNG that passes existing metadata validation")
	var library:=Library.new()
	# Invalid PNG engine diagnostics are deliberate for this fixture only.
	var print_errors:=Engine.print_error_messages;Engine.print_error_messages=false
	var model:=library.load_model(path)
	Engine.print_error_messages=print_errors
	check(model==null,"Incomplete avatar is rejected instead of accepted with a missing texture")
	check(library.error.contains("6") and library.error.contains("corrupt_image_6.vrm"),"Failure identifies the image index and avatar filename")
	if model:model.free()
	var network:=NetworkLibrary.new()
	var hash:=FileAccess.get_sha256(path)
	network.entries[hash]={"path":path}
	Engine.print_error_messages=false
	model=network.create_avatar(hash)
	Engine.print_error_messages=print_errors
	check(model==null and not network.scenes.has(hash),"Failed remote model never enters the packed scene cache")
	check(network.last_error.contains("6"),"Network avatar error preserves the decoder context")
	if model:model.free()
	network.free()
	var good:=library.load_model("res://assets/avatars/vita.vrm")
	check(good!=null and library.error.is_empty(),"Valid avatar loads after the failed import and clears the error")
	if good:good.free()
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await create_timer(.3).timeout
	var previous=game.avatar
	var selected:String=game.avatars.selected_path
	Engine.print_error_messages=false
	await game._select_avatar(path)
	Engine.print_error_messages=print_errors
	check(game.avatar==previous and game.avatars.selected_path==selected,"Damaged texture preserves the equipped avatar and saved selection")
	check(game.avatar_menu.status.text.contains("image index 6"),"Avatar menu explains which embedded texture failed")
	game.queue_free();await process_frame;await create_timer(.2).timeout
	DirAccess.remove_absolute(path)
	await process_frame
	print("AVATAR_IMAGE_FAILURE_RESULT ",failures)
	quit(0 if failures.is_empty() else 1)
