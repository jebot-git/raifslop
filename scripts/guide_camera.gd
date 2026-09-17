extends Node
## Dedicated mono photo view: UI is excluded by layers, never globally hidden.
const UI_LAYER := 128
const PHOTO_SIZE := Vector2i(1920, 1080)
const PREVIEW_SIZE := Vector2i(640, 360)
static var PHOTO_DIR: String:
	get: return preload("res://scripts/data_paths.gd").photos()
const REAR_LENS := Vector3(0.055, 0.13, -0.024)
const FRONT_LENS := Vector3(0.055, 0.139, 0.024)
const MAX_SELFIE_EXTENSION := 3.0
const SELFIE_SPEED := 1.0
const STICK_DEADZONE := .18
const LENS_CLEARANCE := .08
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
var selfie_extension := 0.0
var effective_extension := 0.0
var clearance_shape := SphereShape3D.new()
var disk = preload("res://scripts/network/disk_worker.gd").new()

func setup(owner_guide) -> void:
	guide = owner_guide
	add_child(disk)
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
	clearance_shape.radius = LENS_CLEARANCE
	# Layers 1/2 are the main scene/body, layer 4 includes the complete avatar.
	camera.cull_mask = 3
	mark_ui(guide.device)
	var game = guide.game_root
	for node in [game.avatar_panel, game.menu_pointer, game.menu_laser]:
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
	# The guide has its own grip rotation. Controller -Z now points along the
	# handle, so using the controller pose puts the lens on the device's edge.
	if game.xr:
		camera.global_transform = guide.global_transform * lens_pose(selfie)
		if selfie:
			var base:=camera.global_position
			camera.global_position=constrain_extension(base,base+camera.global_basis.z*selfie_extension)
			effective_extension=base.distance_to(camera.global_position)
		camera.cull_mask = 5 if selfie else 3
		camera.fov = 90 if selfie else 65
		camera.environment = game.head.environment
		camera.attributes = game.head.attributes
		return
	var source: Transform3D = game.head.global_transform
	camera.fov = 65
	if selfie:
		var target: Vector3 = game.head.global_position - Vector3.UP * 0.3
		var desired := source.origin - source.basis.z * (1.5+selfie_extension) + Vector3.UP * 0.15
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

func constrain_extension(base:Vector3,desired:Vector3)->Vector3:
	if base.is_equal_approx(desired):return base
	var game=guide.game_root
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=clearance_shape
	query.transform=Transform3D(Basis.IDENTITY,base)
	query.motion=desired-base
	query.collision_mask=1
	if game.motor is CollisionObject3D:query.exclude=[game.motor.get_rid()]
	var space:PhysicsDirectSpaceState3D=game.get_world_3d().direct_space_state
	# Sweeps ignore initially overlapping shapes. Never extend out through a wall.
	if not space.intersect_shape(query,1).is_empty():return base
	var fractions:=space.cast_motion(query)
	return base.lerp(desired,fractions[0]) if not fractions.is_empty() else base

func adjust_selfie(axis:float,delta:float)->void:
	if not active or not selfie or not guide.held or busy or guide.game_root.menu_open:return
	if not is_finite(axis) or delta<=0 or absf(axis)<=STICK_DEADZONE:return
	var rate:=signf(axis)*clampf((absf(axis)-STICK_DEADZONE)/(1.0-STICK_DEADZONE),0,1)
	# Retracting responds immediately even when scenery shortened the extension.
	if rate<0 and guide.game_root.xr:selfie_extension=minf(selfie_extension,effective_extension)
	selfie_extension=clampf(selfie_extension+rate*SELFIE_SPEED*minf(delta,.1),0,MAX_SELFIE_EXTENSION)
	update_pose()

func sample_selfie_input(delta:float)->void:
	var game=guide.game_root
	var axis:=0.0
	if game.xr:
		if not game.tracking_manager.focused or not game.right.get_has_tracking_data() or not game.left.get_has_tracking_data():return
		axis=game.right.get_vector2("primary").y
	else:
		axis=float(Input.is_key_pressed(KEY_UP))-float(Input.is_key_pressed(KEY_DOWN))
	adjust_selfie(axis,delta)

static func lens_pose(front: bool) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, PI) if front else Basis.IDENTITY, FRONT_LENS if front else REAR_LENS)

func _process(delta: float) -> void:
	if not is_instance_valid(guide) or not active or not guide.held or busy: return
	sample_selfie_input(delta)
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
	view.size = PREVIEW_SIZE
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if photo == null or photo.is_empty():
		_finish_save(ERR_CANT_CREATE, "")
		return
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var path := PHOTO_DIR.path_join("fishing_%s_%d.png" % [stamp, Time.get_ticks_usec()])
	status = "Saving photo…"
	# PNG compression and disk writes cannot stall the render/network dispatch.
	if not disk.submit(save_photo.bind(photo,path),func(error): _finish_save(error,path)):
		_finish_save(ERR_BUSY,path)
	while busy: await get_tree().process_frame

static func save_photo(photo: Image,path: String) -> Error:
	if OS.has_feature("android") and not "--photos-root" in OS.get_cmdline_user_args():
		return preload("res://scripts/android_photos.gd").save(photo,path.get_file())
	var error := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	return photo.save_png(path) if error==OK else error

func _finish_save(error: Error,path: String) -> void:
	busy = false
	if error == OK:
		last_path = ProjectSettings.globalize_path(path)
		status = "Photo saved · " + path.get_file()
		saved.emit(last_path)
	else:
		status = "Could not save photo (%s)." % error_string(error)
	if is_instance_valid(guide):guide.screen.queue_redraw()
