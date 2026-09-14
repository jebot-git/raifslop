extends SceneTree
func _initialize():run.call_deferred()
func run():
	root.size=Vector2i(1600,1000)
	var g=load("res://scenes/main.tscn").instantiate();root.add_child(g)
	await create_timer(.4).timeout
	g.set_process(false);g.motor.set_physics_process(false);g.hud.hide();g.avatar.hide();g.fish_guide.hide();g.rod.hide();g.game.reset();g._update_line()
	for entry in g.Locations.CATALOG:
		g._select_location(entry.id,false)
		g.head.global_basis=Basis(Vector3.UP,deg_to_rad(entry.yaw));g.head.fov=65
		for i in 12:await process_frame
		await RenderingServer.frame_post_draw
		var image:=root.get_texture().get_image()
		var stage:="after" if "--after" in OS.get_cmdline_user_args() else "before"
		image.save_png("res://test-results/panorama-8k/"+entry.id+"-seam-"+stage+".png")
		print("SEAM_RENDER ",entry.id," ",stage)
	g.queue_free();await process_frame;await create_timer(.3).timeout;quit()
