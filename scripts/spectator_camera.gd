extends Node3D
## Desktop streaming camera; headset tracking never inherits this smoothing.
const OFFSET := Vector3(1.25, 1.1, 3.4)
const FOLLOW_SPEED := 5.0
const TELEPORT_DISTANCE := 5.0
var game
var camera: Camera3D
var anchor := Vector3.ZERO
var yaw := 0.0
var initialized := false

func setup(game_root) -> void:
	game = game_root
	name = "SpectatorCamera"
	camera = Camera3D.new()
	camera.name = "DesktopCamera"
	camera.fov = 65
	camera.near = 0.08
	# Scene + complete VRM, excluding the first-person duplicate and guide UI.
	camera.cull_mask = 5
	add_child(camera)
	camera.current = true
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(game): return
	update_pose(delta)

func update_pose(delta: float) -> void:
	var target: Vector3 = game.head.global_position - Vector3.UP * 0.35
	# Follow locomotion yaw, not every glance or tilt of the headset.
	var heading: float = game.origin.global_rotation.y
	var snap := not initialized or anchor.distance_to(target) > TELEPORT_DISTANCE
	var weight := 1.0 if snap else 1.0 - exp(-FOLLOW_SPEED * delta)
	anchor = anchor.lerp(target, weight)
	yaw = lerp_angle(yaw, heading, weight)
	initialized = true
	var desired := anchor + Basis(Vector3.UP, yaw) * OFFSET
	var query := PhysicsRayQueryParameters3D.create(target, desired, 1)
	query.exclude = [game.motor.get_rid()]
	var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty(): desired = hit.position + hit.normal * 0.2
	camera.global_position = desired
	if desired.distance_squared_to(anchor) > 0.001:
		var direction := (anchor - desired).normalized()
		camera.look_at(anchor, Vector3.RIGHT if absf(direction.dot(Vector3.UP)) > 0.98 else Vector3.UP)
	camera.environment = game.head.environment
	camera.attributes = game.head.attributes
