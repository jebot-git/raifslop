extends SceneTree
func _initialize():run.call_deferred()
func capture(label:String):
	for i in 16:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/vr-fixes/feedback-"+label+".png")
func run():
	root.size=Vector2i(1600,1000)
	var g=load("res://scenes/main.tscn").instantiate();root.add_child(g)
	await create_timer(.5).timeout
	g.set_process(false);g.motor.set_physics_process(false);g.hud.hide()
	for entry in g.Locations.CATALOG:
		g._select_location(entry.id,false)
		g.head.rotation=Vector3(-.10,0,0)
		await capture("water-"+entry.id)
	g.hud.show();g.game.state=g.Session.State.FIGHT;g.game.cue=0;g.game.resistance=.62;g.game.counter_active=true;g.game.tension=.55;g.game.message="Hold the rod against the fish's pull."
	g.hud.queue_redraw();await capture("fight-desktop")
	g._toggle_avatar_menu();await capture("menu-quit")
	g._toggle_avatar_menu();g.fish_guide.held=true;g.fish_guide.selected=-1;g.fish_guide.update_device();g.hud.hide()
	await capture("guide-status")
	g.fish_guide.viewport.get_texture().get_image().save_png("res://test-results/vr-fixes/feedback-guide-screen.png")
	g.queue_free();await process_frame;await create_timer(.3).timeout;quit()
