extends SceneTree
## Run with a display, --xr-mode off and an isolated XDG_DATA_HOME.
func _initialize() -> void: run.call_deferred()

func run() -> void:
	var g=load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	await create_timer(.5).timeout
	g.set_process(false)
	g.motor.set_physics_process(false)
	for item in [g.hud,g.rod,g.avatar,g.fish_guide,g.rod_status,g.bobber]: item.hide()
	if not g._select_location("lake_pier",false):
		quit(1)
		return
	var output := "res://test-results/pier-water"
	DirAccess.make_dir_recursive_absolute(output)
	var views := [
		["front",Vector3(0,1.67,1.3),Vector3(-.13,0,0)],
		["left",Vector3(0,1.67,1.3),Vector3(-.3,PI/2,0)],
		["rear",Vector3(0,1.67,1.3),Vector3(-.2,PI,0)],
		["edge",Vector3(4.6,1.67,-2.6),Vector3(-.7,-.6,0)],
		["seated",Vector3(0,1.1,1.3),Vector3(-.13,0,0)],
		["foundation",Vector3(8,.25,-7),Vector3.ZERO],
	]
	for view in views:
		g.head.global_position=view[1]
		g.head.rotation=view[2]
		if view[0]=="foundation": g.head.look_at(Vector3(0,-.4,0))
		for i in 12: await process_frame
		await RenderingServer.frame_post_draw
		if root.get_texture().get_image().save_png(output+"/"+view[0]+".png")!=OK:
			quit(1)
			return
	print("PIER_WATER_RENDER_RESULT: 6 viewpoints captured")
	g._quit_game()
