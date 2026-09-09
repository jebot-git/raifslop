extends SkeletonModifier3D
## Analytic two-bone arms and legs. All calculations use skeleton space.
var rig: Node3D
var ids: Dictionary = {}
var rest: Dictionary = {}

func setup(avatar: Node3D) -> void:
	rig = avatar
	var sk := get_skeleton()
	for i in range(sk.get_bone_count()):
		ids[sk.get_bone_name(i)] = i
		rest[i] = sk.get_bone_global_rest(i)

static func elbow_position(a: Vector3, target: Vector3, pole: Vector3, upper: float, lower: float) -> Vector3:
	var offset := target - a
	var axis := offset.normalized() if offset.length() > 0.0001 else Vector3.DOWN
	var distance := clampf(offset.length(), absf(upper - lower) + 0.001, upper + lower - 0.001)
	var along := (upper * upper - lower * lower + distance * distance) / (2.0 * distance)
	var height := sqrt(maxf(0.0, upper * upper - along * along))
	var bend := pole - a
	bend -= axis * bend.dot(axis)
	if bend.length_squared() < 0.0001:
		bend = axis.cross(Vector3.RIGHT)
		if bend.length_squared() < 0.0001: bend = axis.cross(Vector3.UP)
	return a + axis * along + bend.normalized() * height

func aim(sk: Skeleton3D, bone: int, current: Vector3, desired: Vector3) -> void:
	if current.length_squared() < 0.000001 or desired.length_squared() < 0.000001: return
	var pose := sk.get_bone_global_pose(bone)
	pose.basis = Basis(Quaternion(current.normalized(), desired.normalized())) * pose.basis
	sk.set_bone_global_pose(bone, pose)

func solve(sk: Skeleton3D, prefix: String, upper_name: String, lower_name: String, end_name: String, target_world: Vector3, pole_world: Vector3) -> void:
	var upper: int = ids[prefix + upper_name]
	var lower: int = ids[prefix + lower_name]
	var end: int = ids[prefix + end_name]
	var a := sk.get_bone_global_pose(upper).origin
	var b := sk.get_bone_global_pose(lower).origin
	var c := sk.get_bone_global_pose(end).origin
	var target := sk.to_local(target_world)
	var upper_length := a.distance_to(b)
	var lower_length := b.distance_to(c)
	if minf(upper_length, lower_length) < 0.005: return
	var elbow := elbow_position(a, target, sk.to_local(pole_world), upper_length, lower_length)
	aim(sk, upper, b - a, elbow - a)
	b = sk.get_bone_global_pose(lower).origin
	c = sk.get_bone_global_pose(end).origin
	aim(sk, lower, c - b, target - b)

func orient(sk: Skeleton3D, bone: int, world_basis: Basis) -> void:
	var pose := sk.get_bone_global_pose(bone)
	pose.basis = sk.global_basis.orthonormalized().inverse() * world_basis.orthonormalized()
	sk.set_bone_global_pose(bone, pose)

func _process_modification_with_delta(_delta: float) -> void:
	if not is_instance_valid(rig) or not is_instance_valid(rig.head): return
	var sk := get_skeleton()
	if rest.is_empty(): return
	for i in range(sk.get_bone_count()): sk.reset_bone_pose(i)
	var hips: int = ids.Hips
	var hip_pose := sk.get_bone_global_pose(hips)
	var crouch: float = clampf(rig.head.global_position.y - rig.global_position.y - rig.standing_height, -0.65, 0.15)
	hip_pose.origin += sk.global_basis.inverse() * Vector3(0, crouch, 0)
	sk.set_bone_global_pose(hips, hip_pose)
	for side in ["Left", "Right"]:
		var sign_x := -1.0 if side == "Left" else 1.0
		var hand_target: Node3D = rig.left_target if side == "Left" else rig.right_target
		var elbow := rig.to_global(Vector3(sign_x * 0.65, 0.95 + crouch, 0.05))
		solve(sk, side, "UpperArm", "LowerArm", "Hand", hand_target.global_position, elbow)
		var palm_basis := hand_target.global_basis * Basis(Vector3.RIGHT, -PI / 2) * Basis(Vector3.UP, PI if side == "Left" else 0.0)
		orient(sk, ids[side + "Hand"], palm_basis)
		var phase: float = rig.walk_phase + (PI if side == "Right" else 0.0)
		var stride: float = minf(rig.walk_speed / 2.0, 1.0)
		var foot := rig.to_global(Vector3(sign_x * 0.13, 0.08 + maxf(0.0, sin(phase)) * 0.10 * stride, cos(phase) * 0.20 * stride))
		solve(sk, side, "UpperLeg", "LowerLeg", "Foot", foot, rig.to_global(Vector3(sign_x * 0.16, 0.65, -0.8)))
		orient(sk, ids[side + "Foot"], rig.global_basis * Basis(Vector3.UP, PI))
		# Basic grip curl; optional finger bones are not required for loading.
		var curl: float = rig.left_curl if side == "Left" else 0.65
		for finger in ["Index", "Middle", "Ring", "Little"]:
			for joint in ["Proximal", "Intermediate", "Distal"]:
				var key: String = side + finger + joint
				if ids.has(key):
					var index: int = ids[key]
					sk.set_bone_pose_rotation(index, sk.get_bone_rest(index).basis.get_rotation_quaternion() * Quaternion(Vector3.RIGHT, -curl))
	var head_index: int = ids.Head
	orient(sk, head_index, rig.head.global_basis * Basis(Vector3.UP, PI))
