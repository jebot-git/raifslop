extends SceneTree
const Ball=preload("res://addons/golfminus/scripts/golf/ball_physics.gd")
const Model=preload("res://addons/golfminus/scripts/golf/course_model.gd")
const Profile=preload("res://addons/golfminus/scripts/golf/club_fit_profile.gd")
const Fit=preload("res://addons/golfminus/scripts/golf/club_fit.gd")
const Head=preload("res://addons/golfminus/scripts/golf/club_head.gd")
const Clubs=preload("res://addons/golfminus/scripts/golf/clubs.gd")
var failures:Array=[]
func check(ok:bool,label:String)->void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func vec(a:Array)->Vector3:return Vector3(a[0],a[1],a[2])
func _initialize()->void:
	for hand in 2:
		for index in 8:
			# Natural trail-hand address: thumb end up, little-finger end down
			# toward the ball, palm toward the shot. X is into the right palm
			# and out of the left palm (OpenXR grip convention).
			var lean:float=deg_to_rad(Profile.LEAN_DEGREES[index])
			var side:float=1 if hand==0 else -1
			var x:=Vector3.FORWARD if hand==0 else Vector3.BACK
			var z:=Vector3(-side*sin(lean),-cos(lean),0)
			var address:=Basis(x,z.cross(x),z)
			var shape:=Head.for_club(index)
			for yaw in [0.0,1.1,-2.3]:
				var world:=Basis(Vector3.UP,yaw)
				var grip:=Transform3D(world*address,world*Vector3(side*.5,.9,.1))
				var shaft:=grip.basis*Basis.from_euler(Profile.default_shaft_rotation(hand)*PI/180)
				check((-shaft.y).dot(grip.basis.z)>.99999,"Default shaft follows held handle %d/%d/%s"%[hand,index,yaw])
				var correction:=Profile.default_head_rotation(hand,index)
				var expected:=world*Basis(Vector3.RIGHT,shape.loft)
				var actual:=grip.basis*Basis.from_euler(correction*PI/180)*Basis(Vector3.RIGHT,shape.loft)
				check(actual.is_equal_approx(expected),"Natural grip squares face with authored loft before fitting %d/%d/%s"%[hand,index,yaw])
				var fit:=Fit.solve_grounded(grip,Vector3(0,Ball.RADIUS,0),world*Vector3.FORWARD,Clubs.BAG[index].length,shape,func(_x,_z):return 0.0,correction)
				check(not fit.is_empty() and Fit.head_pose(grip,fit,Clubs.BAG[index].length,shape).basis.is_equal_approx(expected),"Fitting preserves corrected default head %d/%d/%s"%[hand,index,yaw])
	var cfg:=ConfigFile.new();cfg.load("res://tests/fixtures/quest19_golf_controls.cfg")
	var shaft:Vector3=cfg.get_value("golf","club_rotation_1")
	var reach:float=cfg.get_value("golf","reach")
	check(Profile.migrate(cfg),"Captured Quest v2 profile migrates")
	check(cfg.get_value("golf","club_head_rotation_1").is_equal_approx(Profile.default_head_rotation(1,0)),"Captured sideways default corrected even after accepted fitting")
	check(cfg.get_value("golf","club_rotation_1")==shaft and cfg.get_value("golf","reach")==reach,"Migration preserves fitted handle and reach")
	check(cfg.get_value("grip_axis_v2","head_rotation_1")==Vector3(0,0,-32),"Previous head correction archived")
	check(not Profile.migrate(cfg),"New profile migration is idempotent")
	for source in ["explicit","legacy"]:
		cfg.load("res://tests/fixtures/quest19_golf_controls.cfg");cfg.set_value("golf","club_head_source_1",source)
		Profile.migrate(cfg)
		check(cfg.get_value("golf","club_head_rotation_1")==Vector3(0,0,-32) and cfg.get_value("golf","club_rotation_1")==shaft,"Preserve manual or unattributed older calibration: "+source)
	var fresh:=ConfigFile.new();Profile.migrate(fresh)
	for hand in 2:
		check(not fresh.get_value("golf","club_fitted_%d"%hand) and fresh.get_value("golf","club_rotation_%d"%hand).is_equal_approx(Profile.default_shaft_rotation(hand)),"Fresh profile has natural grip without claiming fitted %d"%hand)
	var shot:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/quest19_shot.json"))
	var stops:Array[Vector3]=[]
	for hz in [72.0,90.0,120.0]:
		var model:=Model.new();model.load_course(shot.course,int(shot.hole))
		var ball:=Ball.new();ball.model=model;ball.place(vec(shot.origin));ball.launch(vec(shot.velocity),vec(shot.spin))
		var seconds:=0.0
		while ball.moving and seconds<30:
			ball.step(1/hz);seconds+=1/hz
		stops.append(ball.position)
		print("QUEST19_SHOT ",JSON.stringify({"hz":hz,"seconds":seconds,"moving":ball.moving,"position":ball.position,"roll_m":ball.roll_distance,"reason":ball.stop_reason}))
		check(not ball.moving and ball.stop_reason=="rest" and ball.velocity==Vector3.ZERO,"Recorded Quest shot comes to rest within 30 seconds %s"%hz)
		var stopped:=ball.position
		for i in 120:ball.step(.5)
		check(ball.position==stopped,"Recorded ball remains at rest for subsequent minute %s"%hz)
	check(stops[0].distance_to(stops[1])<.05 and stops[0].distance_to(stops[2])<.05,"Captured shot stopping point stable across headset cadences")
	print("QUEST19_GOLF_REGRESSIONS_RESULT ",failures);quit(0 if failures.is_empty() else 1)
