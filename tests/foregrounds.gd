extends SceneTree
const Shore = preload("res://scripts/shore.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func floor_at(g, x: float, z: float) -> Dictionary:
	return g.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, .1, z), Vector3(x, -1, z), 1))
func key(code: int, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
func run() -> void:
	var g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	current_scene = g
	for i in range(12): await process_frame
	var seen: Array = []
	for id in Shore.catalog():
		var old = g.foreground
		check(g._select_location(id, false), "Load foreground " + id)
		check(old.get_parent() == null and g.foreground != old, "Previous collision tree detached")
		check(not seen.has(g.foreground.get_child(0).scene_file_path), "Distinct model for " + id)
		seen.append(g.foreground.get_child(0).scene_file_path)
		for i in range(8): await physics_frame
		check(not floor_at(g, g.head.global_position.x, g.head.global_position.z).is_empty(), "Solid arrival floor " + id)
		key(KEY_W, true)
		var stayed_above_water := true
		for i in range(330):
			await physics_frame
			stayed_above_water = stayed_above_water and g.motor.global_position.y > -.1
		key(KEY_W, false)
		var arrival: Vector3 = g.foreground.get_meta("spawn")
		check(stayed_above_water and g.motor.global_position.z < arrival.z-1.0, "Can walk toward the protected water edge " + id)
		var stopped: Vector3 = g.motor.global_position
		key(KEY_W, true)
		for i in range(40): await physics_frame
		key(KEY_W, false)
		check(g.motor.global_position.distance_to(stopped) < .03, "Edge collision holds " + id)
		g.motor.relocate(g.foreground.get_meta("spawn"))
		if "--capture" in OS.get_cmdline_user_args():
			var camera := Camera3D.new()
			g.add_child(camera)
			camera.position = Vector3(8, 7, -9) if id != "bell_park_pier" else Vector3(5, 4, -6)
			camera.look_at(Vector3(0, 0, 3) if id == "lakeside" else Vector3.ZERO)
			camera.current = true
			g.set_process(false)
			g.avatar.hide()
			g.rod.hide()
			g.fish_guide.hide()
			g.hud.hide()
			for i in range(12): await process_frame
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png("res://docs/locations/" + id + "_foreground.png") == OK, "Saved overview " + id)
			camera.queue_free()
			g.head.current = true
			g.hud.show()
			g.avatar.show()
			g.rod.show()
			g.fish_guide.show()
			g.set_process(true)
	g._select_location("lakeside", false)
	g.motor.relocate(Vector3(6, .02, 10))
	var height: float = g.head.global_position.y - g.motor.global_position.y
	var orientation: Basis = g.head.global_basis
	g._select_location("bell_park_pier", false)
	check(Vector2(g.head.global_position.x, g.head.global_position.z).distance_to(Vector2(0, .35)) < .01, "Travel from distant shore reaches boat safely")
	check(absf(g.head.global_position.y - g.motor.global_position.y - height) < .001 and g.head.global_basis.is_equal_approx(orientation), "Travel preserves head height and orientation")
	for i in range(8): await physics_frame
	check(not floor_at(g, 0, -3.2).is_empty(), "Boat bow has walkable floor")
	check(floor_at(g, 1.4, -3.2).is_empty(), "No invisible rectangular floor outside tapered bow")
	g.motor.global_position.y = -4
	for i in range(3): await physics_frame
	check(g.motor.global_position.distance_to(g.motor.safe_spawn) < .1, "Fall recovery uses current boat arrival")
	print("Foreground tests: %d checks, %d failures" % [checks, failures])
	g.queue_free()
	await process_frame
	await create_timer(.3).timeout
	quit(1 if failures else 0)
