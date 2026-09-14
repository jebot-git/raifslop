extends SceneTree
var failures: Array = []
func _initialize() -> void: run.call_deferred()
func capture(path: String) -> void:
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/vr-fixes/"+path+".png")
func run() -> void:
	root.size = Vector2i(1440,900)
	var g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g);current_scene=g
	for i in 12: await process_frame
	g._toggle_avatar_menu()
	for id in g.avatar_menu.pages:
		g.avatar_menu.show_page(id)
		await capture("menu-"+id)
		g.avatar_menu.scroll_page(10000)
		await capture("menu-"+id+"-bottom")
		if g.avatar_menu.size.y>700: failures.append("Menu exceeds bounds: "+id)
	g.queue_free();await process_frame;await create_timer(.15).timeout
	var world := Node3D.new();root.add_child(world)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("263c38")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.8
	world.add_child(environment)
	var camera:=Camera3D.new();world.add_child(camera);camera.cull_mask=4;camera.position=Vector3(0,1.3,-4.5);camera.look_at(Vector3(0,.8,0));camera.current=true
	var light:=DirectionalLight3D.new();world.add_child(light);light.rotation_degrees=Vector3(-35,-25,0)
	var library=preload("res://scripts/avatar_library.gd").new()
	var avatars: Array=[]
	for i in library.DEFAULTS.size():
		var avatar=preload("res://scripts/avatar_rig.gd").new();world.add_child(avatar)
		var model: Node3D=library.load_model(library.DEFAULTS[i]);avatar.add_child(model)
		if not avatar.configure(model): failures.append("Avatar configure failed");continue
		avatar.render_frame=Transform3D(Basis(Vector3.UP,.25),Vector3((i-1)*1.3,0,0));avatar.global_transform=avatar.render_frame
		avatar.xr_pose={"head":Transform3D(Basis.IDENTITY,Vector3(0,1.65,0)),"left":Transform3D(Basis.from_euler(Vector3(.3,.6,.4)),Vector3(-.3,1.1,-.3)),"right":Transform3D(Basis.from_euler(Vector3(.3,.6,.4)),Vector3(.3,1.1,-.3)),"body":{"left_curls":PackedFloat32Array([.2,.2,.6,.6,.6]),"right_curls":PackedFloat32Array([.2,.2,.6,.6,.6])}}
		avatars.append(avatar)
	await capture("avatars-standing")
	for avatar in avatars:
		avatar.xr_pose.head.origin.y=1.2
		avatar.xr_pose.left.origin.y=.9;avatar.xr_pose.right.origin.y=.9
		avatar.xr_pose.body.hips=Transform3D(Basis.IDENTITY,Vector3(0,.65,0))
		avatar.xr_pose.body.left_foot=Transform3D(Basis.IDENTITY,Vector3(-.13,.25,-.18))
		avatar.xr_pose.body.right_foot=Transform3D(Basis.IDENTITY,Vector3(.13,.08,0))
	await capture("avatars-tracked-crouch")
	world.queue_free();await process_frame
	print("VR_VISUAL_RESULT ",failures);quit(0 if failures.is_empty() else 1)
