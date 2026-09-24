extends SceneTree
const Motion=preload("res://scripts/cast_motion.gd")
const Sampler=preload("res://scripts/cast_pose_sampler.gd")
const Preparation=preload("res://scripts/cast_preparation.gd")
var failures:Array=[]
func check(ok:bool,label:String)->void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func pose(f:Dictionary,turn:Basis)->Transform3D:
	return Transform3D(turn*Basis(Quaternion(f.q[0],f.q[1],f.q[2],f.q[3])),turn*Vector3(f.p[0],f.p[1],f.p[2]))
func replay(c:Dictionary,hz:float,yaw:float)->Dictionary:
	var turn:=Basis(Vector3.UP,yaw);var prep:=Preparation.new();var sampler:=Sampler.new();var motion:=Motion.new()
	var frames:Array=c.frames;var t:float=frames[0].us;var end:float=frames[-1].us
	var index:=1;var begun:=false;var prepared:=false
	while t<end:
		var dt:=minf(1.0/hz,(end-t)/1e6);t+=dt*1e6
		while index<frames.size()-1 and float(frames[index].us)<t:index+=1
		var a:Dictionary=frames[index-1];var b:Dictionary=frames[index]
		var current:=pose(a,turn).interpolate_with(pose(b,turn),clampf((t-float(a.us))/(float(b.us)-float(a.us)),0,1))
		if t<float(c.pressed_us):prep.sample(current,dt,true);continue
		if not begun:
			var seed:=prep.backswing();prepared=not seed.is_empty()
			motion.begin(current*Sampler.HELD_POSE,Motion.controller_axis(current*Sampler.HELD_POSE),seed)
			sampler.reset(current);begun=true;continue
		var sample:=sampler.sample(current,dt,true)
		if not sample.is_empty():motion.sample_controller(sample.movement,dt,current*Sampler.HELD_POSE,motion.axis,motion.committed())
	return {"committed":motion.committed(),"speed":motion.swing_speed,"direction":turn.inverse()*motion.swing_travel.normalized(),"prepared":prepared}
func _initialize()->void:
	var cases:Array=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/rec5_casts.json"))
	for c in cases:
		var reference:=replay(c,72,0);print("REC5 ",c.attempt," ",reference)
		for hz in [72.0,90.0,120.0]:
			for yaw in [0.0,.8,-1.5]:
				var r:=replay(c,hz,yaw)
				if int(c.attempt) in [1,2]:check(not r.committed,"Recorded short tap remains rejected %s/%s/%s"%[c.attempt,hz,yaw]);continue
				check(r.committed and r.speed>2,"Recorded swing commits %s/%s/%s"%[c.attempt,hz,yaw])
				check(r.direction.dot(reference.direction)>.95,"Cast heading remains stable across cadence/yaw %s/%s/%s"%[c.attempt,hz,yaw])
				if int(c.attempt) in [21,22,23,39,42]:check(r.direction.z<-.3,"Late-trigger forward swing is not labelled backswing %s/%s/%s"%[c.attempt,hz,yaw])
	var prep:=Preparation.new()
	for i in 60:prep.sample(Transform3D.IDENTITY,1.0/90,true)
	check(prep.backswing().is_empty(),"Stationary preparation cannot supply a cast")
	prep.sample(Transform3D(Basis.IDENTITY,Vector3(3,0,0)),.014,true)
	check(prep.backswing().is_empty(),"Tracking jump clears preparation")
	var motion:=Motion.new();motion.begin(Transform3D.IDENTITY,Vector3.FORWARD,{"axis":Vector3.FORWARD,"back":Vector3.BACK})
	check(not motion.committed() and motion.swing_speed==0,"Preparation alone never supplies power or permits release")
	print("REC5_CAST_REPLAY_RESULT ",failures);quit(0 if failures.is_empty() else 1)
