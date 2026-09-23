extends SceneTree
const Ball=preload("res://addons/golfminus/scripts/golf/ball_physics.gd")
const Turf=preload("res://addons/golfminus/scripts/golf/club_turf.gd")
const Head=preload("res://addons/golfminus/scripts/golf/club_head.gd")
const Swing=preload("res://addons/golfminus/scripts/golf/swing_tracker.gd")
const Clubs=preload("res://addons/golfminus/scripts/golf/clubs.gd")
class Ground:
	extends RefCounted
	var surface:="green"
	var slope:=0.0
	var transition:=false
	func height(x:float,_z:float)->float:return slope*x
	func normal_at(_x:float,_z:float)->Vector3:return Vector3(-slope,1,0).normalized()
	func lie(_x:float,z:float)->String:return "sand" if transition and z<-.5 else surface
	func wind()->Vector3:return Vector3.ZERO
	func pin()->Vector3:return Vector3(1000,0,0)
var failures:Array=[]
func check(ok:bool,label:String)->void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func energy(ball:RefCounted)->float:
	return .5*Ball.MASS*ball.velocity.length_squared()+.2*Ball.MASS*Ball.RADIUS*Ball.RADIUS*ball.spin.length_squared()
func resistance(surface:String,depth:float,hz:float)->Dictionary:
	var ground:=Ground.new();ground.surface=surface
	var shape=Head.for_club(3)
	var bottom:=0.0
	for point in shape.surface_points:bottom=minf(bottom,point.y)
	var turf:=Turf.new()
	var duration:=.1
	var count:=int(hz*duration)
	var dt:=duration/count
	for i in count:
		var start:=Transform3D(Basis.IDENTITY,Vector3(0,-bottom-depth,.3-i*dt*3))
		var finish:=Transform3D(Basis.IDENTITY,start.origin+Vector3.FORWARD*3*dt)
		turf.sweep(start,finish,shape,ground,dt,1,Vector3.FORWARD*3)
	return turf.attenuate(Vector3.FORWARD*3,Vector3.ZERO,shape,Basis.IDENTITY)
func _initialize()->void:
	var b:=Ball.new()
	for surface in Ball.SURFACES:
		for angle in [5.0,30.0,65.0]:
			for spin in [-600.0,0.0,600.0]:
				for slope in [0.0,.15]:
					var n:=Vector3(-slope,1,0).normalized()
					b.velocity=Vector3.FORWARD*20*cos(deg_to_rad(angle))-n*20*sin(deg_to_rad(angle))
					b.spin=Vector3.RIGHT*spin
					var before:=energy(b)
					var incoming:=b.velocity
					var vn:=incoming.dot(n)
					var slip:Vector3=incoming-n*vn+b.spin.cross(-n*Ball.RADIUS)
					var landing:=b.landing_contact(n,surface)
					var impulse:Vector3=(b.velocity-incoming)*Ball.MASS
					var tangent:Vector3=landing.friction_impulse_ns
					slip=landing.slip_before_friction
					check(energy(b)<=before+.00001 and tangent.length()<=Ball.LANDING_FRICTION[surface]*impulse.dot(n)+.00001,"Passive friction-bounded landing %s / %s / %s / %s"%[surface,angle,spin,slope])
					var after_slip:Vector3=b.velocity-n*b.velocity.dot(n)+b.spin.cross(-n*Ball.RADIUS)
					check(after_slip.length()<=slip.length()+.0001 and after_slip.dot(slip)>=-.001,"Landing reduces contact slip without reversing it")
	# Backspin transfers a larger opposing impulse than an otherwise identical landing.
	var speeds:Array=[]
	for spin in [0.0,400.0]:
		b.velocity=Vector3(0,-20,-15);b.spin=Vector3(spin,0,0)
		b.landing_contact(Vector3.UP,"green");speeds.append(-b.velocity.z)
	check(speeds[1]<speeds[0]-1,"Backspin checks forward speed on a green landing")
	var landing_speeds:Array=[]
	for descent in [1.0,15.0]:
		b.velocity=Vector3(0,-descent,-10);b.spin=Vector3(-10/Ball.RADIUS,0,0)
		var landing:=b.landing_contact(Vector3.UP,"green")
		landing_speeds.append(-b.velocity.z)
		check(landing.deformation_impulse_ns.z>0,"Compliant turf resists a landing even without initial slip")
	check(landing_speeds[1]<landing_speeds[0],"Steeper arrival dissipates more energy through turf deformation")
	var clean:=resistance("fairway",-.004,90)
	var shallow:=resistance("fairway",.002,90)
	var deep:=resistance("fairway",.008,90)
	var rough:=resistance("rough",.008,90)
	var sand:=resistance("sand",.008,90)
	check(clean.speed_scale==1 and clean.work_j==0,"Clear sole loses no energy")
	check(shallow.speed_scale<1 and deep.speed_scale<shallow.speed_scale,"Deeper fat strike loses more energy")
	check(rough.requested_work_j>deep.requested_work_j and sand.requested_work_j>rough.requested_work_j,"Rough and bunker resistance exceed fairway")
	for hz in [72.0,90.0,120.0]:
		var result:=resistance("fairway",.002,hz)
		check(absf(result.work_j-shallow.work_j)<.0001,"Turf work is stable at %s Hz"%hz)
		check(absf(result.incoming_energy_j*(1-result.speed_scale*result.speed_scale)-result.work_j)<.00001,"Turf speed attenuation accounts for dissipated energy")
	# A sweep past a raised ball is clean until impact; later terrain cannot affect it.
	var shape=Head.for_club(7)
	var ground:=Ground.new();ground.surface="fairway"
	var start:=Transform3D(Basis.IDENTITY,Vector3(0,.08,.2))
	var finish:=Transform3D(Basis.IDENTITY,Vector3(0,-.06,-.2))
	var tracker:=Swing.new()
	tracker.sample_pose(start,shape,Vector3(0,.045,0),.01,false,Vector3.ZERO,ground)
	var hit:=tracker.sample_pose(finish,shape,Vector3(0,.045,0),.01,true,Vector3.ZERO,ground)
	check(not hit.is_empty() and hit.turf.work_j==0,"Follow-through ground contact cannot penalize earlier clean ball contact")
	var fat_tracker:=Swing.new()
	start.origin=Vector3(0,.009,.2);finish.origin=Vector3(0,.009,-.2)
	fat_tracker.sample_pose(start,shape,Vector3(0,Ball.RADIUS,0),.02,false,Vector3.ZERO,ground)
	var fat:=fat_tracker.sample_pose(finish,shape,Vector3(0,Ball.RADIUS,0),.02,true,Vector3.ZERO,ground)
	check(not fat.is_empty() and fat.turf.work_j>0 and fat.velocity.length()<fat.raw_velocity.length(),"Tracker applies pre-ball sole resistance to effective impact speed")
	fat_tracker.turf.work_j=10;fat_tracker.reset()
	check(fat_tracker.turf.work_j==0,"Tracking reset clears stored terrain losses")
	fat_tracker.turf.work_j=10;fat_tracker.sample_pose(start,shape,Vector3.ZERO,.01,false,Vector3.ZERO,ground)
	check(fat_tracker.turf.work_j==0,"Grip release clears stored terrain losses")
	var turf:=Turf.new();turf.work_j=10;turf.direction=Vector3.BACK
	turf.sweep(Transform3D(Basis.IDENTITY,Vector3(0,1,.1)),Transform3D(Basis.IDENTITY,Vector3(0,1,0)),shape,ground,.01,1,Vector3.FORWARD*10)
	check(turf.work_j==0,"Swing reversal discards backswing resistance")
	# Rotated mesh support must agree with all-vertex clearance on planar slopes.
	for tilt in [0.0,.4,1.2]:
		ground.slope=.12
		var basis:=Basis(Vector3.FORWARD,tilt)
		var lowest:=INF
		for vertex in shape.surface_points:
			var point:Vector3=basis*vertex
			lowest=minf(lowest,point.y-ground.height(point.x,point.z))
		var pose:=Transform3D(basis,Vector3(0,-lowest-.004,0))
		var rotated:=Turf.new()
		rotated.sweep(pose,Transform3D(basis,pose.origin+Vector3.FORWARD*.1),shape,ground,.01,1,Vector3.FORWARD*10)
		check(absf(rotated.max_depth_m-.004)<.00001,"Rotated sole/toe contact matches mesh clearance on slope")
	ground.slope=0
	turf.work_j=10
	for i in 20:turf.sweep(start,start,shape,ground,.01,1,Vector3.ZERO)
	check(turf.work_j==0,"Stationary address clears stale turf work")
	var clean_shot:Dictionary=Clubs.impact(3,Vector3.FORWARD*20,Vector3.FORWARD,"fairway")
	for lie in ["rough","sand"]:
		var shot:Dictionary=Clubs.impact(3,Vector3.FORWARD*20,Vector3.FORWARD,lie)
		check(shot.velocity.is_equal_approx(clean_shot.velocity) and shot.spin.is_equal_approx(clean_shot.spin),"Clean contact has no fixed "+lie+" penalty")
	var distances:Array=[]
	for transition in [false,true]:
		ground=Ground.new();ground.transition=transition;b=Ball.new();b.model=ground;b.place(Vector3(0,Ball.RADIUS,0))
		b.launch(Vector3.FORWARD*3,Vector3(-3/Ball.RADIUS,0,0));b.grounded=true
		for i in 3000:
			b.step(1.0/90)
			if not b.moving:break
		distances.append(-b.position.z)
		check(not b.moving and not b.hazard,"Rolling ball settles across surface boundary")
	check(distances[1]<distances[0]*.4 and distances[1]>.5,"Green-to-bunker transition increases rolling resistance")
	print("GOLF_TURF_CONTACT_RESULT ",failures)
	quit(0 if failures.is_empty() else 1)
