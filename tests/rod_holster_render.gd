extends SceneTree
func _initialize():run.call_deferred()
func run():
	root.size=Vector2i(1400,1100)
	var g=load("res://scenes/main.tscn").instantiate();root.add_child(g)
	await create_timer(.4).timeout
	g.set_process(false);g.motor.set_physics_process(false);g.hud.hide();g.fish_guide.hide()
	g.game.reset();g.rod_holster.update_holster();g.rod_holster.set_stowed(true)
	g.avatar.first_person=false
	for mesh in g.avatar.find_children("*","MeshInstance3D",true,false):mesh.layers=1 if mesh.layers&4 else 0
	var camera=Camera3D.new();g.add_child(camera);camera.current=true
	var hip:Vector3=g.rod_holster.belt_pose.origin
	camera.global_position=hip+Vector3(1.2,.25,1.6);camera.look_at(hip+Vector3(-.12,-.1,0));camera.fov=45
	for i in 24:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/vr-fixes/rod-holster-worn.png")
	g.queue_free();await process_frame;await create_timer(.3).timeout;quit()
