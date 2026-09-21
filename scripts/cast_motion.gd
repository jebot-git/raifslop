extends RefCounted
## Back/forward casting envelope, including seated and sidearm casts.
var raised := false
var retreat := 0.0

func sample(movement: Vector3, rod_pose: Transform3D, head_height: float, axis: Vector3, completed := false) -> float:
	var forward := -rod_pose.basis.z.normalized()
	var travel := movement.dot(axis)
	var horizontal := Vector2(movement.x, movement.z).length()
	# Ignore sideways sweeps, even when they contain a little forward travel.
	if horizontal > .001 and absf(travel) < horizontal * .65: return 0.0
	# Requiring a raised tip excludes level sidearm casts and seated users.
	# Deliberate back/forward travel still supplies the gesture, not height.
	if travel < 0 and rod_pose.origin.y > head_height - 1.25 and forward.dot(axis) > -.8:
		raised = true
	if not raised: return 0.0
	if completed: retreat = maxf(0, retreat - travel)
	return travel

func release_allowed(rod_pose: Transform3D, _head_height: float, axis: Vector3) -> bool:
	# A small follow-through is harmless; a deliberate reverse sweep is not.
	return raised and retreat < .3 and (-rod_pose.basis.z).dot(axis) > -.2
