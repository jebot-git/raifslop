extends SceneTree
const Session = preload("res://scripts/fishing_session.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(1500, 1500)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("24363b")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("dbe2e3")
	env.environment.ambient_light_energy = .65
	view.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35,-25,0)
	light.light_energy = .8
	view.add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.2
	camera.position = Vector3(0,0,4)
	view.add_child(camera)
	var models: Array[Node3D] = []
	var labels: Array[Label3D] = []
	var indices := [3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,1,2]
	for i in range(indices.size()):
		var species: Dictionary = Session.SPECIES[indices[i]]
		var fish: Node3D = load(species.model).instantiate()
		fish.position = Vector3(-1.33 + (i % 3) * 1.33, 1.74 - (i / 3) * .67, 0)
		view.add_child(fish)
		models.append(fish)
		var label := Label3D.new()
		label.text = species.name
		label.font_size = 24
		label.pixel_size = .0018
		label.position = fish.position + Vector3(0,-.27,.15)
		view.add_child(label)
		labels.append(label)
	for i in range(12): await process_frame
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png("res://docs/photographic_fish.png")
	for fish in models: fish.visible = false
	for label in labels: label.visible = false
	# Separate close-ups prevent neighbouring specimens obscuring their eyes and jaws.
	camera.size = .48
	for name in ["chub", "pike", "rudd", "barbel"]:
		var pivot := Node3D.new()
		view.add_child(pivot)
		var fish: Node3D = load("res://assets/models/fish/"+name+".glb").instantiate()
		pivot.add_child(fish)
		fish.position.x = -.32
		pivot.rotation_degrees.y = -32 if name != "rudd" else 148
		for i in range(12): await process_frame
		await RenderingServer.frame_post_draw
		view.get_texture().get_image().save_png("res://docs/fish_head_"+name+".png")
		pivot.queue_free()
		await process_frame
	print("Photographic fish: catalogue and oblique head views captured")
	quit()
