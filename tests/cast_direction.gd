extends SceneTree
const Motion = preload("res://scripts/cast_motion.gd")
const Fly = preload("res://scripts/fly_fishing.gd")
var failures: Array = []
func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures.append(label)
func attempt(height: float, direction: Vector3, basis: Basis, reverse := false) -> bool:
	var motion = Motion.new()
	var fly = Fly.new(); fly.begin_cast()
	var pose := Transform3D(basis, Vector3(.25, height, -.3))
	for sign_value in [-1, 1]:
		for i in 20:
			var movement: Vector3 = direction * sign_value * .008
			pose.origin += movement
			fly.stroke(.05, motion.sample(movement, pose, 1.65, Vector3.FORWARD, fly.strokes > 0) / .05)
	if reverse:
		for i in 25: motion.sample(Vector3.BACK * .008, pose, 1.65, Vector3.FORWARD, true)
	return fly.strokes > 0 and motion.release_allowed(pose, 1.65, Vector3.FORWARD)
func _initialize() -> void:
	var raised := Basis(Vector3.RIGHT, .35)
	check(attempt(1.3, Vector3.FORWARD, raised), "Slow shoulder-height back/forward swing remains comfortable")
	check(attempt(1.3, Vector3(-.4, 0, -1).normalized(), raised), "Moderately diagonal forward cast remains accepted")
	check(not attempt(.55, Vector3.FORWARD, raised), "Low waist-level swing cannot cast")
	check(not attempt(1.3, Vector3(1, 0, -.2).normalized(), raised), "Sideways sweep with a little forward travel cannot cast")
	check(not attempt(1.3, Vector3.FORWARD, Basis(Vector3.UP, PI) * raised), "Backward-pointing rod cannot cast")
	check(not attempt(1.3, Vector3.FORWARD, raised, true), "Deliberate reverse sweep after readiness cannot release a cast")
	print("CAST_DIRECTION_RESULT ", failures); quit(0 if failures.is_empty() else 1)
