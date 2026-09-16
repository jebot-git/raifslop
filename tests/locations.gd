extends SceneTree
const Locations = preload("res://scripts/locations.gd")
const Session = preload("res://scripts/fishing_session.gd")
var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func capture(path: String) -> void:
	for i in range(8):
		current_scene._layout_avatar_menu()
		await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(path) == OK, "Location screenshot saved")

func run() -> void:
	# Use a dedicated XDG_DATA_HOME: this suite exercises persistent preferences.
	var invalid := ConfigFile.new()
	invalid.set_value("location", "id", "removed_location")
	invalid.save(Locations.SAVE_PATH)
	check(Locations.saved_location() == Locations.DEFAULT_ID, "Stale saved location falls back to Lakeside")
	var packed: PackedScene = load("res://scenes/main.tscn")
	var g = packed.instantiate()
	root.add_child(g)
	current_scene = g
	for i in range(12): await process_frame
	g.set_process(false)
	g.motor.set_physics_process(false)
	var count: int = g.get_child_count()

	var journal_before: Array = g.game.journal.duplicate(true)
	for entry in Locations.CATALOG:
		check(g._select_location(entry.id), "Can visit " + entry.name)
		check(g.current_location == entry.id and g.game.location_name == entry.name, "Active location and HUD identity agree")
		var texture: Texture2D = g.panorama_material.panorama
		check(texture.get_width() == 8192 and texture.get_height() == 4096, "Sky uses bounded 2:1 native 8K panorama")
		check(Locations.saved_location() == entry.id, "Location selection survives preference reload")
		check(is_equal_approx(g.location_sun.light_energy, entry.sun_energy), "Location sunlight is applied")
		check(g.water_material.get_shader_parameter("deep_color") == entry.water, "Location water colour is applied")
		check(g.get_child_count() == count and g.foreground.get_meta("location_id") == entry.id and g.motor.global_position == g.foreground.get_meta("spawn"), "Travel replaces foreground and places player at safe arrival")
		check(g.game.journal == journal_before, "Travel preserves existing catches")
		if entry.id in ["lakeside", "gray_pier", "bell_park_pier"]:
			var distant_vertices := 0
			for node in g.foreground.find_children("*", "MeshInstance3D", true, false):
				for surface in node.mesh.get_surface_count():
					var material: Material = node.mesh.surface_get_material(surface)
					if not material or not material.resource_name.begins_with("FG_bank"): continue
					for vertex in node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
						var point: Vector3 = node.global_transform * vertex
						if maxf(absf(point.x),point.z) >= 100:
							distant_vertices += 1
							check(point.y <= -.399, "Far land meets the water horizon: " + entry.id)
			check(distant_vertices > 0, "Distant land geometry exercised: " + entry.id)
		var preview: Texture2D = load(entry.preview)
		check(preview.get_width() <= 768, "Menu uses a small preview")
		if "--capture" in OS.get_cmdline_user_args():
			await capture("res://docs/locations/" + entry.id + ".png")
	var current: String = g.current_location
	var old_texture: Texture2D = g.panorama_material.panorama
	check(not g._select_location("missing"), "Unknown locations rejected")
	check(g.current_location == current and g.panorama_material.panorama == old_texture, "Rejected location preserves active sky")
	for state in [Session.State.CASTING, Session.State.WAITING, Session.State.BITE, Session.State.FIGHT, Session.State.LANDED, Session.State.LOST]:
		g.game.state = state
		check(not g._select_location(Locations.DEFAULT_ID) and g.current_location == current, "Travel cannot interrupt an active or unreleased cast")
	g.game.reset()
	g.casting = true
	check(not g._select_location(Locations.DEFAULT_ID), "Travel cannot interrupt a held casting gesture")
	g.casting = false
	g._toggle_avatar_menu()
	g.avatar_menu.show_locations()
	check(g.menu_open and g.motor.blocked and g.avatar_menu.locations_page.visible, "Locations share paused desktop/VR menu")
	g.avatar_menu.location_list.select(1)
	g.avatar_menu._preview_location(1)
	g.avatar_menu.visit_button.pressed.emit()
	check(g.current_location == "lake_pier" and not g.menu_open and not g.motor.blocked, "Fish here travels and automatically closes menu")
	g._toggle_avatar_menu()
	for i in range(8):
		g._layout_avatar_menu()
		await process_frame
	var menu_rect: Rect2 = g.avatar_menu.get_global_rect()
	check(menu_rect.position.x >= 0 and menu_rect.position.y >= 0 and menu_rect.end.x <= root.get_visible_rect().size.x and menu_rect.end.y <= root.get_visible_rect().size.y, "Menu remains within the desktop viewport")
	if "--capture" in OS.get_cmdline_user_args(): await capture("res://docs/locations/menu.png")
	g._toggle_avatar_menu()
	check(not g.menu_open and not g.motor.blocked, "Closing menu resumes movement")
	# New catch entries retain the location context alongside the real species.
	g.game.state = Session.State.BITE
	g.game.strike()
	g.game.distance = 1.0
	g.game.stamina = .2
	g.game.cue = -1
	g.game.tick(.01, .5, 0)
	check(not g.game.journal.is_empty(), "Retrieving the exhausted fish records a catch")
	if g.game.journal.is_empty():
		g.queue_free();await process_frame;quit(1);return
	check(g.game.journal.back().location_id == "lake_pier", "Catch journal records the fishing location")
	g._save_journal()
	g.game.journal.clear()
	g._load_journal()
	check(g.game.journal.back().location_name == "Lake Pier", "Location survives journal save/load")
	print("Location tests: %d checks, %d failures" % [checks, failures])
	g.queue_free();await process_frame;await create_timer(.3).timeout
	quit(1 if failures else 0)
