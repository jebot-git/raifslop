extends SceneTree
## Offline editorial cameras in the production game world. No network session.
## Run with isolated XDG directories, --xr-mode off and -- --xr-test.
var game: Node3D
var camera: Camera3D
var output := "res://docs/quest-store/media/raw"
var mode := "survey"
var showcase: Node3D
const SHOTS := ["lake_pier", "gray_pier", "cedar_creek", "glacier_run", "blouberg_sunrise_2"]

func option(key: String, fallback: String) -> String:
	var args := OS.get_cmdline_user_args()
	var at := args.find(key)
	return args[at + 1] if at >= 0 and at + 1 < args.size() else fallback

func _initialize() -> void:
	call_deferred("run")

func settle(frames: int = 12) -> void:
	for i in frames: await process_frame
	await RenderingServer.frame_post_draw

func capture(name: String) -> void:
	await settle()
	var image := root.get_texture().get_image()
	image.convert(Image.FORMAT_RGB8)
	var result := image.save_png(output.path_join(name + ".png"))
	print("STORE_CAPTURE ", name, " ", image.get_size(), " ", result)
	if result != OK: quit(1)

func hide_player() -> void:
	game.set_process(false)
	game.motor.process_mode = Node.PROCESS_MODE_DISABLED
	for key in ["motor", "avatar", "hud", "bobber", "aim_marker", "catch_label", "fish_guide", "shoulder_radio", "avatar_panel", "menu_pointer", "menu_laser", "rod"]:
		var node = game.get(key)
		if is_instance_valid(node): node.hide()
	camera.make_current()

func location(id: String, yaw: float = 0.0, pitch: float = -3.0) -> void:
	game._select_location(id, false)
	hide_player()
	camera.global_position = game.foreground.get_meta("spawn") + Vector3(0, 1.7, 0)
	camera.rotation_degrees = Vector3(pitch, yaw, 0)
	await settle(24)

func golf_location() -> void:
	await game.golf_activity.enter("poppy")
	var golf = game.golf_activity.golf
	golf.set_process(false)
	golf.body.process_mode = Node.PROCESS_MODE_DISABLED
	golf.hud.hide()
	golf.club.hide()
	if is_instance_valid(golf.aim_mesh): golf.aim_mesh.hide()
	hide_player()
	camera.global_position = golf.model.tee() + Vector3(0, 1.7, 0)
	camera.look_at(golf.model.guide_target(golf.model.tee()) + Vector3(0, 1.0, 0))
	await settle(30)

func equipment(kind: String) -> void:
	await location("lake_pier", -20)
	camera.fov = 42
	root.msaa_3d = Viewport.MSAA_4X
	camera.rotation_degrees = Vector3(-2,-20,0)
	showcase = Node3D.new()
	game.add_child(showcase)
	showcase.global_transform = camera.global_transform
	if kind == "tackle":
		for i in 3:
			var rod = load("res://scripts/rod_visual.gd").new()
			showcase.add_child(rod)
			rod.equip([0,2,3][i], i == 1, false, i == 2)
			rod.position = Vector3((i-1)*.43,-.19,-1.32-i*.05)
			rod.rotation_degrees = Vector3(66, -22, -18)
	else:
		camera.fov = 34
		for i in 3:
			var index: int = [0,3,7][i]
			var asset: String = ["driver","iron","putter"][i]
			var club: Node3D = load("res://addons/golfminus/assets/models/"+asset+".glb").instantiate()
			showcase.add_child(club)
			var shape = load("res://addons/golfminus/scripts/golf/club_head.gd").for_club(index)
			var head: MeshInstance3D = shape.install(club,index)
			var length: float = [1.13,.93,.86][i]
			head.basis = Basis.from_euler(Vector3(0,0,deg_to_rad(-27))) * Basis(Vector3.RIGHT,shape.loft)
			head.position = Vector3(0,-length,0)+head.basis.x*.055
			load("res://addons/golfminus/scripts/golf/club_style.gd").apply(club,[0,2,3][i])
			club.position = Vector3((i-1)*.24,length-.10,-.88)
			club.rotation_degrees = Vector3(-12, -145, -12)
	# Editorial equipment lighting affects only the staged production meshes.
	for mesh in showcase.find_children("*","MeshInstance3D",true,false): mesh.layers = 8
	camera.cull_mask = 9
	for spec in [[Vector3(-.8,1.2,.1),1.25],[Vector3(.9,.2,-.1),.6]]:
		var fill := OmniLight3D.new()
		showcase.add_child(fill)
		fill.position = spec[0]
		fill.light_energy = spec[1]
		fill.omni_range = 4
		fill.light_cull_mask = 8
	var focus := CameraAttributesPractical.new()
	focus.dof_blur_far_enabled = true
	focus.dof_blur_far_distance = 2.0
	focus.dof_blur_far_transition = 1.0
	focus.dof_blur_amount = .16
	camera.attributes = focus
	await capture("promo-"+kind)
	showcase.queue_free()
	camera.attributes = null
	camera.fov = 70
	camera.cull_mask = 1
	await settle()

func panorama_clip(id: String) -> void:
	await location(id)
	var folder := output.path_join(id)
	DirAccess.make_dir_recursive_absolute(folder)
	for frame in 180:
		var t := float(frame) / 179.0
		camera.rotation_degrees = Vector3(-3.0, lerpf(-14.0,14.0,t), 0)
		await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		image.convert(Image.FORMAT_RGB8)
		var error := image.save_jpg(folder.path_join("%05d.jpg" % frame),.96)
		if error != OK: push_error("Frame write failed"); quit(1); return
		if frame % 30 == 0: print("STORE_VIDEO ", id, " ", frame, "/180")
	print("STORE_CLIP_DONE ", id)

func run() -> void:
	mode = option("--mode", "survey")
	output = option("--output", output)
	DirAccess.make_dir_recursive_absolute(output)
	var size := Vector2i(1280,720) if mode == "survey" else Vector2i(2560,1440)
	if mode == "video": size = Vector2i(1920,1080)
	root.size = Vector2i(1280,720)
	root.content_scale_size = size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	camera = Camera3D.new()
	camera.fov = 70
	camera.far = 2000
	camera.cull_mask = 1
	game.add_child(camera)
	await settle(30)
	hide_player()
	if mode == "survey":
		for entry in load("res://scripts/locations.gd").CATALOG:
			await location(entry.id)
			await capture(entry.id)
	elif mode == "stills":
		var number := 1
		for id in SHOTS:
			await location(id)
			await capture("screenshot-%02d-%s" % [number,id])
			number += 1
		await golf_location()
		await capture("screenshot-06-golf")
	elif mode == "equipment":
		await equipment("tackle")
		await equipment("clubs")
	elif mode == "video":
		var selected := option("--shot", "all")
		for id in SHOTS:
			if selected == "all" or selected == id: await panorama_clip(id)
	quit()
