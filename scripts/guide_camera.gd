extends Node
## Dedicated mono photo view: UI is excluded by layers, never globally hidden.
const UI_LAYER := 128
const PHOTO_SIZE := Vector2i(1920, 1080)
const PREVIEW_SIZE := Vector2i(640, 360)
const PHOTO_DIR := "user://photos"
signal saved(path: String)
var guide
var view: SubViewport
var camera: Camera3D
var active := false
var selfie := false
var busy := false
var status := ""
var last_path := ""
var refresh_time := 0.0

func setup(owner_guide) -> void:
	guide = owner_guide
	view = SubViewport.new()
	view.size = PREVIEW_SIZE
	view.world_3d = guide.game_root.get_world_3d()
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	view.gui_disable_input = true
	add_child(view)
	camera = Camera3D.new()
	view.add_child(camera)
	camera.current = true
	camera.near = 0.05
	camera.fov = 65
	# Layers 1/2 are the main scene/body, layer 4 includes the complete avatar.
	camera.cull_mask = 3
	mark_ui(guide.device)
	var game = guide.game_root
	for node in [game.vr_status, game.avatar_panel, game.menu_pointer]:
		if is_instance_valid(node): mark_ui(node)
	game.head.cull_mask |= UI_LAYER

static func mark_ui(node: Node) -> void:
	if node is VisualInstance3D: node.layers = UI_LAYER
	for child in node.get_children(): mark_ui(child)

func toggle() -> void:
	if busy: return
	active = not active
	status = "Photos saved in " + ProjectSettings.globalize_path(PHOTO_DIR)
	if not active: view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	guide.screen.queue_redraw()

func toggle_selfie() -> void:
	if not active or busy: return
	selfie = not selfie
	update_pose()
	guide.screen.queue_redraw()

func update_pose() -> void:
	var game = guide.game_root
	var source: Transform3D = game.left.global_transform if game.xr else game.head.global_transform
	if selfie:
		var target: Vector3 = game.head.global_position - Vector3.UP * 0.3
		var desired := source.origin - source.basis.z * 1.5 + Vector3.UP * 0.15
		# Keep the extended lens on this side of solid scenery.
		var query := PhysicsRayQueryParameters3D.create(target, desired, 1)
		if game.motor is CollisionObject3D: query.exclude = [game.motor.get_rid()]
		var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty(): desired = hit.position + hit.normal * 0.08
		if desired.distance_to(target) < 0.15: desired = target + source.basis.z * 0.2
		camera.global_position = desired
		var direction := (target - desired).normalized()
		camera.look_at(target, Vector3.RIGHT if absf(direction.dot(Vector3.UP)) > 0.98 else Vector3.UP)
		camera.cull_mask = 5
	else:
		camera.global_transform = source
		camera.cull_mask = 3
	camera.environment = game.head.environment
	camera.attributes = game.head.attributes

func _process(delta: float) -> void:
	if not is_instance_valid(guide) or not active or not guide.held or busy: return
	refresh_time -= delta
	if refresh_time > 0: return
	refresh_time = 0.1
	update_pose()
	view.render_target_update_mode = SubViewport.UPDATE_ONCE
	guide.screen.queue_redraw()

func capture() -> void:
	if not active or not guide.held or busy: return
	if DisplayServer.get_name() == "headless":
		status = "Photos need a running graphics renderer."
		guide.screen.queue_redraw()
		return
	busy = true
	status = "Taking photo…"
	guide.screen.queue_redraw()
	update_pose()
	view.size = PHOTO_SIZE
	# Two draws allow the resized render target to settle before readback.
	for frame in range(2):
		view.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		if not is_instance_valid(guide): return
	var photo := view.get_texture().get_image()
	var error := ERR_CANT_CREATE
	var path := ""
	if photo != null and not photo.is_empty():
		error = DirAccess.make_dir_recursive_absolute(PHOTO_DIR)
		if error == OK:
			var stamp := Time.get_datetime_string_from_system().replace(":", "-")
			path = PHOTO_DIR.path_join("fishing_%s_%d.png" % [stamp, Time.get_ticks_usec()])
			error = photo.save_png(path)
	view.size = PREVIEW_SIZE
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	busy = false
	if error == OK:
		last_path = ProjectSettings.globalize_path(path)
		status = "Photo saved · " + path.get_file()
		saved.emit(last_path)
	else:
		status = "Could not save photo (%s)." % error_string(error)
	guide.screen.queue_redraw()
