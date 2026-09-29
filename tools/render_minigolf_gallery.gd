extends SceneTree
const Catalog=preload("res://scripts/minigolf/catalog.gd")
func _initialize()->void:run.call_deferred()
func run()->void:
	var stage:="after" if "--before" not in OS.get_cmdline_user_args() else "before"
	var folder:="res://test-results/minigolf-gallery/"+stage
	DirAccess.make_dir_recursive_absolute(folder)
	root.size=Vector2i(1600,1000)
	var only:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):only=arg.trim_prefix("--only=")
	for id in Catalog.ALL:
		if not only.is_empty() and id!=only:continue
		var scene:=Node3D.new();root.add_child(scene)
		var world=preload("res://scripts/minigolf/world.gd").new();scene.add_child(world);world.setup(id)
		preload("res://scripts/minigolf/preview_environment.gd").setup(scene,id)
		var camera:=Camera3D.new();scene.add_child(camera);camera.fov=62;camera.make_current()
		for view in ["overview","detail"]:
			camera.position=Vector3(42,39,89) if view=="overview" else Vector3(-7,8,34)
			camera.look_at(Vector3(0,2,38) if view=="overview" else Vector3(-14,2,18))
			await create_timer(1.2).timeout
			await RenderingServer.frame_post_draw
			var path:String=folder+"/"+id+"-"+view+".png"
			var code:=root.get_texture().get_image().save_png(path)
			print("GALLERY ",id," ",view," ",code)
			if code!=OK:quit(code);return
		scene.queue_free();await process_frame
	quit()
