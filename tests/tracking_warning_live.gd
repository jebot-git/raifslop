extends SceneTree
func _initialize():run.call_deferred()
func run():
	var g=load("res://scenes/main.tscn").instantiate();root.add_child(g)
	await create_timer(2).timeout
	if not g.xr:push_error("OpenXR unavailable");quit(1);return
	var failures:=0;var tracked_samples:=0
	for i in 10:
		await create_timer(1).timeout
		var both:bool=g.left.get_has_tracking_data() and g.right.get_has_tracking_data()
		if both:tracked_samples+=1
		if both and g.hud.tracking_lost:failures+=1
		print("TRACKING_LIVE ",JSON.stringify({"left":g.left.get_has_tracking_data(),"right":g.right.get_has_tracking_data(),"focused":g.tracking_manager.focused,"warning":g.hud.tracking_lost,"fps":Engine.get_frames_per_second()}))
	print("TRACKING_LIVE_RESULT ",failures," failures; ",tracked_samples," samples with both controllers tracked")
	g.queue_free();await process_frame;await create_timer(.3).timeout
	quit(0 if failures==0 else 1)
