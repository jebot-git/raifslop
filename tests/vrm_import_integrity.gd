extends SceneTree
const Library = preload("res://scripts/avatar_library.gd")
const Bounds = preload("res://scripts/avatar_rest_bounds.gd")
var failures: Array[String] = []
func _initialize() -> void: run.call_deferred()
func vertices(model: Node3D, imported: bool) -> Dictionary:
	var transforms: Dictionary = {}
	Bounds.collect(model, model.transform, transforms)
	var result: Dictionary = {}
	for node in transforms:
		if not node is MeshInstance3D or not node.mesh: continue
		if imported and not node.layers & 4: continue
		var sk: Skeleton3D = node.get_node_or_null(node.skeleton)
		var palette: Array[Transform3D] = []
		if node.skin and sk:
			for bind in node.skin.get_bind_count():
				var bone: int = sk.find_bone(node.skin.get_bind_name(bind)) if not node.skin.get_bind_name(bind).is_empty() else node.skin.get_bind_bone(bind)
				if bone < 0: failures.append("Unresolved skin bind"); return {}
				palette.append(transforms[sk] * sk.get_bone_global_rest(bone) * node.skin.get_bind_pose(bind))
		for surface in node.mesh.get_surface_count():
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones = arrays[Mesh.ARRAY_BONES]
			var weights = arrays[Mesh.ARRAY_WEIGHTS]
			var posed := PackedVector3Array()
			for i in points.size():
				var p: Vector3 = transforms[node] * points[i]
				if not palette.is_empty():
					p = Vector3.ZERO
					var count: int = bones.size() / points.size()
					for j in count:
						p += palette[bones[i*count+j]] * points[i] * weights[i*count+j]
				posed.append(p)
			# VRM keeps mesh/surface ordering and vertices; head-hidden duplicates are excluded.
			result[str(node.name)+":"+str(surface)] = posed
	return result
func run() -> void:
	var library = Library.new()
	for path in Library.DEFAULTS:
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		var error := document.append_from_file(path, state, 8)
		if error != OK: failures.append("Raw glTF decode " + path); continue
		var raw := document.generate_scene(state)
		var imported: Node3D = library.load_model(path)
		var original := vertices(raw, false)
		var retargeted := vertices(imported, true)
		var maximum := 0.0
		var count := 0
		for key in original:
			if not retargeted.has(key): failures.append("Missing imported surface " + key); continue
			if original[key].size() != retargeted[key].size(): failures.append("Changed vertex count " + key); continue
			for i in original[key].size():
				# VRM 0.0 faces -Z; the importer normalizes the entire model to +Z.
				var expected: Vector3 = original[key][i] * Vector3(-1,1,-1)
				maximum = maxf(maximum, expected.distance_to(retargeted[key][i]))
				count += 1
		print("IMPORT_GEOMETRY ", path, " vertices=", count, " maximum_rest_displacement_m=", maximum)
		if count == 0 or maximum > 0.0001: failures.append("Rest mesh changed " + path)
		raw.free(); imported.free()
	await process_frame
	print("VRM_IMPORT_RESULT ", failures)
	quit(0 if failures.is_empty() else 1)
