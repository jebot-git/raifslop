extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	for id in preload("res://scripts/minigolf/catalog.gd").ALL:
		var world = preload("res://scripts/minigolf/world.gd").new()
		root.add_child(world)
		world.setup(id)
		if not world.get_meta("lightmap_applied", false):
			failures.append(id + ": missing or stale bake")
		else:
			var data = load("res://assets/minigolf/lighting/" + id + ".res")
			for texture in [data.irradiance, data.occlusion]:
				if texture == null or not texture.get_image().has_mipmaps():
					failures.append(id + ": lightmap needs mipmaps")
			for mesh in data.meshes:
				for surface in mesh.get_surface_count():
					var arrays = mesh.surface_get_arrays(surface)
					if arrays[Mesh.ARRAY_TEX_UV2].size() != arrays[Mesh.ARRAY_VERTEX].size():
						failures.append(id + ": incomplete UV2")
		print("LIGHTMAP_CHECK ", id)
		world.free()
		await process_frame
	print("MINIGOLF LIGHTMAP failures: ", failures)
	quit(0 if failures.is_empty() else 1)
