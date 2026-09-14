extends CharacterBody3D
## Collision capsule follows the tracked head horizontally; the tracking origin
## absorbs room-scale offsets so physical steps are not counted twice.
const WALK_SPEED := 2.0
var origin: XROrigin3D
var head: Camera3D
var left: XRController3D
var right: XRController3D
var xr := false
var blocked := false
var tracking_focused := true
var catch_controls := false
var smooth_turn := false
var turn_latched := false
var capsule := CapsuleShape3D.new()
var shape := CollisionShape3D.new()
var last_motion := Vector3.ZERO
var safe_spawn := Vector3(0, 0.02, 0.65)

func _ready() -> void:
	name = "PlayerBody"
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.25
	floor_max_angle = deg_to_rad(45)
	capsule.radius = 0.23
	capsule.height = 1.65
	shape.shape = capsule
	shape.position.y = 0.825
	add_child(shape)

static func deadzone(value: Vector2) -> Vector2:
	var magnitude := value.length()
	if magnitude < 0.18: return Vector2.ZERO
	return value.normalized() * clampf((magnitude - 0.18) / 0.82, 0.0, 1.0)

func turn(angle: float) -> void:
	# Rotate around the player's head, never around the edge of the play space.
	var pivot := head.global_position
	origin.global_position = pivot + Basis(Vector3.UP, angle) * (origin.global_position - pivot)
	origin.global_basis = Basis(Vector3.UP, angle) * origin.global_basis

func relocate(spawn: Vector3) -> void:
	# Preserve physical head height/orientation while placing its floor projection safely.
	var offset := head.global_position - global_position
	offset.y = 0
	global_position = spawn
	origin.global_position -= offset
	velocity = Vector3.ZERO
	last_motion = Vector3.ZERO
	safe_spawn = spawn

func _physics_process(delta: float) -> void:
	if not is_instance_valid(head): return
	if blocked or (xr and (not tracking_focused or not right.get_has_tracking_data())):
		velocity = Vector3.ZERO
		last_motion = Vector3.ZERO
		return
	var height := clampf(head.global_position.y - global_position.y, 0.65, 2.1)
	capsule.height = height
	shape.position.y = height * 0.5
	var room_step := head.global_position - global_position
	room_step.y = 0.0
	if room_step.length() > 0.001:
		move_and_collide(room_step)
		origin.global_position -= room_step
	var stick := Vector2.ZERO
	var turn_axis := 0.0
	if xr:
		if left.get_has_tracking_data(): stick = deadzone(left.get_vector2("primary"))
		if right.get_has_tracking_data(): turn_axis = right.get_vector2("primary").x
	else:
		stick = Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S))).limit_length()
		turn_axis = float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q))
	if catch_controls:
		stick = Vector2.ZERO
		turn_axis = 0.0
		velocity = Vector3.ZERO
	if smooth_turn:
		if absf(turn_axis) > 0.18: turn(-turn_axis * deg_to_rad(75) * delta)
	elif absf(turn_axis) > 0.65 and not turn_latched:
		turn(-signf(turn_axis) * deg_to_rad(30))
		turn_latched = true
	if absf(turn_axis) < 0.25: turn_latched = false
	var forward := -head.global_basis.z
	forward.y = 0.0
	if forward.length() < 0.01: forward = -origin.global_basis.z
	forward = forward.normalized()
	var sideways := forward.cross(Vector3.UP)
	var desired := (sideways * stick.x + forward * stick.y) * WALK_SPEED
	velocity.x = move_toward(velocity.x, desired.x, delta * 7.0)
	velocity.z = move_toward(velocity.z, desired.z, delta * 7.0)
	velocity.y = -0.5 if is_on_floor() else velocity.y - 9.8 * delta
	var before := global_position
	move_and_slide()
	last_motion = (global_position - before) / maxf(delta, 0.001)
	if global_position.y < -3.0:
		relocate(safe_spawn)
