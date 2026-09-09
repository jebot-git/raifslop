extends RefCounted
## Authored 3D foreground. The distant photograph remains a sky, not terrain.
static func collider(root: Node3D, pos: Vector3, dimensions: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 2
	root.add_child(body)
	body.position = pos
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = dimensions
	shape.shape = box
	body.add_child(shape)
	return body

static func build(g: Node3D) -> void:
	var land_mat := ShaderMaterial.new()
	land_mat.shader = load("res://assets/environment/ground.gdshader")
	g.box(g, Vector3(0, -0.29, 9.5), Vector3(25, 0.54, 15), land_mat)
	collider(g, Vector3(0, -0.29, 9.5), Vector3(25, 0.54, 15))
	collider(g, Vector3(0, -0.10, -0.2), Vector3(3.2, 0.18, 4.2))
	var path_mat = g.material(Color("a39370"))
	g.box(g, Vector3(0, -0.01, 4), Vector3(23, 0.025, 2.0), path_mat)
	g.box(g, Vector3(0, -0.01, 9.5), Vector3(2.2, 0.025, 15), path_mat)
	var wood = g.material(Color("6b5136"))
	for x in [-12.2, 12.2]:
		collider(g, Vector3(x, 0.65, 9.5), Vector3(0.2, 1.4, 15))
		g.box(g, Vector3(x, 0.95, 9.5), Vector3(0.10, 0.10, 15), wood)
		for z in range(2, 18, 2): g.cylinder(g, Vector3(x, 0.5, z), 0.06, 1.1, wood)
	collider(g, Vector3(0, 0.65, 17), Vector3(25, 1.4, 0.2))
	g.box(g, Vector3(0, 0.95, 17), Vector3(25, 0.10, 0.10), wood)
	for x in range(-12, 13, 2): g.cylinder(g, Vector3(x, 0.5, 17), 0.06, 1.1, wood)
	# Shoreline rails leave the original dock entrance open.
	for x in [-7.0, 7.0]:
		collider(g, Vector3(x, 0.55, 2.05), Vector3(10.7, 1.2, 0.15))
		g.box(g, Vector3(x, 0.90, 2.05), Vector3(10.7, 0.10, 0.10), wood)
		for offset in range(-5, 6): g.cylinder(g, Vector3(x + offset, 0.5, 2.05), 0.05, 1.05, wood)
	# Low visible dock rails stop the capsule while leaving casts unobstructed.
	for x in [-1.57, 1.57]:
		collider(g, Vector3(x, 0.35, -0.2), Vector3(0.10, 0.8, 4.4))
		g.box(g, Vector3(x, 0.45, -0.2), Vector3(0.06, 0.08, 4.4), wood)
	collider(g, Vector3(0, 0.35, -2.4), Vector3(3.2, 0.8, 0.10))
	g.box(g, Vector3(0, 0.45, -2.4), Vector3(3.2, 0.08, 0.06), wood)
	var leaves = g.material(Color("526b39"))
	for i in range(10):
		var x := -10.0 + (i % 5) * 5.0
		var z := 9.0 + (i / 5) * 6.0
		if absf(x) < 1.5: x += 2.8
		g.cylinder(g, Vector3(x, 1.0, z), 0.16, 2.1, wood)
		collider(g, Vector3(x, 1.0, z), Vector3(0.4, 2.0, 0.4))
		for crown in range(3):
			var sphere := SphereMesh.new()
			sphere.radius = 1.1 - crown * 0.18
			sphere.height = sphere.radius * 1.8
			g.mesh_node(sphere, g, Vector3(x, 2.2 + crown * 0.65, z), leaves)
	for x in [-6.0, 6.0]:
		g.box(g, Vector3(x, 0.48, 6.3), Vector3(2.0, 0.12, 0.6), wood)
		g.box(g, Vector3(x, 0.87, 6.57), Vector3(2.0, 0.7, 0.10), wood)
		for dx in [-0.8, 0.8]: g.box(g, Vector3(x + dx, 0.22, 6.3), Vector3(0.1, 0.5, 0.5), wood)
		collider(g, Vector3(x, 0.5, 6.3), Vector3(2.0, 1.0, 0.7))
	var sign := Label3D.new()
	sign.text = "LAKESIDE TRAIL\n25 m shore walk\nB / V · Avatar & movement"
	sign.font_size = 40
	sign.pixel_size = 0.007
	g.add_child(sign)
	sign.position = Vector3(2.8, 1.4, 5.5)
	g.box(g, Vector3(2.8, 1.35, 5.54), Vector3(2.8, 1.1, 0.1), g.material(Color("1e3b30")))
	g.cylinder(g, Vector3(2.8, 0.5, 5.55), 0.07, 1.0, wood)
