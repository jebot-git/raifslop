extends SceneTree
func _initialize()->void:run.call_deferred()
func run()->void:
	root.size=Vector2i(1600,1100)
	for id in ["cypress","poppy"]:
		var start:=Time.get_ticks_msec()
		var model=preload("res://addons/golfminus/scripts/golf/course_model.gd").new();model.load_course(id)
		var world=preload("res://addons/golfminus/scripts/world/connected_course_world.gd").new();root.add_child(world);world.build(model)
		var light:=DirectionalLight3D.new();world.add_child(light);light.rotation_degrees=Vector3(-55,-30,0);light.light_energy=1.0
		var env:=WorldEnvironment.new();world.add_child(env);env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("162e31")
		var camera:=Camera3D.new();world.add_child(camera);camera.current=true;camera.far=5000;camera.projection=Camera3D.PROJECTION_ORTHOGONAL
		var bounds:Rect2=model.course_bounds();var center:=bounds.get_center();camera.size=maxf(bounds.size.y,bounds.size.x/1.45)*1.08
		camera.position=Vector3(center.x,2200,center.y+.01);camera.look_at(Vector3(center.x,0,center.y),Vector3.FORWARD)
		for i in 18:
			var label:=Label3D.new();label.text=str(i+1);label.font_size=64;label.pixel_size=.16;label.no_depth_test=true;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.position=model.pin_for(i)+Vector3(8,20,0);world.add_child(label)
		for frame in 5:await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/%s-connected-course.png"%id)
		print("COURSE RENDER ",id," build/render_ms=",Time.get_ticks_msec()-start," markers=",world.hole_markers.size())
		world.queue_free();await process_frame
	print("REFERENCE RENDERS COMPLETE");quit()
