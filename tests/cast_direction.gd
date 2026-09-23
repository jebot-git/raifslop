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
		for i in 45: motion.sample(Vector3.BACK * .008, pose, 1.65, Vector3.FORWARD, true)
	return fly.strokes > 0 and motion.release_allowed(pose, 1.65, Vector3.FORWARD)
func _initialize() -> void:
	# Trigger may be pressed before or after the rod passes vertical.
	for yaw in [0.0,.7,-1.4]:
		for pitch in [.0,.7,1.3,1.57,2.0,2.3,2.6,2.9]:
			var basis:=Basis(Vector3.UP,yaw)*Basis(Vector3.RIGHT,pitch)
			var axis:=Motion.controller_axis(Transform3D(basis,Vector3.ZERO))
			check(axis.dot(Basis(Vector3.UP,yaw)*Vector3.FORWARD)>.999,"Overhand casting gate stays forward at pitch %.2f / yaw %.2f"%[pitch,yaw])
	var raised := Basis(Vector3.RIGHT, .35)
	check(attempt(1.3, Vector3.FORWARD, raised), "Slow shoulder-height back/forward swing remains comfortable")
	check(attempt(1.3, Vector3(-.4, 0, -1).normalized(), raised), "Moderately diagonal forward cast remains accepted")
	check(attempt(.55, Vector3.FORWARD, Basis.IDENTITY), "Level waist-height sidearm cast is accepted")
	check(attempt(.1, Vector3.FORWARD, raised), "Low seated back/forward swing remains accepted")
	check(not attempt(1.3, Vector3(1, 0, -.2).normalized(), raised), "Sideways sweep with a little forward travel cannot cast")
	check(attempt(1.3, Vector3.FORWARD, Basis(Vector3.UP, PI) * raised), "Release wrist angle cannot invalidate a completed swing")
	check(attempt(1.3, Vector3.FORWARD, raised, true), "Follow-through cannot undo a completed swing")
	var motion = Motion.new()
	var pose := Transform3D(Basis.IDENTITY, Vector3(.25, .55, -.3))
	motion.sample_controller(Vector3.BACK * .1, .05, pose, Vector3.FORWARD, false)
	motion.sample_controller(Vector3.FORWARD * .2, .05, pose, Vector3.FORWARD, false)
	check(is_equal_approx(motion.swing_distance(), 8.75), "Controller cast range comes from measured forward speed")
	motion.sample_controller(Vector3.BACK * .1, .05, pose, Vector3.FORWARD, true)
	motion.sample_controller(Vector3.FORWARD * .05, .05, pose, Vector3.FORWARD, true)
	check(is_equal_approx(motion.swing_distance(), 8.75), "A softer follow-through preserves the accepted stroke power")
	check(motion.swing_travel.normalized().dot(Vector3.FORWARD)>.999,"Recovery after a completed cast cannot redirect the saved stroke")
	motion=Motion.new();motion.sample_controller(Vector3.BACK*.1,.05,pose,Vector3.FORWARD,false)
	motion.sample_controller(Vector3.FORWARD*1.2, .03, pose, Vector3.FORWARD, false)
	check(is_equal_approx(motion.swing_distance(), 24.0), "Fast controller swings respect maximum cast reach")
	for sign_x in [-1,1]:
		motion=Motion.new();motion.sample_controller(Vector3.BACK*.12,.05,pose,Vector3.FORWARD,false)
		for i in 8:motion.sample_controller(Vector3(0,0,-.1),.02,pose,Vector3.FORWARD,i>1)
		var heading:Vector3=motion.swing_travel.normalized();var reach:float=motion.swing_distance()
		for i in 20:motion.sample_controller(Vector3(sign_x*.15,0,-.005),.02,pose,Vector3.FORWARD,true)
		check(motion.swing_travel.normalized().dot(heading)>.999 and is_equal_approx(motion.swing_distance(),reach),"Sideways follow-through does not steer or power a completed cast: "+str(sign_x))
	# Preparation can briefly complete a gesture; the subsequent real stroke wins.
	motion=Motion.new()
	motion.sample_controller(Vector3.BACK*.07,.05,pose,Vector3.FORWARD,false)
	motion.sample_controller(Vector3(.14,0,-.11),.014,pose,Vector3.FORWARD,false)
	for i in 8:motion.sample_controller(Vector3.BACK*.04,.014,pose,Vector3.FORWARD,true)
	for i in 12:motion.sample_controller(Vector3.FORWARD*.08,.014,pose,Vector3.FORWARD,true)
	check(motion.swing_travel.normalized().dot(Vector3.FORWARD)>.999,"A real backswing and forward cast replace sideways preparatory gesture")
	# An early lateral wrist sample must not beat a sustained forward stroke.
	motion=Motion.new();motion.sample_controller(Vector3.BACK*.1,.05,pose,Vector3.FORWARD,false)
	motion.sample_controller(Vector3(.16,0,-.09),.007,pose,Vector3.FORWARD,false)
	for i in 16:motion.sample_controller(Vector3.FORWARD*.07,.014,pose,Vector3.FORWARD,true)
	check(motion.swing_travel.normalized().dot(Vector3.FORWARD)>.999,"One fast lateral sample cannot dominate a full forward velocity window")
	var reference:=Vector3.ZERO
	for yaw in [0.0,.7,1.8,-1.1]:
		var turn:=Basis(Vector3.UP,yaw);motion=Motion.new()
		motion.sample_controller(turn*Vector3.BACK*.1,.05,pose,turn*Vector3.FORWARD,false)
		for displacement in [Vector3(.09,0,-.08),Vector3(.01,0,-.09),Vector3(-.01,0,-.09),Vector3(.01,0,-.08),Vector3(0,0,-.09),Vector3(0,0,-.07)]:
			motion.sample_controller(turn*displacement,.014,pose,turn*Vector3.FORWARD,true)
		var local_heading:Vector3=turn.inverse()*motion.swing_travel
		if yaw==0:reference=local_heading
		else:check(local_heading.distance_to(reference)<.00001,"Rotating a physical stroke preserves its measured heading: "+str(yaw))
	print("CAST_DIRECTION_RESULT ", failures); quit(0 if failures.is_empty() else 1)
