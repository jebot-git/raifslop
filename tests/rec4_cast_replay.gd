extends SceneTree
const Motion=preload("res://scripts/cast_motion.gd")
const Sampler=preload("res://scripts/cast_pose_sampler.gd")
var failures:Array=[]
func check(ok:bool,label:String)->void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func pose(row:Dictionary,turn:Basis)->Transform3D:
	return Transform3D(turn*Basis(Quaternion(row.q[0],row.q[1],row.q[2],row.q[3])),turn*Vector3(row.p[0],row.p[1],row.p[2]))
func replay(c:Dictionary,hz:float,yaw:float)->Dictionary:
	var turn:=Basis(Vector3.UP,yaw)
	var sampler:=Sampler.new();var first:=pose(c.seed,turn);sampler.reset(first)
	var motion:=Motion.new();motion.begin(first*Sampler.HELD_POSE,Motion.controller_axis(first*Sampler.HELD_POSE))
	var timeline:Array[Dictionary]=[{"t":0.0,"pose":first}];var duration:=0.0
	for row in c.samples:
		duration+=float(row.dt);timeline.append({"t":duration,"pose":pose(row,turn)})
	var index:=1;var t:=0.0;var rejected:=0
	while t<duration-.000001:
		var dt:=minf(1.0/hz,duration-t);t+=dt
		while index<timeline.size()-1 and timeline[index].t<t:index+=1
		var a:Dictionary=timeline[index-1];var b:Dictionary=timeline[index]
		var current:Transform3D=a.pose.interpolate_with(b.pose,clampf((t-a.t)/(b.t-a.t),0,1))
		var sample:=sampler.sample(current,dt,true)
		if sample.is_empty():rejected+=1;continue
		motion.sample_controller(sample.movement,dt,current*Sampler.HELD_POSE,motion.axis,motion.committed())
	return {"speed":motion.swing_speed,"direction":turn.inverse()*motion.swing_travel.normalized(),"committed":motion.committed(),"rejected":rejected}
func _initialize()->void:
	var cases:Array=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/rec4_casts.json"))
	for c in cases:
		var reference:=replay(c,72,0)
		print("REPLAY ",c.attempt," ",reference)
		for hz in [72.0,90.0,120.0]:
			for yaw in [0.0,.7,-1.4]:
				var r:=replay(c,hz,yaw)
				check(r.rejected==0,"Recorded controller motion survives pose validation %d / %s / %s"%[c.attempt,hz,yaw])
				if int(c.attempt)==4:
					check(not r.committed,"Stationary recorded hold cannot cast");continue
				check(r.committed and r.speed>15,"Recorded fast stroke completes with measured power %d / %s / %s"%[c.attempt,hz,yaw])
				check(r.direction.dot(reference.direction)>.97,"Heading survives cadence and playspace rotation %d / %s / %s"%[c.attempt,hz,yaw])
	var sampler:=Sampler.new();sampler.reset(Transform3D.IDENTITY)
	check(sampler.sample(Transform3D(Basis.IDENTITY,Vector3(2,0,0)),1.0/72,true).is_empty(),"Hand teleport is rejected")
	check(sampler.sample(Transform3D(Basis(Vector3.UP,PI),Vector3(2,0,0)),1.0/72,true).is_empty(),"Quaternion discontinuity is rejected")
	check(sampler.sample(Transform3D.IDENTITY,.2,true).is_empty(),"Long frame cannot supply cast motion")
	check(sampler.sample(Transform3D.IDENTITY,.014,false).is_empty(),"Untracked pose cannot supply cast motion")
	check(sampler.sample(Transform3D.IDENTITY,.014,true).is_empty(),"Tracking recovery seeds a fresh baseline")
	var motion:=Motion.new();motion.begin(Transform3D.IDENTITY,Vector3.FORWARD)
	motion.sample_controller(Vector3.BACK*.12,.04,Transform3D.IDENTITY,Vector3.FORWARD,false)
	motion.sample_controller(Vector3.FORWARD*.2,.04,Transform3D.IDENTITY,Vector3.FORWARD,false)
	check(motion.committed(),"Initial deliberate stroke commits")
	motion.sample_controller(Vector3.BACK*.12,.04,Transform3D.IDENTITY,Vector3.FORWARD,true)
	check(not motion.committed() and motion.swing_speed==0 and motion.swing_travel==Vector3.ZERO,"Fresh backswing cannot release a stale completed stroke")
	motion.sample_controller(Vector3.FORWARD*.04,.04,Transform3D.IDENTITY,Vector3.FORWARD,false)
	check(not motion.committed(),"Partial new forward stroke remains ineligible")
	motion.sample_controller(Vector3.FORWARD*.12,.04,Transform3D.IDENTITY,Vector3.FORWARD,false)
	check(motion.committed(),"Completing the new forward stroke rearms release")
	print("REC4_CAST_REPLAY_RESULT ",failures);quit(0 if failures.is_empty() else 1)
