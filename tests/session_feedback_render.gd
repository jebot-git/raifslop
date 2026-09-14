extends SceneTree
func _initialize():run.call_deferred()
func run():
	var g=load("res://scenes/main.tscn").instantiate();root.add_child(g);current_scene=g
	await create_timer(1).timeout
	g.set_process(false);g.motor.set_physics_process(false);g.hud.hide()
	g.game.reset();g.game.bait=0;g._select_bait(2);g._update_line();g.rod_status.remaining=100
	g.head.position=Vector3(.70,1.80,-.05)
	g.head.look_at(g.tip.global_position.lerp(g.rod.global_position,.5))
	g._update_avatar(.02)
	for frame in 8:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/live-analytics/ready-rod.png")
	g.fish_guide.held=true;var photo=g.fish_guide.photo_camera;photo.active=true
	await photo.capture()
	if photo.last_path.is_empty() or not FileAccess.file_exists(photo.last_path):push_error("Picture save failed");quit(1);return
	var decoded:=Image.load_from_file(photo.last_path)
	if decoded.get_size()!=photo.PHOTO_SIZE:push_error("Photo size wrong");quit(1);return
	print("PHOTO_RENDER_PASS ",photo.last_path)
	g._quit_game()
