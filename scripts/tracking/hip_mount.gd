extends RefCounted
## Shared waist frame for fishing and golf tools. Looking never turns tracked hips.
static func pose(head: Node3D, motor: Node3D, tracking: Node) -> Transform3D:
	var basis := head.global_basis
	var at := Vector3(head.global_position.x, maxf(motor.global_position.y + .55, head.global_position.y - .70), head.global_position.z)
	if is_instance_valid(tracking) and tracking.body.has("hips"):
		var hips: Transform3D = motor.global_transform * tracking.body.hips
		if motor.tracked_hip is Transform3D:
			hips = motor.origin.global_transform * motor.tracked_hip
		basis = hips.basis; at = hips.origin
	# Belt equipment stays upright even while the player bends at the waist.
	var facing := Vector3(basis.z.x, 0, basis.z.z)
	if facing.length_squared() < .001:
		facing = Vector3(basis.x.x, 0, basis.x.z).cross(Vector3.UP)
	return Transform3D(Basis(Vector3.UP, atan2(facing.x, facing.z)), at)
