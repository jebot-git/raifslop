extends SceneTree
func _initialize()->void:run.call_deferred()
func run()->void:
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await create_timer(1).timeout
	await game.golf_activity.join_course("spyglass")
	await create_timer(2).timeout
	var a=game.golf_activity
	game.motor.set_physics_process(false)
	await RenderingServer.frame_post_draw
	a.clubhouse_board.viewport.get_texture().get_image().save_png("res://test-results/clubhouse-board.png")
	game.head.look_at(a.clubhouse_board.global_position,Vector3.UP)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/clubhouse-arrival.png")
	var centre:=Vector2.ZERO
	for b in a.clubhouse_board.viewport.find_children("*","Button",true,false):
		if b.text=="Start new solo round":centre=b.get_global_rect().get_center()
	var hit:Vector3=a.clubhouse_board.to_global(Vector3((centre.x/960-.5)*3,(.5-centre.y/640)*2,0))
	var tracker:=XRControllerTracker.new();tracker.name="clubhouse_visual_right";XRServer.add_tracker(tracker)
	game.right.tracker=tracker.name;game.right.pose="grip";game.xr=true;game.tracking_manager.focused=true
	var pose:=Transform3D(game.origin.global_basis.inverse(),game.origin.to_local(hit+Vector3(0,0,1)))
	for name in ["aim","grip"]:tracker.set_pose(name,pose,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	for i in 4:await process_frame
	tracker.set_input("trigger_click",true)
	await process_frame;await process_frame
	tracker.set_input("trigger_click",false)
	await process_frame;await process_frame
	XRServer.remove_tracker(tracker)
	if a.clubhouse_round!=null:push_error("Wall panel click did not start solo play")
	else:print("PASS wall-mounted pointer selects solo play")
	a.golf.course_guide.screen.refresh()
	await RenderingServer.frame_post_draw
	# Use the existing shared quit path so audio and profile writes complete.
	a.leave();game._quit_game()
