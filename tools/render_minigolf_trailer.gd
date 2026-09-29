extends SceneTree

# Deterministic 30 fps captures of the production scene; encode with ffmpeg.
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var id: String = args[0]
	var mode: String = args[1]
	preload("res://scripts/locations.gd").save_location(id)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var game = load("res://scenes/main.tscn").instantiate()
	viewport.add_child(game)
	await create_timer(.5).timeout
	game.set_process(false)
	game.motor.set_physics_process(false)
	game.hud.hide()
	game.rod_holster.set_stowed(true)
	if is_instance_valid(game.avatar): game.avatar.hide()
	var activity = game.golf_activity
	if mode == "bbq":
		game.bbq.visit()
	else:
		activity.enter(id)
		activity.set_process(false)
		activity.set_physics_process(false)
		activity.club.hide()
		activity.readout.hide()
		activity.ball_label.hide()
	game.head.fov = 65
	var folder := "res://test-results/minigolf-trailer/" + id + "-" + mode
	DirAccess.make_dir_recursive_absolute(folder)
	await create_timer(1).timeout
	for frame in 240:
		var t := frame / 239.0
		if mode == "bbq":
			var center: Vector3 = game.bbq.station.global_position
			game.head.global_position = center + Vector3(2.4 - t * 1.4, 1.8, 2.8)
			game.head.look_at(center + Vector3(0, .8, 0))
		else:
			var origin: Vector3 = preload("res://scripts/minigolf/catalog.gd").origin(0)
			game.head.global_position = origin + Vector3(4.5 - 2 * t, 2.3, 1 - t * 2)
			game.head.look_at(origin + Vector3(0, .15, -4))
			if frame == 35: activity.request_putt(activity.aim * 2.7)
			activity._physics_process(1.0 / 30)
			activity.update_ball()
			activity.ball_label.hide()
		await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = viewport.get_texture().get_image()
		image.convert(Image.FORMAT_RGB8)
		assert(image.save_jpg(folder + "/%04d.jpg" % frame, .96) == OK)
	print("TRAILER_CAPTURE ", id, " ", mode, " 240 frames")
	game.ambience.stop()
	game.queue_free()
	await process_frame
	quit()
