extends SceneTree
const Clubs=preload("res://addons/golfminus/scripts/golf/clubs.gd")
const Solver=preload("res://addons/golfminus/scripts/golf/impact_solver.gd")
const Ball=preload("res://addons/golfminus/scripts/golf/ball_physics.gd")
class Ground extends RefCounted:
	func height(_x:float,_z:float)->float:return 0.0
	func normal_at(_x:float,_z:float)->Vector3:return Vector3.UP
	func lie(_x:float,_z:float)->String:return "fairway"
	func wind()->Vector3:return Vector3.ZERO
	func pin()->Vector3:return Vector3(1000,0,1000)
var failures:Array=[]
func check(ok:bool,label:String)->void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func v(a:Array)->Vector3:return Vector3(a[0],a[1],a[2])
func energy(ball:RefCounted)->float:
	return .5*Ball.MASS*ball.velocity.length_squared()+.2*Ball.MASS*Ball.RADIUS*Ball.RADIUS*ball.spin.length_squared()+Ball.MASS*9.80665*(ball.position.y-Ball.RADIUS)
func _initialize()->void:
	var cases:Array=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/rec4_contacts.json"))
	var regions:Dictionary={};var report:Array=[]
	for row in cases:
		var contact:Dictionary=row.duplicate(true)
		for key in ["normal","contact","head_center","ball_center","ball_velocity","ball_spin","angular_velocity"]:contact[key]=v(row[key])
		contact.head_basis=Basis(v(row.head_basis[0]),v(row.head_basis[1]),v(row.head_basis[2]))
		var result:Dictionary=Clubs.impact(int(row.club),v(row.filtered_velocity),contact.normal,row.lie,contact)
		check(not result.is_empty(),"Recorded contact has a physical impulse at %.3f s"%row.engine_s)
		if result.is_empty():continue
		check(result.velocity.distance_to(v(row.original_launch))<.0002,"Contact replay preserves recorded impulse before fitting changes")
		regions[result.surface_region]=true
		var local:Vector3=contact.head_basis.transposed()*contact.normal
		check(result.contact_normal_local.distance_to(local)<.00001,"Telemetry identifies the actual local contact normal")
		for hz in [72.0,90.0,120.0]:
			var ball:=Ball.new();ball.model=Ground.new();ball.place(Vector3(0,Ball.RADIUS,0));ball.launch(result.velocity,result.spin)
			var previous:=energy(ball);var passive:=true;var outside:=true
			for i in int(hz*.5):
				ball.step(1.0/hz)
				var current:=energy(ball)
				passive=passive and current<=previous+.001;previous=current
				outside=outside and ball.position.y>=Ball.RADIUS-.00001 and ball.position.is_finite()
			check(passive and outside,"Recorded launch/ground resolution stays passive and above turf %.3f / %s"%[row.engine_s,hz])
		report.append({"engine_s":row.engine_s,"club":int(row.club),"region":result.surface_region,"local_normal":[local.x,local.y,local.z],"launch_angle":rad_to_deg(atan2(result.velocity.y,Vector2(result.velocity.x,result.velocity.z).length()))})
	check(regions.has("sole") and regions.has("back") and regions.has("crown"),"Rec4 replay retains whole-head sole, back and crown impacts")
	for normal in [Vector3.FORWARD,Vector3.DOWN,Vector3.UP,Vector3.LEFT,Vector3.RIGHT,Vector3.BACK]:
		check(Solver.surface_region(normal) in ["face","sole","crown","heel","toe","back"],"Each head region is identifiable")
	FileAccess.open("user://rec4-contact-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("REC4_GOLF_REPLAY_RESULT ",failures);quit(0 if failures.is_empty() else 1)
