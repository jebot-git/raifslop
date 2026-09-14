extends SceneTree
var effect=preload("res://tests/xr_capture.gd").new()
func _initialize():run.call_deferred()
func run():
	var g=load("res://scenes/main.tscn").instantiate();root.add_child(g);current_scene=g
	await create_timer(2).timeout
	if not g.xr:push_error("OpenXR failed");quit(1);return
	g.set_process(false);g.motor.set_physics_process(false);g.game.reset();g.casting=false
	g.hud.hide();g.avatar_panel.hide()
	var compositor=Compositor.new();compositor.compositor_effects=[effect];g.head.compositor=compositor
	for entry in g.Locations.CATALOG:
		if not g._select_location(entry.id,false):push_error("Location failed");quit(1);return
		for i in 180:
			g.tracking_manager.sample(1.0/72);g._update_avatar(1.0/72)
			await process_frame
		print("LIVE_8K ",JSON.stringify({"location":entry.id,"size":str(g.panorama_material.panorama.get_size()),"fps":Engine.get_frames_per_second(),"focused":g.tracking_manager.focused,"head":g.tracking_manager.head_tracked(),"left":g.left.get_has_tracking_data(),"right":g.right.get_has_tracking_data(),"sharpness":g.panorama_material.get_shader_parameter("detail_strength")}))
		effect.request_capture(entry.id)
		for i in 180:
			await process_frame
			if effect.completed==entry.id:break
		if effect.completed!=entry.id or effect.views!=2:push_error("Stereo capture failed");quit(1);return
		for eye in 2:
			var frame:Image=effect.results[eye];frame.convert(Image.FORMAT_RGBA8);frame.linear_to_srgb()
			frame.save_png("res://test-results/panorama-8k/"+entry.id+"-live-eye%d.png"%eye)
	g.head.compositor=null;g.queue_free();await process_frame;await create_timer(.3).timeout
	print("LIVE_8K_RESULT PASS");quit()
