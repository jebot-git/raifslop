extends SceneTree
const Session = preload("res://scripts/fishing_session.gd")
var failures: Array[String] = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label); push_error(label)
func run() -> void:
	var g=load("res://scenes/main.tscn").instantiate();root.add_child(g)
	await create_timer(.4).timeout
	g.set_process(false)
	for id in ["simons_town_rocks","blouberg_sunrise_2","secluded_beach","fish_hoek_beach","lakeside"]:
		g.game.reset();check(g._select_location(id,false),"Travel "+id)
		var marine:=Session.is_marine_location(id)
		for bait in 6:
			g.game.select_bait(bait);g.rod_status.show_bait()
			check(g.rod_status.label.text==g.game.bait_name(bait),"Rod label matches habitat")
			check(g.rod_status.bait_visual.get_meta("marine")==marine,"Tackle visual matches habitat")
			if marine:
				var part: String=["RagwormBristle","SquidStrip","MetalBlade","PrawnSegment","SardineBody","StreamerFiber"][bait]
				check(g.rod_status.bait_visual.find_child(part,true,false)!=null,"Marine bait geometry "+part)
			for index in Session.species_for_bait(bait,id):
				check((Session.SPECIES[index].get("habitat", "freshwater")=="marine")==marine,"No cross-habitat catches")
		# Travel keeps the chosen slot but must refresh its name and model.
		g.game.select_bait(1);g.rod_status.show_bait()
	check(g.rod_status.label.text=="Sweetcorn","Freshwater bait restored after marine travel")
	if "--capture" in OS.get_cmdline_user_args(): await gallery()
	print("MARINE_SPECIES_RESULT ",failures)
	g.queue_free();await process_frame;await create_timer(.3).timeout
	quit(0 if failures.is_empty() else 1)
func gallery() -> void:
	var view:=SubViewport.new();view.size=Vector2i(1400,1400);view.own_world_3d=true
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
	var env:=WorldEnvironment.new();env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("172b30")
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.75;view.add_child(env)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-30,-25,0);light.light_energy=.9;view.add_child(light)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.7
	camera.position=Vector3(0,0,4);view.add_child(camera)
	for i in 8:
		var species: Dictionary=Session.SPECIES[i+18]
		var fish=load(species.model).instantiate();fish.position=Vector3(-.66+(i%2)*1.32,1.0-(i/2)*.66,0)
		fish.rotation.y=.16;view.add_child(fish)
		var label:=Label3D.new();label.text=species.name+" · "+str(species.length)+" cm"
		label.font_size=25;label.pixel_size=.0014;label.position=fish.position+Vector3(0,-.3,.15);view.add_child(label)
	for i in 16:await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://test-results/marine-fish")
	check(view.get_texture().get_image().save_png("res://test-results/marine-fish/gallery.png")==OK,"Gallery saved")
	view.queue_free()
