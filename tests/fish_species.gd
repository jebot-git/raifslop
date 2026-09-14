extends SceneTree
## Real scene integration: model loading, size, replacement and journal persistence.
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

func bounds(node: Node3D, relative := Transform3D.IDENTITY) -> AABB:
	var transform := relative * node.transform
	var result := AABB()
	if node is MeshInstance3D:
		result = transform * node.get_aabb()
	for child in node.get_children():
		if child is Node3D:
			var child_bounds := bounds(child, transform)
			if child_bounds.has_volume():
				result = result.merge(child_bounds) if result.has_volume() else child_bounds
	return result

func run() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	var g = scene.instantiate()
	root.add_child(g)
	current_scene = g
	for i in range(12): await process_frame
	g.set_process(false)
	# Run with a separate XDG_DATA_HOME to preserve personal catches.
	g.game.journal.clear()
	for index in range(Session.SPECIES.size()):
		var species: Dictionary = Session.SPECIES[index]
		g.game.fish_index = index
		g.game.journal.append(species.duplicate())
		g._show_fish()
		await process_frame
		check(g.fish_display.visible and g.fish_display.get_child_count() > 0, "Catch model visible: " + species.name)
		var box := bounds(g.fish_display)
		check(box.has_volume() and box.size.is_finite(), "Catch mesh has finite volume: " + species.name)
		if species.has("model"):
			check(g.fish_display.get_child_count() == 1, "Previous model removed before new catch")
			check(absf(box.size.x - species.length / 100.0) < .02, "Model matches catch length: " + species.name)
			check(box.size.y < box.size.x and box.size.z < box.size.x, "Fish stays upright and lengthwise on X")
			var authored: PackedScene = load(species.model)
			var asset := authored.instantiate() as Node3D
			check(asset.find_child("Cube", true, false) == null, "Export contains no unrelated Blender cube")
			var has_textured_skin := false
			for mesh_node in asset.find_children("*", "MeshInstance3D", true, false):
				for surface in range(mesh_node.mesh.get_surface_count()):
					var uv = mesh_node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_TEX_UV]
					var mat = mesh_node.mesh.surface_get_material(surface)
					if uv != null and not uv.is_empty() and mat is BaseMaterial3D:
						has_textured_skin = has_textured_skin or mat.albedo_texture != null
			check(has_textured_skin, "Imported fish has UV-mapped skin texture")
			asset.free()
	g._save_journal()
	g.game.journal.clear()
	g._load_journal()
	check(g.game.journal.size() == Session.SPECIES.size(), "All species persist through real journal save/load")
	check(g.game.journal.back().latin == Session.SPECIES.back().latin, "Saved catch retains scientific identity")
	if "--capture" in OS.get_cmdline_user_args():
		g.game.fish_index = 6
		g.game.journal.append(Session.SPECIES[6].duplicate())
		g._show_fish()
		g.game.state = Session.State.LANDED
		g.game.bait = 2
		g.game.message = "Zander · 60 cm · 2.00 kg\nSander lucioperca · Release to fish again."
		g.last_state = Session.State.LANDED
		g.time = 0.0
		g.set_process(true)
		g.hud.queue_redraw()
		for i in range(8): await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://docs/zander_catch.png") == OK, "Runtime catch screenshot saved")
	print("Fish species integration: %d checks, %d failures" % [checks, failures])
	g.queue_free()
	await process_frame
	await create_timer(.3).timeout
	quit(1 if failures else 0)
