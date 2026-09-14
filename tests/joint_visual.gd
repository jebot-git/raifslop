extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size=Vector2i(1200,1200)
	var world:=Node3D.new();root.add_child(world)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("263c38")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.8
	world.add_child(environment)
	var camera:=Camera3D.new();world.add_child(camera);camera.cull_mask=4;camera.fov=35;camera.current=true
	var light:=DirectionalLight3D.new();world.add_child(light);light.rotation_degrees=Vector3(-35,-25,0)
	var library=preload("res://scripts/avatar_library.gd").new()
	for path in library.DEFAULTS:
		var avatar=preload("res://scripts/avatar_rig.gd").new();world.add_child(avatar)
		var model:Node3D=library.load_model(path);avatar.add_child(model);avatar.configure(model)
		avatar.xr_pose={"head":Transform3D(Basis.IDENTITY,Vector3(0,1.65,0)),"left":Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3(-.3,1.1,-.3)),"right":Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3(.3,1.1,-.3)),"body":{"left_curls":PackedFloat32Array([.85,.5,.7,.7,.7]),"right_curls":PackedFloat32Array([.85,.5,.7,.7,.7])}}
		for pose in ["front","side","hands","raised","crouch","ankles"]:
			camera.position=Vector3(0,1.2,-2.7);camera.look_at(Vector3(0,.88,0))
			if pose=="side":camera.position=Vector3(2,1.2,-2);camera.look_at(Vector3(0,.9,0))
			if pose=="hands":camera.position=Vector3(0,1.25,-1.0);camera.look_at(Vector3(-.10,1.09,-.28));camera.fov=50
			else:camera.fov=35
			if pose=="raised":avatar.xr_pose.left.origin=Vector3(-.2,1.8,-.1);avatar.xr_pose.left.basis=Basis(Vector3.FORWARD,PI/2)
			if pose=="crouch":
				avatar.xr_pose.head.origin.y=1.2;avatar.xr_pose.left.origin=Vector3(-.3,.9,-.3)
				avatar.xr_pose.body.hips=Transform3D(Basis(Vector3.UP,.5),Vector3(0,.65,0))
			if pose=="ankles":
				camera.position=Vector3(.5,.3,-.7);camera.look_at(Vector3(0,.18,0));camera.fov=50
			for i in 8:await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://test-results/vr-fixes/joints-"+path.get_file().get_basename()+"-"+pose+".png")
		avatar.queue_free();await process_frame
	world.queue_free();await process_frame
	quit()
