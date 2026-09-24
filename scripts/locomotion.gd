extends CharacterBody3D
## Collision capsule follows tracked hips (head when unavailable); the tracking origin
## absorbs room-scale offsets so physical steps are not counted twice.
const WALK_SPEED := 2.0
var origin: XROrigin3D
var head: Camera3D
var left: XRController3D
var right: XRController3D
var xr := false
var single_controller_controls := false
var single_controller_hand:Callable
var blocked := false
var stick_lock:Callable
var stick_release_pending:=false
var turn_reserved:=false
var radial_open:=false
var tracking_focused := true
var catch_controls := false
var smooth_turn := false
var smooth_turn_speed := 75.0
var snap_turn_angle := 30.0
var turn_latched := false
var capsule := CapsuleShape3D.new()
var shape := CollisionShape3D.new()
var last_motion := Vector3.ZERO
var safe_spawn := Vector3(0, 0.02, 0.65)
var tracked_hip: Variant = null # Transform3D in tracking-origin coordinates.
var head_shape := CollisionShape3D.new()
var previous_head := Vector3(INF, INF, INF)

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
	var sphere := SphereShape3D.new(); sphere.radius = .12
	head_shape.shape = sphere; head_shape.disabled = true; add_child(head_shape)

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
	previous_head = Vector3(INF, INF, INF)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(head): return
	if blocked or not tracking_focused or (not right.get_has_tracking_data() and not (single_controller_controls and left.get_has_tracking_data())):
		velocity = Vector3.ZERO
		last_motion = Vector3.ZERO
		previous_head = Vector3(INF, INF, INF)
		return
	var height := clampf(head.global_position.y - global_position.y, 0.65, 2.1)
	capsule.height = height
	shape.position.y = height * 0.5
	var hips_tracked := xr and tracked_hip is Transform3D
	head_shape.disabled = not hips_tracked
	head_shape.position = to_local(head.global_position)
	var anchor: Vector3 = origin.to_global(tracked_hip.origin) if hips_tracked else head.global_position
	var room_step := anchor - global_position
	room_step.y = 0.0
	if room_step.length() > 0.001:
		move_and_collide(room_step)
		origin.global_position -= room_step
	head_shape.position = to_local(head.global_position)
	if hips_tracked and previous_head.is_finite():
		# Sweep only the head through the lean. A low rail never intersects it;
		# a tall wall still blocks even a large one-frame tracking movement.
		var from := origin.to_global(previous_head)
		var motion := head.global_position - from
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = head_shape.shape; query.transform = Transform3D(Basis.IDENTITY, from)
		query.motion = motion; query.collision_mask = collision_mask; query.exclude = [get_rid()]
		var fractions := get_world_3d().direct_space_state.cast_motion(query)
		if fractions[0] < 1.0: global_position -= motion * (1.0 - fractions[0])
	previous_head = head.position if hips_tracked else Vector3(INF, INF, INF)
	var stick := Vector2.ZERO
	var turn_axis := 0.0
	if left.get_has_tracking_data(): stick = deadzone(left.get_vector2("primary"))
	if right.get_has_tracking_data(): turn_axis = right.get_vector2("primary").x
	var only:XRController3D=null
	if single_controller_controls:
		if single_controller_hand.is_valid():only=single_controller_hand.call()
		if not is_instance_valid(only) and left.get_has_tracking_data()!=right.get_has_tracking_data():
			only=left if left.get_has_tracking_data() else right
	if is_instance_valid(only) and only.get_has_tracking_data():
		var input:=deadzone(only.get_vector2("primary"))
		stick=Vector2(0,input.y);turn_axis=only.get_vector2("primary").x
	if stick_lock.is_valid() and stick_lock.call():stick_release_pending=true
	elif stick_release_pending and stick.length()<.2 and absf(turn_axis)<.2:stick_release_pending=false
	if catch_controls or stick_release_pending:
		stick = Vector2.ZERO
		turn_axis = 0.0
		velocity = Vector3.ZERO
	if turn_reserved:
		if not radial_open and absf(turn_axis)<.2 and (right.get_vector2("primary").length()<.2 and not right.is_button_pressed("primary_click")):turn_reserved=false
		turn_axis=0
	apply_turn_input(turn_axis, delta)
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

func apply_turn_input(axis:float,delta:float) -> void:
	if smooth_turn:
		if absf(axis) > 0.18: turn(-axis * deg_to_rad(smooth_turn_speed) * delta)
	elif absf(axis) > 0.65 and not turn_latched:
		turn(-signf(axis) * deg_to_rad(snap_turn_angle))
		turn_latched = true
	if absf(axis) < 0.25: turn_latched = false
