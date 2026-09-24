extends SceneTree
const Ball=preload("res://addons/golfminus/scripts/golf/ball_physics.gd")
const Fit=preload("res://addons/golfminus/scripts/golf/club_fit.gd")
const Head=preload("res://addons/golfminus/scripts/golf/club_head.gd")
const Clubs=preload("res://addons/golfminus/scripts/golf/clubs.gd")
class Ground extends RefCounted:
	var grade:=Vector2.ZERO
	var breeze:=Vector3.ZERO
	var turf:="green"
	func height(x:float,z:float)->float:return grade.x*x+grade.y*z
	func normal_at(_x:float,_z:float)->Vector3:return Vector3(-grade.x,1,-grade.y).normalized()
	func lie(_x:float,_z:float)->String:return turf
	func wind()->Vector3:return breeze
	func pin()->Vector3:return Vector3(10000,0,10000)
var failures:Array=[]
func check(ok:bool,label:String)->void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func energy(ball:RefCounted)->float:return .5*Ball.MASS*ball.velocity.length_squared()+.2*Ball.MASS*Ball.RADIUS*Ball.RADIUS*ball.spin.length_squared()+Ball.MASS*9.80665*(ball.position.y-Ball.RADIUS)
func roll(speed:float,spin:Vector3,grade:=Vector2.ZERO,turf:="green")->RefCounted:
	var ball:=Ball.new();ball.model=Ground.new();ball.model.grade=grade;ball.model.turf=turf
	ball.place(Vector3(0,Ball.RADIUS,0));ball.launch(Vector3(0,0,-speed),spin);ball.grounded=true
	var before:=energy(ball);var passive:=true
	for i in 360*15:
		ball.step(1.0/360);var after:=energy(ball)
		passive=passive and after<=before+.00001;before=after
		if not ball.moving:break
	check(passive,"Ground contact remains passive: "+turf+" / "+str(spin))
	return ball
func flight(wind:Vector3,spin:Vector3,hz:=90)->RefCounted:
	var ball:=Ball.new();ball.model=Ground.new();ball.model.breeze=wind
	ball.place(Vector3(0,Ball.RADIUS,0));ball.launch(Vector3(0,18,-60),spin)
	for i in hz*20:
		ball.step(1.0/hz)
		if ball.grounded:break
	return ball
func _initialize()->void:
	var b:=Ball.new();var v:=Vector3(0,0,-50)
	var no_spin:Vector3=b.acceleration(v,Vector3.ZERO,Vector3.ZERO)
	var rifle:Vector3=b.acceleration(v,Vector3(0,0,800),Vector3.ZERO)
	var tiny:Vector3=b.acceleration(v,Vector3(.001,0,800),Vector3.ZERO)
	check(no_spin.distance_to(rifle)<.0001 and tiny.distance_to(rifle)<.001,"Parallel spin produces no lift; near-parallel spin is continuous")
	check(b.acceleration(v,Vector3(300,0,0),Vector3.ZERO).y>no_spin.y,"Backspin lifts a forward-moving ball")
	var pure:=roll(1.83,Vector3(-1.83/Ball.RADIUS,0,0))
	var threshold:float=(.55-Ball.HOLD_ACCEL.green)/Ball.LOW_SPEED_DRAG
	var slow_distance:float=(Ball.LOW_SPEED_DRAG*threshold-Ball.HOLD_ACCEL.green*log(1+Ball.LOW_SPEED_DRAG*threshold/Ball.HOLD_ACCEL.green))/pow(Ball.LOW_SPEED_DRAG,2)
	var expected:float=(1.83*1.83-threshold*threshold)/(2*.55)+slow_distance
	check(absf(pure.roll_distance-expected)<.02,"Green roll agrees with piecewise resistance integral (about 10 ft Stimp)")
	var skid:=roll(3,Vector3.ZERO)
	var backspin:=roll(3,Vector3(150,0,0))
	check(backspin.roll_distance<skid.roll_distance and skid.roll_distance<9/(2*.55),"Skidding and backspin dissipate speed before pure roll")
	var downhill:=roll(2,Vector3(-2/Ball.RADIUS,0,0),Vector2(0,.03))
	check(downhill.roll_distance>roll(2,Vector3(-2/Ball.RADIUS,0,0)).roll_distance,"Downhill slope extends roll")
	var sand:=roll(3,Vector3(-3/Ball.RADIUS,0,0),Vector2.ZERO,"sand")
	check(sand.roll_distance<1.1 and not sand.moving,"Sand stops a rolling ball much sooner than green")
	var calm:=flight(Vector3.ZERO,Vector3(280,0,0))
	var right:=flight(Vector3(2.4,0,0),Vector3(280,0,0))
	var left:=flight(Vector3(-2.4,0,0),Vector3(280,0,0))
	check(absf(calm.position.x)<.001 and right.position.x>0 and absf(right.position.x+left.position.x)<.01,"2.4 m/s wind drift is downwind and mirror symmetric")
	var tilted:=flight(Vector3.ZERO,Vector3(280,100,0))
	check(absf(tilted.position.x)>absf(right.position.x),"A tilted spin axis can curve the shot more than a 2.4 m/s crosswind")
	var high:=flight(Vector3(2.4,0,0),Vector3(280,0,0),120)
	check(high.position.distance_to(right.position)<.3,"Flight is stable across 90/120 Hz")
	print("PHYSICS_COMPARISON ",JSON.stringify({"calm":calm.position,"crosswind_2_4":right.position,"tilted_spin":tilted.position,"green_stimp_m":pure.roll_distance,"skid_m":skid.roll_distance,"backspin_m":backspin.roll_distance,"sand_m":sand.roll_distance}))
	for grade in [Vector2.ZERO,Vector2(.08,-.12),Vector2(-.1,.08)]:
		var ground:=Ground.new();ground.grade=grade
		for index in 8:
			var shape=Head.for_club(index)
			var grip:=Transform3D(Basis.from_euler(Vector3(.4,.2,-.5)),Vector3(-.5,.85,.1))
			var fit:Dictionary=Fit.solve_grounded(grip,Vector3(0,Ball.RADIUS,0),Vector3.FORWARD,Clubs.BAG[index].length,shape,ground.height)
			check(not fit.is_empty(),"Ground fit exists: %d / %s"%[index,grade])
			if fit.is_empty():continue
			var pose:Transform3D=Fit.head_pose(grip,fit,Clubs.BAG[index].length,shape)
			check(pose.basis.is_equal_approx(grip.basis*Basis(Vector3.RIGHT,shape.loft)) and absf(Fit.clearance(pose,shape,ground.height)-.004)<.001,"Auto-fit preserves intended head address orientation and sole clearance: %d / %s"%[index,grade])
			var correction:=Vector3(7,12,-25)
			fit=Fit.solve_grounded(grip,Vector3(0,Ball.RADIUS,0),Vector3.FORWARD,Clubs.BAG[index].length,shape,ground.height,correction)
			check(not fit.is_empty() and fit.head_rotation.is_equal_approx(correction),"Auto-fit preserves explicit head correction: %d / %s"%[index,grade])
	print("GOLF_PHYSICS_REVIEW_RESULT ",failures);quit(0 if failures.is_empty() else 1)
