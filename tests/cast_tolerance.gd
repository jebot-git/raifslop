extends SceneTree
const F = preload("res://scripts/fly_fishing.gd")
var failures: Array = []
func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures.append(label)
func _initialize() -> void:
	for fps in [30, 72, 90, 120]:
		for speed in [.12, .25, .6, 3.0]:
			var gesture = F.new(); gesture.begin_cast()
			var dt: float = 1.0 / fps
			for i in ceili(.08 / speed * fps): gesture.stroke(dt, -speed)
			# A comfortable pause while deciding where/how to swing is allowed.
			for i in fps * 5: gesture.stroke(dt, 0)
			for i in ceili(.14 / speed * fps): gesture.stroke(dt, speed)
			check(gesture.strokes == 1, "Slow/fast casting accepts an unhurried pause at %d FPS, %.2f m/s" % [fps, speed])
			for i in fps * 2: gesture.stroke(dt, -speed)
			check(gesture.strokes == 1, "Follow-through cannot erase or repeatedly count an accepted cast")
	var idle = F.new(); idle.begin_cast()
	for i in 900: idle.stroke(1.0 / 90.0, .05 if i % 2 == 0 else -.05)
	check(idle.strokes == 0, "Stationary hand noise cannot cast")
	var jitter = F.new(); jitter.begin_cast()
	for i in 900: jitter.stroke(1.0 / 90.0, .3 if i % 2 == 0 else -.3)
	check(jitter.strokes == 0, "Tiny alternating tracking movements cannot complete forward travel")
	print("CAST_TOLERANCE_RESULT ", failures); quit(0 if failures.is_empty() else 1)
