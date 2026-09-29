extends SceneTree
const Catalog=preload("res://scripts/minigolf/catalog.gd")
const Ball=preload("res://scripts/minigolf/ball.gd")
const Putter=preload("res://scripts/minigolf/putter.gd")
const Rules=preload("res://scripts/minigolf/course_session.gd")
const Fitting=preload("res://scripts/minigolf/fitting.gd")
var failures:Array=[]
var checks:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures.append(message);push_error(message)
func run_ball(b:RefCounted)->void:
	for i in 6000:
		b.tick(1.0/90)
		if not b.moving:return
func _initialize()->void:
	check(Catalog.ALL.size()==preload("res://scripts/locations.gd").CATALOG.size(),"Every water has a course")
	for id in Catalog.ALL:
		var course:Dictionary=Catalog.course(id)
		check(course.holes.size()==18,"18 holes at "+id)
		for hole in course.holes:
			var b:=Ball.new();b.reset(hole)
			check(b.position.distance_to(Catalog.point(hole.cup))>3,"Playable length")
			b.position=Catalog.point(hole.cup)+Vector2(0,.16)
			check(b.strike(Vector2(0,-.3)),"Accept legal putt")
			run_ball(b);check(b.holed,"Cup accessible: "+id+" "+str(hole.number))
	var b:=Ball.new();b.reset(Catalog.course("lakeside").holes[0]);b.strike(Vector2(8,0));b.tick(.1)
	check(absf(b.position.x)<2,"Fast putts remain within rail")
	run_ball(b);check(not b.moving and b.elapsed<36,"Ball settles within bounded time")
	b.reset(Catalog.course("lakeside").holes[6]);var safe:=b.position;b.position=Catalog.point(b.layout.hazards[0].center);b.last_safe=safe;b.moving=true;b.tick(.01)
	check(b.result=="hazard" and b.position==safe,"Water resets to previous lie")
	check(not b.strike(Vector2(NAN,0)),"Reject invalid impulse")
	var hit:=Putter.contact(Vector3(0,.021,.09),Vector3(0,.021,-.02),Vector3(0,.021,0),Vector3.FORWARD,.02)
	check(hit.y<0,"Swept putter face hits ball")
	check(Putter.contact(Vector3(2,0,2),Vector3.ZERO,Vector3.ZERO,Vector3.FORWARD,.01)==Vector2.ZERO,"Tracking jump cannot putt")
	var swing:=Putter.new();swing.sample(Vector3(0,.021,.09),Vector3(0,.021,0),Vector3.FORWARD,.02,false)
	check(swing.sample(Vector3(0,.021,-.02),Vector3(0,.021,0),Vector3.FORWARD,.02,true)==Vector2.ZERO,"Arming inside ball cannot putt")
	var rules:=Rules.new()
	check(rules.command("A","Alice","join",{"course":"lakeside","mode":"competition"},0),"Alice joins")
	check(rules.command("B","Bob","join",{"course":"lakeside","mode":"competition"},0),"Bob joins")
	for who in ["A","B"]:check(rules.command(who,who,"presence",{"present":true},0),"Lobby presence")
	check(rules.command("A","Alice","start",{},0),"Shared round starts")
	for hole in 18:
		for turn in 2:
			var who:String=rules.games.lakeside.turn
			var epoch:int=rules.view(who).epoch
			check(rules.command(who,who,"shot",{"epoch":epoch},1),"Server grants putt")
			check(not rules.command(who,who,"shot",{"epoch":epoch},1),"Reject duplicate stroke")
			check(rules.command(who,who,"settled",{"epoch":epoch,"holed":true},2),"Server accepts cup")
	check(rules.view("A").finished and rules.view("A").scores.size()==18,"Round completion")
	for hand in 2:
		var fit:=Fitting.new();var grip:=Transform3D(Basis.from_euler(Vector3(.4,.2,1.2)),Vector3(-.5 if hand else .5,.85,.2))
		var solved:Dictionary=Fitting.Solver.solve_address(grip,Vector3(0,.021335,0),Vector3.FORWARD,.86,fit.shape,func(_x,_z):return 0.0,fit.heads[hand],fit.rotations[hand],Vector3.ZERO)
		check(not solved.is_empty(),"Preserved address solver reaches ground")
		if not solved.is_empty():check(absf(Fitting.Solver.clearance(Fitting.Solver.head_pose(solved.capture_grip,solved,.86,fit.shape),fit.shape,func(_x,_z):return 0.0)-.004)<.001,"Fitted head clears turf")
	print("MINIGOLF ",checks," checks; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
