extends SceneTree
const Catalog=preload("res://scripts/minigolf/catalog.gd")
func _initialize()->void:run.call_deferred()
func run()->void:
	var id:="lakeside"
	var hole_index:=-1
	for arg in OS.get_cmdline_user_args():
		if arg in Catalog.ALL:id=arg
		if arg.begins_with("--hole="):hole_index=clampi(arg.trim_prefix("--hole=").to_int()-1,0,17)
	var scene:=Node3D.new();root.add_child(scene)
	var world=preload("res://scripts/minigolf/world.gd").new();scene.add_child(world);world.setup(id)
	preload("res://scripts/minigolf/preview_environment.gd").setup(scene,id)
	var camera:=Camera3D.new();scene.add_child(camera);camera.position=Vector3(-8,13,35);camera.look_at(Vector3(-14,2,19));camera.fov=65;camera.make_current()
	if hole_index>=0:
		var origin:=Catalog.origin(hole_index)
		camera.position=origin+Vector3(6,7,5);camera.look_at(origin+Vector3(0,0,-4))
	root.size=Vector2i(1440,900)
	await create_timer(3).timeout
	await RenderingServer.frame_post_draw
	var path:="res://test-results/minigolf-%s.png"%id
	if hole_index>=0:path="res://test-results/minigolf-%s-hole%02d.png"%[id,hole_index+1]
	var code:=root.get_texture().get_image().save_png(path)
	print("MINIGOLF_PREVIEW ",path," ",code)
	quit(code)
