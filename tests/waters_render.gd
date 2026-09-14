extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var g=load("res://scenes/main.tscn").instantiate();root.add_child(g)
	await create_timer(.5).timeout
	g.set_process(false);g.motor.set_physics_process(false)
	g.hud.hide();g.rod.hide();g.avatar.hide();g.fish_guide.hide();g.rod_status.hide();g.bobber.hide()
	for child in g.get_children():
		if child is MeshInstance3D and child.mesh==g.line_mesh:child.hide()
	for entry in g.Locations.CATALOG:
		g._select_location(entry.id,false)
		g.head.rotation=Vector3(-.13,0,0)
		for i in 12:await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://test-results/live-analytics/"+entry.id+"-wildlife.png")
	g._select_location("lake_pier",false)
	for yaw in [-1.1,0.0,1.1]:
		g.head.rotation=Vector3(-.13,yaw,0)
		for i in 8:await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://test-results/live-analytics/pier-water-fixed-"+str(yaw)+".png")
	g._quit_game()
