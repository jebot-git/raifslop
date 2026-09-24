extends SceneTree
const Ball=preload("res://addons/golfminus/scripts/golf/ball_physics.gd")
const Model=preload("res://addons/golfminus/scripts/golf/course_model.gd")
class Ground extends RefCounted:
	var grade:=0.0
	var turf:="fairway"
	var crest:=false
	func height(x:float,_z:float)->float:return -x*x*2 if crest else grade*x
	func normal_at(x:float,_z:float)->Vector3:return Vector3(4*x if crest else -grade,1,0).normalized()
	func lie(_x:float,_z:float)->String:return turf
	func wind()->Vector3:return Vector3.ZERO
	func pin()->Vector3:return Vector3(10000,0,10000)
var failures:Array=[]
func check(ok:bool,label:String)->void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func energy(b:RefCounted)->float:return .5*Ball.MASS*b.velocity.length_squared()+.2*Ball.MASS*Ball.RADIUS*Ball.RADIUS*b.spin.length_squared()+Ball.MASS*9.80665*b.position.y
func roll(turf:String,speed:float,grade:=0.0,hz:=90.0,skid:=false)->Dictionary:
	var g:=Ground.new();g.turf=turf;g.grade=grade
	var b:=Ball.new();b.model=g;b.place(Vector3(0,b.support_height(0,0),0))
	var velocity:=Vector3(1,grade,0).normalized()*speed
	b.launch(velocity,Vector3.ZERO if skid else g.normal_at(0,0).cross(velocity)/Ball.RADIUS);b.grounded=true
	var reversed:=false;var gain:=0.0;var before:=energy(b)
	for i in int(hz*20):
		b.step(1.0/hz);reversed=reversed or b.velocity.x<-.05
		var after:=energy(b);gain=maxf(gain,after-before);before=after
		if not b.moving:break
	return {"distance":b.roll_distance,"reversed":reversed,"moving":b.moving,"gain":gain}
func vec(a:Array)->Vector3:return Vector3(a[0],a[1],a[2])
func _initialize()->void:
	for skid in [false,true]:
		for hz in [72.0,90.0,120.0]:
			var fair:=roll("fairway",15,0,hz,skid);var rough:=roll("rough",15,0,hz,skid);var sand:=roll("sand",15,0,hz,skid)
			print("SURFACE_COMPARISON ",JSON.stringify({"hz":hz,"skid":skid,"fairway":fair,"rough":rough,"sand":sand}))
			check(rough.distance<fair.distance*.5 and sand.distance<rough.distance*.5,"Fast rough/sand travel differs substantially, including skids %s/%s"%[hz,skid])
			check(fair.gain<.0001 and rough.gain<.0001 and sand.gain<.0001,"Material drag cannot inject energy %s/%s"%[hz,skid])
	for turf in ["green","fairway","rough"]:
		var grade:float={"green":.03,"fairway":.06,"rough":.12}[turf]
		for hz in [72.0,90.0,120.0]:
			check(roll(turf,1.5,grade,hz).reversed,"Uphill ball reverses on playable slope %s/%s"%[turf,hz])
	check(not roll("sand",1.5,.1).reversed,"Soft sand can hold an embedded ball on a moderate slope")
	check(not roll("green",1.5,.005).moving,"Shallow stable slope still settles")
	var a:=roll("rough",15,0,72);var b:=roll("rough",15,0,120)
	check(absf(a.distance-b.distance)<.05,"Strong material drag remains stable at headset cadences")
	var ground:=Ground.new();ground.grade=.3
	var ball:=Ball.new();ball.model=ground
	var centre:=Vector3(1,ball.support_height(1,0),0)
	check(absf(ground.normal_at(1,0).dot(centre)-Ball.RADIUS)<.00001,"Sphere support matches slope-normal radius")
	ground.crest=true;ball.place(Vector3(-.1,ball.support_height(-.1,0),0))
	var v:=Vector3(1,.4,0).normalized()*10
	ball.launch(v,ground.normal_at(-.1,0).cross(v)/Ball.RADIUS);ball.grounded=true;ball.step(1.0/90)
	check(not ball.grounded,"Ball separates from a sharp convex crest")
	for course in ["dalkey","alpine","spyglass","poppy"]:
		var m:=Model.new();m.load_course(course)
		for hole in 18:
			m.load_course(course,hole)
			for kind in ["club","back","forward"]:
				var tee:=m.tee(kind)
				check(absf(tee.y-m.height(tee.x,tee.z)-Ball.RADIUS-Ball.TEE_HEIGHT)<.00002,"Tee holds ball 35 mm above turf %s/%s/%s"%[course,hole,kind])
	var recorded:Array=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/rec5_shots.json"))
	for shot in recorded:
		var model:=Model.new();model.load_course(shot.course,int(shot.hole))
		var replay:=Ball.new();replay.model=model;replay.place(vec(shot.origin));replay.launch(vec(shot.velocity),vec(shot.spin))
		for i in 90*180:
			replay.step(1.0/90)
			if not replay.moving:break
		print("REC5_TERRAIN ",shot.shot_id," roll=",replay.roll_distance," travel=",replay.travel_distance," at=",replay.position," velocity=",replay.velocity," normal=",model.normal_at(replay.position.x,replay.position.z)," lie=",model.lie(replay.position.x,replay.position.z))
		check(not replay.moving and not replay.hazard,"Recorded terrain replay settles: "+shot.shot_id)
		if shot.shot_id.ends_with("shot-5"):check(replay.roll_distance<30,"Recorded shallow sand shot no longer rolls 214 metres")
	print("REC5_TERRAIN_RESULT ",failures);quit(0 if failures.is_empty() else 1)
