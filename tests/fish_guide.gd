extends SceneTree
const Guide = preload("res://scripts/fish_guide.gd")
const Session = preload("res://scripts/fishing_session.gd")
var checks := 0
var failures := 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var guide := Guide.new()
	check(guide.entries.is_empty(), "No species unlocked before catching")
	var first: Dictionary = Session.SPECIES[0].duplicate()
	first.length = 30.0
	check(guide.ingest([first]), "First catch unlocks a species")
	var entry: Dictionary = guide.entries[first.latin].duplicate()
	check(entry.name == first.name and not entry.description.is_empty() and entry.length == 30.0, "Entry contains name, description and size")
	check(not guide.ingest([first]), "Equal catch does not change the record")
	first.length = 20.0
	check(not guide.ingest([first]) and guide.entries[first.latin] == entry, "Smaller catch preserves the complete entry")
	first.length = 40.0
	check(guide.ingest([first]) and guide.entries[first.latin].length == 40.0, "Larger catch raises the record")
	check(guide.entries[first.latin].name == entry.name and guide.entries[first.latin].description == entry.description, "Larger catch changes only size")
	check(not guide.ingest([null, 4, {}, {"latin": "fake", "length": 999}, {"latin": first.latin, "length": -1}, {"latin": first.latin, "length": "broken"}]), "Malformed and fictional records ignored")
	for species in Session.SPECIES:
		guide.ingest([species])
	check(guide.entries.size() == Session.SPECIES.size(), "Every real species can unlock")
	for species in Session.SPECIES:
		check(preload("res://scripts/fish_guide_icons.gd").contour(species.latin, Vector2.ZERO, 1.0).size() >= 15, "Species has an authored fish silhouette")
	guide.free()
	var g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	current_scene = g
	for i in range(12): await process_frame
	g.game.journal.clear()
	g.fish_guide.entries.clear()
	g.game.state = Session.State.BITE
	g.game.fish_index = 6
	g.game.strike()
	g.game.distance = 1.0
	g.game.stamina = 0.2
	g._process(0.01)
	check(g.game.state == Session.State.LANDED and g.fish_guide.entries.has("Sander lucioperca"), "Actual landing adds species to device")
	var best: float = g.fish_guide.entries["Sander lucioperca"].length
	g.fish_guide.entries.clear()
	g.game.journal.clear()
	g._load_journal()
	check(is_equal_approx(g.fish_guide.entries["Sander lucioperca"].length, best), "Device record survives disk save/load")
	var event := InputEventKey.new()
	event.keycode = KEY_G
	event.pressed = true
	g._unhandled_input(event)
	g._process(0.05)
	check(g.fish_guide.held and g.fish_guide.visible and not g.hud.visible, "Desktop G opens physical device for inspection")
	g._unhandled_input(event)
	g._process(0.05)
	check(not g.fish_guide.held and not g.fish_guide.visible and g.hud.visible, "G closes device and restores HUD")
	g.fish_guide.ingest(Session.SPECIES)
	g.fish_guide.page(-1)
	check(g.fish_guide.selected == Session.SPECIES.size() - 1, "Previous page wraps to final species")
	g.fish_guide.page(1)
	check(g.fish_guide.selected == -1, "Next page wraps to session status")
	if "--capture" in OS.get_cmdline_user_args():
		g.fish_guide.held = true
		for i in range(12): await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://docs/field_guide_desktop.png") == OK, "Saved desktop device capture")
		check(g.fish_guide.viewport.get_texture().get_image().save_png("res://docs/field_guide_screen.png") == OK, "Saved device screen")
	# Stop the landing tone before rapid headless teardown.
	g.audio.stop()
	g.audio.stream = null
	await process_frame
	print("Field guide tests: %d checks, %d failures" % [checks, failures])
	g.queue_free()
	await process_frame
	await create_timer(.3).timeout
	quit(1 if failures else 0)
