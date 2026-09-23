extends SceneTree
var failures: Array = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures.append(label)
func run() -> void:
	var output := OS.get_environment("GOLF_VALIDATION_OUTPUT")
	if output.is_empty(): output = "user://golf-validation"
	DirAccess.make_dir_recursive_absolute(output)
	var g = load("res://scenes/main.tscn").instantiate(); root.add_child(g); current_scene = g
	await create_timer(2).timeout
	check(g.xr, "Exported build initializes the connected OpenXR runtime")
	if not g.xr: quit(1); return
	var capture = load(get_script().resource_path.get_base_dir().path_join("xr_capture.gd")).new()
	var compositor := Compositor.new(); compositor.compositor_effects = [capture]; g.head.compositor = compositor
	var readings: Array = []
	for id in ["cypress","poppy"]:
		await g.golf_activity.join_course(id)
		await create_timer(2).timeout
		check(g.golf_activity.active and g.golf_activity.golf.course_id==id, id+" loads in the exported build")
		g.golf_activity.start_play("solo")
		await create_timer(2).timeout
		for sample in 3:
			await create_timer(2).timeout
			var row := {"course":id,"fps":Engine.get_frames_per_second(),"head":g.tracking_manager.head_tracked(),"left":g.left.get_has_tracking_data(),"right":g.right.get_has_tracking_data(),"focused":g.tracking_manager.focused,"hips":g.tracking_manager.body.has("hips"),"hip_collision":g.motor.tracked_hip is Transform3D}
			readings.append(row); print("GOLF_LIVE ",JSON.stringify(row))
		check(readings.back().head and readings.back().focused,id+" receives focused native head tracking")
		check(readings.back().hips and readings.back().hip_collision,id+" uses native hip tracking for collision")
		capture.request_capture(id)
		for frame in 240:
			await process_frame
			if capture.completed==id:break
		check(capture.completed==id and capture.views==2,id+" renders two native eyes")
		if capture.completed==id and capture.views==2:
			for eye in 2:
				var frame:Image=capture.results[eye];frame.convert(Image.FORMAT_RGBA8);frame.linear_to_srgb()
				frame.save_png(output.path_join("%s-eye%d.png"%[id,eye]))
		g.golf_activity.leave();await process_frame
	FileAccess.open(output.path_join("readings.json"),FileAccess.WRITE).store_string(JSON.stringify({"readings":readings,"failures":failures},"\t"))
	g.head.compositor=null;g.ambience.stop();g.queue_free();await process_frame;await create_timer(.4).timeout
	print("GOLF_LIVE_RESULT ",failures);quit(0 if failures.is_empty() else 1)
