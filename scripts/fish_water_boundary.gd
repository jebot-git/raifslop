extends RefCounted
## Vertical exclusion around the actual ground/deck/rock footprint, at every depth.
## A small spatial grid keeps checks local even for the scanned coastal rocks.
const CELL := 4.0
var ground_faces: Array[PackedVector3Array] = []
var minimum_height := -INF
var triangles: Array[PackedVector2Array] = []
var bounds: Array[Rect2] = []
var cells: Dictionary = {}
func rebuild(root: Node3D, height := -INF) -> void:
	ground_faces.clear()
	minimum_height = height
	triangles.clear(); bounds.clear(); cells.clear()
	_collect(root)
func set_minimum_height(height: float) -> void:
	if is_equal_approx(height, minimum_height): return
	minimum_height = height
	triangles.clear(); bounds.clear(); cells.clear()
	for face in ground_faces: _project_face(face)
func _project_face(face: PackedVector3Array) -> void:
	# Deep seabed can remain beneath open water; clip at the fish's deepest
	# possible body extent, then extrude the resulting shoreline vertically.
	var clipped := PackedVector3Array()
	for i in 3:
		var a := face[i]; var b := face[(i+1)%3]
		var inside_a := a.y >= minimum_height; var inside_b := b.y >= minimum_height
		if inside_a: clipped.append(a)
		if inside_a != inside_b:
			clipped.append(a.lerp(b, (minimum_height-a.y)/(b.y-a.y)))
	for i in range(1,clipped.size()-1):
		add_triangle(PackedVector2Array([Vector2(clipped[0].x,clipped[0].z),Vector2(clipped[i].x,clipped[i].z),Vector2(clipped[i+1].x,clipped[i+1].z)]))
func _collect(node: Node) -> void:
	if node is MeshInstance3D and node.mesh != null and node.visible:
		for surface in node.mesh.get_surface_count():
			var mat: Material = node.mesh.surface_get_material(surface)
			var name_: String = mat.resource_name if mat != null else ""
			var ground: bool = node.get_meta("fish_ground", false)
			for prefix in ["FG_bank", "FG_sand", "FG_stone", "FG_gravel", "FG_concrete", "FG_weathered", "FG_timber", "FG_wood_end", "FG_paint", "FG_rubber", "FG_steel"]:
				ground = ground or name_.begins_with(prefix)
			if not ground: continue
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			for i in range(0, indices.size() if not indices.is_empty() else vertices.size(), 3):
				var face := PackedVector3Array()
				for corner in 3:
					var at: Vector3 = node.global_transform * vertices[indices[i+corner] if not indices.is_empty() else i+corner]
					face.append(at)
				ground_faces.append(face); _project_face(face)
	for child in node.get_children(): _collect(child)
func segment_obstructed(start: Vector3, end: Vector3) -> bool:
	# Use the same authored triangles before physics has registered a newly
	# loaded location. This keeps feeding targets out from behind nearby rocks.
	for face in ground_faces:
		if Geometry3D.segment_intersects_triangle(start,end,face[0],face[1],face[2]) != null: return true
	return false

func add_triangle(tri: PackedVector2Array) -> void:
	if absf((tri[1]-tri[0]).cross(tri[2]-tri[0])) < .000001: return
	var box := Rect2(tri[0], Vector2.ZERO).expand(tri[1]).expand(tri[2])
	var index := triangles.size(); triangles.append(tri); bounds.append(box)
	for x in range(floori(box.position.x / CELL), floori(box.end.x / CELL)+1):
		for y in range(floori(box.position.y / CELL), floori(box.end.y / CELL)+1):
			var key := Vector2i(x,y)
			if not cells.has(key): cells[key] = []
			cells[key].append(index)
func blocked(at: Vector3, radius: float) -> bool:
	if not at.is_finite(): return true
	var point := Vector2(at.x, at.z)
	var seen := {}
	for x in range(floori((point.x-radius)/CELL), floori((point.x+radius)/CELL)+1):
		for y in range(floori((point.y-radius)/CELL), floori((point.y+radius)/CELL)+1):
			for index in cells.get(Vector2i(x,y), []):
				if seen.has(index): continue
				seen[index] = true
				if not bounds[index].grow(radius).has_point(point): continue
				var tri := triangles[index]
				if Geometry2D.is_point_in_polygon(point, tri): return true
				for edge in 3:
					if Geometry2D.get_closest_point_to_segment(point,tri[edge],tri[(edge+1)%3]).distance_squared_to(point) <= radius*radius: return true
	return false
func clip_motion(start: Vector3, end: Vector3, radius: float) -> Vector3:
	# Sweep the entire move: endpoint-only checks tunnel through a narrow pier.
	if not start.is_finite() or not end.is_finite(): return start
	var steps := maxi(1, ceili(Vector2(end.x-start.x,end.z-start.z).length() / maxf(.08, radius*.5)))
	var previous := start
	for i in range(1, steps+1):
		var candidate := start.lerp(end, float(i)/steps)
		if blocked(candidate, radius):
			var low := previous; var high := candidate
			for iteration in 12:
				var middle := low.lerp(high,.5)
				if blocked(middle,radius): high = middle
				else: low = middle
			return low
		previous = candidate
	return end
func recover(at: Vector3, away: Vector3, radius: float) -> Vector3:
	if not blocked(at,radius): return at
	# Used for a larger predator taking over, or a restored/externally set pose.
	away.y=0
	if away.length_squared()<.001: away=Vector3.FORWARD
	for distance in range(1,121):
		for angle in [0.0, PI/4, -PI/4, PI/2, -PI/2, PI]:
			var candidate := at + away.normalized().rotated(Vector3.UP,angle)*distance*.25
			if not blocked(candidate,radius+.01): return candidate
	return at
