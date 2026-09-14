extends SceneTree
func _initialize():run.call_deferred()
func run():
	root.size=Vector2i(1800,1100)
	var g=load("res://scenes/main.tscn").instantiate();root.add_child(g)
	await create_timer(.5).timeout
	g.set_process(false);g.motor.set_physics_process(false);g.hud.hide();g.avatar.hide();g.fish_guide.hide();g.rod.hide()
	g.head.fov=55;g.head.rotation.x=-.04
	for entry in g.Locations.CATALOG:
		g._select_location(entry.id,false)
		for enhanced in [false,true]:
			for material in [g.panorama_material,g.water_material]:
				material.set_shader_parameter("detail_strength",.5 if enhanced else 0.0)
				material.set_shader_parameter("vibrance",1.025 if enhanced else 1.0)
				material.set_shader_parameter("shadow_lift",.015 if enhanced else 0.0)
			for i in 16:await process_frame
			await RenderingServer.frame_post_draw
			var path="res://test-results/panorama-8k/"+entry.id+("-enhanced" if enhanced else "-original")+".png"
			root.get_texture().get_image().save_png(path)
			print("PANORAMA_RENDER ",entry.id," enhanced=",enhanced," source=",g.panorama_material.panorama.get_size())
	g.queue_free();await process_frame;await create_timer(.3).timeout;quit()
