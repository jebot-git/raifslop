extends RefCounted
## Generous overhead/shoulder casting envelope, independent of speed or timing.
var raised := false
var retreat := 0.0

func sample(movement: Vector3, rod_pose: Transform3D, head_height: float, axis: Vector3, completed := false) -> float:
	var forward := -rod_pose.basis.z.normalized()
	var tip := rod_pose * Vector3(0, 0, -1.68)
	var travel := movement.dot(axis)
	var horizontal := Vector2(movement.x, movement.z).length()
	# Ignore sideways sweeps, even when they contain a little forward travel.
	if horizontal > .001 and absf(travel) < horizontal * .65: return 0.0
	if travel < 0 and rod_pose.origin.y > head_height - .7 and tip.y > head_height - .15 and forward.y > .1:
		raised = true
	if not raised: return 0.0
	if completed: retreat = maxf(0, retreat - travel)
	return travel

func release_allowed(rod_pose: Transform3D, head_height: float, axis: Vector3) -> bool:
	# A small follow-through is harmless; a deliberate reverse sweep is not.
	return raised and retreat < .15 and (-rod_pose.basis.z).dot(axis) > .2 and rod_pose.origin.y > head_height - .85
