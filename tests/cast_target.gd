extends SceneTree
const Target=preload("res://scripts/cast_target.gd")
func _initialize()->void:
	var anchor:=Vector3(.25,.05,0)
	for yaw in [0.0,.7,-1.4]:
		var direction:=Basis(Vector3.UP,yaw)*Vector3.FORWARD
		var water:=func(at:Vector3):
			var offset:Vector3=at-anchor
			return offset.dot(direction)>=5.0 and offset.dot(direction)<=8.0 and offset.cross(direction).length()<.001
		var landing:=Target.fit(anchor,direction,24.0,water)
		assert(landing.is_finite() and water.call(landing))
		assert(landing.distance_to(anchor)>7.95)
		assert((landing-anchor).normalized().dot(direction)>.999)
		assert(Target.fit(anchor,direction,6.0,water).is_equal_approx(anchor+direction*6))
	assert(not Target.fit(anchor,Vector3.FORWARD,24,func(_at):return false).is_finite())
	assert(not Target.fit(anchor,Vector3.ZERO,24,func(_at):return true).is_finite())
	print("CAST_TARGET_RESULT river overshoot, heading and blocked-water checks passed")
	quit()
