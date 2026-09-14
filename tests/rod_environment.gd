extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func run() -> void:
	var g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	for i in 10: await process_frame
	for tier in 4:
		g.game.tackle.equipped = tier
		await process_frame
		check(g.rod_visual.tier == tier,"Equipped rod changes visible model")
		check(g.tip.position.is_equal_approx(Vector3(0,0,-1.68)),"Casting tip stays at authored rod end")
		check(g.crank.position.is_equal_approx(Vector3(-.085,-.075,.04)),"Crank preserves tracked reeling pivot")
		var schema = preload("res://scripts/network/state.gd")
		var state: Dictionary = schema.capture(g,1)
		check(schema.valid(state) and state.rod_tier == tier,"Rod tier and handle pose accepted by network")
		state.rod_tier=4
		check(not schema.valid(state),"Unknown remote rod rejected")
		state.rod_tier=tier;state.reel_angle=NAN
		check(not schema.valid(state),"Nonfinite remote handle rejected")
	for location in preload("res://scripts/locations.gd").CATALOG:
		g.game.reset();g._select_location(location.id,false)
		var life=g.foreground.get_node("EnvironmentalLife")
		check(life.birds.multimesh.instance_count<=7 and life.insects.multimesh.instance_count==4,"Bounded wildlife count")
		var before: Transform3D=life.birds.multimesh.get_instance_transform(0)
		life._process(10.0)
		var after: Transform3D=life.birds.multimesh.get_instance_transform(0)
		# Dummy headless RenderingServer does not retain MultiMesh transforms.
		if DisplayServer.get_name() != "headless":
			check(after.is_finite() and before.origin.distance_to(after.origin)>1,"Birds move through finite 3D positions")
		check(life.birds.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"Wildlife adds no dynamic shadows")
		check(g.panorama_material.panorama.get_size()==Vector2(8192,4096),"Native 8K panorama loaded")
	if "--capture" in OS.get_cmdline_user_args(): await capture()
	print("Rod and environment: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
func capture() -> void:
	var view:=SubViewport.new();view.size=Vector2i(1400,1000);view.own_world_3d=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("263e3f");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.8;view.add_child(env)
	var lamp:=DirectionalLight3D.new();lamp.rotation_degrees=Vector3(-45,-25,0);lamp.light_energy=1.1;view.add_child(lamp)
	var cam:=Camera3D.new();cam.projection=Camera3D.PROJECTION_ORTHOGONAL;cam.size=2.7;cam.position=Vector3(0,0,4);view.add_child(cam)
	for i in 4:
		var rod=preload("res://scripts/rod_visual.gd").new();view.add_child(rod);rod.equip(i);rod.rotation_degrees.y=90;rod.position=Vector3(.8,.95-i*.62,0)
		var label:=Label3D.new();label.text=preload("res://scripts/tackle.gd").RODS[i].name;label.font_size=24;label.pixel_size=.002;label.position=Vector3(-.3,.75-i*.62,.1);view.add_child(label)
	for i in 15: await process_frame
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png("res://docs/rods.png")
