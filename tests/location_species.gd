extends SceneTree
const Session = preload("res://scripts/fishing_session.gd")
const Locations = preload("res://scripts/locations.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var all_seen := {}
	var layouts := {}
	for location in Locations.CATALOG:
		var roster := Session.species_for_location(location.id, false)
		check(roster.size() >= (3 if Session.Fly.river(location.id) else 6 if Session.is_marine_location(location.id) else 10) and roster.size() == (func():
			var unique := {}
			for i in roster: unique[i] = true
			return unique.size()).call(), "Distinct local species at " + location.id)
		layouts[str(roster)] = true
		for index in roster:
			check((Session.SPECIES[index].get("habitat", "freshwater")=="marine") == Session.is_marine_location(location.id), "Habitat matches location")
		var seen := {}
		var s := Session.new()
		s.location_id = location.id
		s.rng.seed = 1773
		for bait in range(s.bait_count()):
			var pool := Session.species_for_bait(bait, location.id)
			check(not pool.is_empty(), "Bait has local fish: " + location.id + " / " + Session.BAITS[bait])
			var valid := true
			for attempt in range(160):
				s.reset()
				s.select_bait(bait)
				s.cast(12)
				s.tick(1, 0, 0)
				valid = valid and s.fish_index in roster and s.fish_index in pool
				seen[s.fish_index] = true
				all_seen[s.fish_index] = true
			check(valid, "Normal casting respects location and bait")
		check(seen.size() == roster.size(), "Every local species reachable")
	check(all_seen.size() == Session.SPECIES.filter(func(row): return not row.get("predator",false)).size(), "Every direct-bait species reachable")
	check(layouts.size() == Session.LOCATION_SPECIES.size(), "Locations have distinct rosters")
	var g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	current_scene = g
	for i in range(12): await process_frame
	g.game.reset()
	for i in range(Session.BAITS.size()):
		var event := InputEventKey.new()
		event.keycode = KEY_1 + i
		event.pressed = true
		g._unhandled_input(event)
		check(g.game.bait == i, "Desktop hotkey selects " + Session.BAITS[i])
		g.game.select_bait((i + 1) % Session.BAITS.size())
		var click := InputEventMouseButton.new()
		click.pressed = true
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = g.hud.bait_rect(i).get_center() * g.hud.scale_factor
		g.hud._gui_input(click)
		check(g.game.bait == i, "Mouse tile selects " + Session.BAITS[i])
	g.game.select_bait(0)
	for i in range(Session.BAITS.size()):
		g._left_button("ax_button")
		check(g.game.bait == (i + 1) % Session.BAITS.size(), "VR X cycles every bait and wraps")
	g.game.cast(12)
	g._left_button("ax_button")
	check(g.game.bait == 0, "Bait remains locked during active cast")
	g.game.reset()
	if "--capture" in OS.get_cmdline_user_args():
		g._select_bait(5)
		for i in range(8): await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://docs/baits_six.png") == OK, "Six-bait HUD captured")
		await gallery()
	print("Location species and bait tests: %d checks, %d failures" % [checks, failures])
	g.queue_free()
	await process_frame
	await create_timer(.3).timeout
	quit(1 if failures else 0)
func gallery() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(1200, 1000)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("172b30")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = .7
	view.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-30,-25,0)
	light.light_energy = 1.0
	view.add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.75
	camera.position = Vector3(0,0,4)
	view.add_child(camera)
	for i in range(6):
		var species: Dictionary = Session.SPECIES[i + 12]
		var fish = load(species.model).instantiate()
		fish.position = Vector3(-.66 + (i % 2) * 1.32, .86 - (i / 2) * .85, 0)
		view.add_child(fish)
		var label := Label3D.new()
		label.text = species.name + "\n" + species.latin
		label.font_size = 26
		label.pixel_size = .0014
		label.position = fish.position + Vector3(0,-.32,0)
		view.add_child(label)
	for i in range(16): await process_frame
	await RenderingServer.frame_post_draw
	check(view.get_texture().get_image().save_png("res://docs/expanded_fish.png") == OK, "Six new fish gallery captured")
	view.queue_free()
