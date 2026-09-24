extends SceneTree
const Ball=preload("res://addons/golfminus/scripts/golf/ball_physics.gd")
const Clubs=preload("res://addons/golfminus/scripts/golf/clubs.gd")
const Model=preload("res://addons/golfminus/scripts/golf/course_model.gd")
const Round=preload("res://addons/golfminus/scripts/golf/round.gd")
const Swing=preload("res://addons/golfminus/scripts/golf/swing_tracker.gd")
class Flat:
	extends RefCounted
	var surface:="fairway"
	var wind_vector:=Vector3.ZERO
	var gradient:=0.0
	var cup:=Vector3(1000,0,0)
	func lie(_x:float,_z:float)->String:return surface
	func height(x:float,_z:float)->float:return x*gradient
	func normal_at(_x:float,_z:float)->Vector3:return Vector3(-gradient,1,0).normalized()
	func wind()->Vector3:return wind_vector
	func pin()->Vector3:return cup
var failures:=0
var checks:=0
func check(ok:bool,description:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(description)
	else:print("PASS ",description)
func simulate(index:int,wind:=Vector3.ZERO,hz:=90.0)->RefCounted:
	var b=Ball.new();var f=Flat.new();f.wind_vector=wind;b.model=f;b.place(Vector3(0,Ball.RADIUS,0))
	var shot=Clubs.impact(index,Vector3.FORWARD*Clubs.BAG[index].speed,Vector3.FORWARD,"fairway")
	b.launch(shot.velocity,shot.spin)
	for i in int(hz*30):
		b.step(1/hz)
		if not b.moving:break
	return b
func _initialize()->void:call_deferred("run")
func run()->void:
	var driver=simulate(0)
	print("DRIVER carry=",driver.carry," total=",-driver.position.z," apex=",driver.peak)
	check(driver.carry>170 and driver.carry<310,"Driver full swing carry plausible")
	check(driver.peak>10 and driver.peak<55,"Driver flight apex plausible")
	check(not driver.moving and not driver.hazard,"Full swing settles")
	var iron=simulate(3);print("7 IRON carry=",iron.carry," apex=",iron.peak)
	check(iron.carry>100 and iron.carry<180,"7 iron carry plausible")
	var other=simulate(0,Vector3.ZERO,120)
	check(driver.position.distance_to(other.position)<.5,"Carry/roll stable across 90/120Hz")
	var crosswind=simulate(0,Vector3(5,0,0))
	check(crosswind.position.x>2,"Crosswind moves ball downwind")
	var b=Ball.new();var f=Flat.new();f.surface="green";b.model=f;b.place(Vector3(0,Ball.RADIUS,0));b.launch(Vector3(0,0,-2),Vector3(-2/Ball.RADIUS,0,0));b.grounded=true
	for i in 1800:b.step(1.0/90)
	check(-b.position.z>3.4 and -b.position.z<3.9,"Green rolling resistance: 2m/s putt rolls about 3.6m")
	b.place(Vector3(0,Ball.RADIUS,.3));f.cup=Vector3.ZERO;b.launch(Vector3(0,0,-.8),Vector3.ZERO);b.grounded=true
	for i in 100:b.step(1.0/90)
	check(b.holed,"Slow center putt captured")
	b.place(Vector3(0,Ball.RADIUS,.3));b.launch(Vector3(0,0,-4),Vector3.ZERO);b.grounded=true
	for i in 20:b.step(1.0/90)
	check(not b.holed,"Fast putt rolls over cup")
	b.place(Vector3(.2,Ball.RADIUS,.3));b.launch(Vector3(0,0,-.8),Vector3.ZERO);b.grounded=true
	for i in 100:b.step(1.0/90)
	check(not b.holed,"Off-line putt misses")
	f.surface="water";b.place(Vector3(0,Ball.RADIUS,0));b.launch(Vector3(.2,0,0),Vector3.ZERO);b.step(.02)
	check(b.hazard,"Water lie triggers relief")
	check(not b.launch(Vector3(NAN,0,0),Vector3.ZERO),"Invalid swing rejected")
	var swing=Swing.new();swing.sample(Vector3(0,0,.2),Vector3.ZERO,.01,true)
	swing.cooldown=0
	var hit=swing.sample(Vector3(0,0,-.2),Vector3.ZERO,.01,true)
	check(not hit.is_empty(),"Swept strike cannot tunnel through ball")
	swing.reset();swing.sample(Vector3(0,0,2),Vector3.ZERO,.01,true);swing.cooldown=0
	check(swing.sample(Vector3(0,0,-2),Vector3.ZERO,.01,true).is_empty(),"Tracking discontinuity rejected")
	var r=Round.new();r.start();r.shot(Vector3(1,0,2));r.penalty()
	check(r.strokes==2,"Hazard adds one penalty to shot")
	check(not r.advance(),"Cannot skip an uncompleted hole")
	for i in 18:
		r.complete_hole()
		if i<17:r.advance();r.shot(Vector3.ZERO)
	check(r.finished and r.scores.size()==18,"Complete 18-hole scorecard")
	for id in ["dalkey","alpine"]:
		var m=Model.new();m.load_course(id)
		check(m.course.holes.size()==18,id+" has 18 holes")
		for i in 18:
			m.load_course(id,i)
			check(m.lie(m.pin().x,m.pin().z)=="green" and m.lie(m.tee().x,m.tee().z)=="fairway",id+" hole %d has playable tee and green"%(i+1))
	var saved=Round.new();saved.progress_path="user://golf_test_round.cfg";saved.start();saved.shot(Vector3(1,2,3));saved.strokes=4;saved.complete_hole();saved.advance();saved.shot(Vector3(4,5,6))
	f.surface="fairway";b.place(Vector3(2,1,3));b.launch(Vector3(1,2,-20),Vector3(40,0,0))
	check(saved.save_progress("dalkey","forward",b)==OK,"Round progress saves")
	var cfg=saved.read_progress();var restored=Round.new();var resumed_ball=Ball.new()
	check(cfg!=null,"Saved round validates")
	restored.restore(cfg,resumed_ball)
	check(restored.hole==1 and restored.scores==[4] and restored.strokes==1,"Scorecard and current hole resume")
	check(resumed_ball.position==b.position and resumed_ball.velocity==b.velocity and resumed_ball.spin==b.spin and resumed_ball.moving,"In-flight ball state resumes exactly")
	check(restored.last_safe==saved.last_safe,"Relief point preserved across save")
	b.place(Vector3(0,1,0));b.collision_query=func(a:Vector3,z:Vector3)->Dictionary:
		if a.z>-.2 and z.z<=-.2:return {"normal":Vector3.BACK,"position":Vector3(0,1,-.2)}
		return {}
	b.launch(Vector3(0,0,-10),Vector3.ZERO);b.step(.04)
	check(b.velocity.z>0,"Solid scenery impact reflects ball")
	DirAccess.remove_absolute(saved.progress_path)
	print("RESULT %d/%d passed"%[checks-failures,checks]);quit(1 if failures else 0)
