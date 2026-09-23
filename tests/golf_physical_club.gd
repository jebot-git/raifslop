extends SceneTree
const Head=preload("res://addons/golfminus/scripts/golf/club_head.gd")
const Solver=preload("res://addons/golfminus/scripts/golf/impact_solver.gd")
const Swing=preload("res://addons/golfminus/scripts/golf/swing_tracker.gd")
const Clubs=preload("res://addons/golfminus/scripts/golf/clubs.gd")
var checks:=0
var failed:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if ok:print("PASS ",message)
	else:failed+=1;push_error(message)
func hit(shape:RefCounted,offset:Vector2=Vector2.ZERO,basis:Basis=Basis.IDENTITY)->Dictionary:
	return {"normal":basis*Vector3.FORWARD,"contact":basis*(shape.face_center+Vector3(offset.x,offset.y,0)),"head_center":Vector3.ZERO,"head_basis":basis}
func energy(shape:RefCounted,v:Vector3,w:Vector3,basis:Basis)->float:
	var local:=basis.transposed()*w
	return .5*shape.mass*v.length_squared()+.5*local.dot(shape.inertia*local)
func _initialize()->void:call_deferred("run")
func run()->void:
	var putter=Head.for_club(7);var driver=Head.for_club(0)
	var centre:=Solver.solve(driver,Vector3.FORWARD*40,Vector3.ZERO,hit(driver),"fairway")
	var toe:=Solver.solve(driver,Vector3.FORWARD*40,Vector3.ZERO,hit(driver,Vector2(.035,0)),"fairway")
	var heel:=Solver.solve(driver,Vector3.FORWARD*40,Vector3.ZERO,hit(driver,Vector2(-.035,0)),"fairway")
	check(toe.velocity.length()<centre.velocity.length() and heel.velocity.length()<centre.velocity.length(),"Off-centre impact loses speed through head rotation")
	check(toe.spin.y*heel.spin.y<0 and absf(toe.spin.y)>10,"Heel and toe produce opposite gear-effect spin")
	var high:=Solver.solve(driver,Vector3.FORWARD*40,Vector3.ZERO,hit(driver,Vector2(0,.015)),"fairway")
	var low:=Solver.solve(driver,Vector3.FORWARD*40,Vector3.ZERO,hit(driver,Vector2(0,-.015)),"fairway")
	check(high.spin.x*low.spin.x<0,"High and low face impacts change vertical gear effect")
	var flat:=Solver.solve(putter,Vector3.FORWARD*2,Vector3.ZERO,hit(putter),"green")
	var lofted:=Solver.solve(putter,Vector3.FORWARD*2,Vector3.ZERO,hit(putter,Vector2.ZERO,Basis(Vector3.RIGHT,.25)),"green")
	check(lofted.velocity.y>flat.velocity.y+.1 and absf(lofted.spin.x)>absf(flat.spin.x),"Dynamic loft changes launch elevation and backspin")
	var open:=Solver.solve(putter,Vector3.FORWARD*2,Vector3.ZERO,hit(putter,Vector2.ZERO,Basis(Vector3.UP,.2)),"green")
	var closed:=Solver.solve(putter,Vector3.FORWARD*2,Vector3.ZERO,hit(putter,Vector2.ZERO,Basis(Vector3.UP,-.2)),"green")
	check(open.velocity.x*closed.velocity.x<0,"Open and closed faces launch to opposite sides")
	var path_right:=Solver.solve(putter,Vector3(.7,0,-2),Vector3.ZERO,hit(putter),"green")
	var path_left:=Solver.solve(putter,Vector3(-.7,0,-2),Vector3.ZERO,hit(putter),"green")
	check(path_right.spin.y*path_left.spin.y<0,"Face-to-path difference produces opposite spin axes")
	var down:=Solver.solve(driver,Vector3(0,-4,-40),Vector3.ZERO,hit(driver,Vector2.ZERO,Basis(Vector3.RIGHT,.2)),"fairway")
	var up:=Solver.solve(driver,Vector3(0,4,-40),Vector3.ZERO,hit(driver,Vector2.ZERO,Basis(Vector3.RIGHT,.2)),"fairway")
	check(down.spin.length()>up.spin.length() and down.velocity.y<up.velocity.y,"Attack angle changes spin loft and launch")
	check(Solver.solve(driver,Vector3.BACK,Vector3.ZERO,hit(driver),"fairway").is_empty(),"Separating head cannot impart an impulse")
	check(Solver.solve(driver,Vector3(NAN,0,0),Vector3.ZERO,hit(driver),"fairway").is_empty(),"Invalid physical input rejected")
	var rng:=RandomNumberGenerator.new();rng.seed=8421
	var passive:=true;var momentum:=true;var angular_momentum:=true;var friction_bounded:=true
	for i in 300:
		var shape=Head.for_club(i%8)
		var basis:=Basis.from_euler(Vector3(rng.randf_range(-.3,.9),rng.randf_range(-.5,.5),rng.randf_range(-.3,.3)))
		var v:=Vector3(rng.randf_range(-10,10),rng.randf_range(-8,8),-rng.randf_range(1,55))
		var w:=Vector3(rng.randf_range(-20,20),rng.randf_range(-20,20),rng.randf_range(-20,20))
		var contact:Dictionary=hit(shape,Vector2(rng.randf_range(-.05,.05),rng.randf_range(-.02,.02)),basis)
		var result:=Solver.solve(shape,v,w,contact,"fairway")
		if result.is_empty():continue
		var before:=energy(shape,v,w,basis)
		var after:float=energy(shape,result.head_velocity_after,result.head_angular_velocity_after,basis)+.5*Solver.MASS*result.velocity.length_squared()+.5*Solver.BALL_INERTIA*result.spin.length_squared()
		passive=passive and after<=before+.001
		momentum=momentum and (shape.mass*v-shape.mass*result.head_velocity_after-Solver.MASS*result.velocity).length()<.0001
		var tensor:=basis*Basis.from_scale(shape.inertia)*basis.transposed()
		var ball_centre:Vector3=contact.contact+contact.normal*Solver.RADIUS
		var angular_after:Vector3=tensor*result.head_angular_velocity_after+ball_centre.cross(Solver.MASS*result.velocity)+Solver.BALL_INERTIA*result.spin
		angular_momentum=angular_momentum and (tensor*w-angular_after).length()<.00001
		friction_bounded=friction_bounded and result.tangent_impulse_ns<=result.friction*result.normal_impulse_ns+.000001
	check(passive,"Random angled/off-centre collisions cannot create kinetic energy")
	check(momentum,"Collision conserves total linear momentum")
	check(angular_momentum,"Collision conserves total angular momentum")
	check(friction_bounded,"Every randomized strike respects Coulomb friction bound")
	var start:=Transform3D(Basis.IDENTITY,Vector3(0,0,.4))
	var finish:=Transform3D(Basis.IDENTITY,Vector3(0,0,-.4))
	var contact:Dictionary=putter.sweep(start,finish,Vector3.ZERO)
	check(not contact.is_empty() and not contact.get("initial_overlap",false) and contact.fraction>0 and contact.fraction<1,"Fast whole-head sweep cannot tunnel through stationary ball")
	check(contact.normal.dot(Vector3.FORWARD)>.99 and contact.contact.distance_to(Vector3.ZERO)-Head.BALL_RADIUS<.00002,"CCD returns surface normal and sphere contact point")
	check(not putter.sweep(start,finish,Vector3(.045,0,0)).is_empty(),"Toe contact outside old point radius is detected by head surface")
	check(putter.sweep(start,finish,Vector3(.10,0,0)).is_empty(),"Swing beyond physical toe misses")
	var corner:=Vector3(.052,.014,0)
	var near:Dictionary=putter.nearest(corner+Vector3(0,0,-putter.depth*.5))
	check(near.distance>.0001,"Rounded head excludes empty bounding-box corners")
	var overlap:Dictionary=putter.sweep(Transform3D.IDENTITY,finish,Vector3.ZERO)
	check(overlap.has("normal") and overlap.fraction==0 and overlap.normal.is_normalized(),"Initial overlap reports immediate surface contact; tracker decides whether it is closing")
	var rotated_from:=Transform3D(Basis(Vector3.UP,-.7),Vector3.ZERO)
	var rotated_to:=Transform3D(Basis(Vector3.UP,.7),Vector3.ZERO)
	var spin_contact:Dictionary=putter.sweep(rotated_from,rotated_to,Vector3(.058,0,-.032))
	check(not spin_contact.is_empty() and not spin_contact.get("initial_overlap",false),"Rotation alone sweeps the toe into the ball")
	var bulge:Dictionary=driver.sweep(start,finish,Vector3(.035,0,0))
	check(not bulge.is_empty() and bulge.normal.x>.04,"Driver face curvature changes local impact normal")
	var sole:Dictionary=putter.sweep(Transform3D(Basis.IDENTITY,Vector3(0,.2,0)),Transform3D(Basis.IDENTITY,Vector3(0,-.2,0)),Vector3.ZERO)
	check(not sole.is_empty() and sole.normal.y<-.9,"Sole strikes use the sole normal instead of face loft")
	var fast:Dictionary=driver.sweep(Transform3D(Basis.IDENTITY,Vector3(0,0,.65)),Transform3D(Basis.IDENTITY,Vector3(0,0,-.1)),Vector3.ZERO)
	check(not fast.is_empty(),"Driver collision survives 54 m/s at 72 Hz")
	var outcomes:Array[Dictionary]=[]
	for hz in [72.0,90.0,120.0]:
		var tracker:=Swing.new();var dt:float=1.0/hz;var result:Dictionary={}
		for i in int(hz*.6):
			var sample:=tracker.sample_pose(Transform3D(Basis.IDENTITY,Vector3(0,0,.5-2*i*dt)),putter,Vector3.ZERO,dt,true)
			if not sample.is_empty():result=Clubs.impact(7,sample.velocity,sample.normal,"green",sample);break
		outcomes.append(result)
	check(outcomes.all(func(r):return not r.is_empty()),"Physical contacts register at 72, 90 and 120 Hz")
	if outcomes.all(func(r):return not r.is_empty()):
		check(outcomes[0].velocity.distance_to(outcomes[2].velocity)<.01 and outcomes[0].spin.distance_to(outcomes[2].spin)<.01,"Launch speed and spin stable across render rates")
	var game=load("res://addons/golfminus/scripts/main.gd").new();root.add_child(game)
	game.set_process(false);game.set_physics_process(false);game.body.set_physics_process(false)
	game.club_reach=.4;game._update_club_pose();var scale1:Vector3=game.physical_head.global_basis.get_scale()
	game.club_reach=1.6;game._update_club_pose();var scale2:Vector3=game.physical_head.global_basis.get_scale()
	check(scale1.is_equal_approx(Vector3.ONE) and scale2.is_equal_approx(Vector3.ONE),"Reach adjustment cannot resize physical clubhead")
	check(game.physical_head.mesh==game.head_shape.mesh,"Visible clubhead uses exact collision mesh")
	game.start_practice();game.set_club(0)
	var live_contact:Dictionary=driver.sweep(Transform3D(Basis.IDENTITY,game.ball.position+Vector3(0,0,.4)),Transform3D(Basis.IDENTITY,game.ball.position+Vector3(0,0,-.4)),game.ball.position)
	var expected:Dictionary=Clubs.impact(0,Vector3.FORWARD*40,live_contact.normal,"green",live_contact)
	check(game.strike(Vector3.FORWARD*40,live_contact.normal,live_contact),"Gameplay accepts a swept mesh contact")
	check(game.ball.velocity.is_equal_approx(expected.velocity) and game.ball.spin.is_equal_approx(expected.spin),"Ball flight receives the solved impulse and spin without preset caps")
	var serialized:Dictionary=preload("res://addons/golfminus/scripts/golf/shot_telemetry.gd").serializable(live_contact)
	check(serialized.head_pose is Dictionary and serialized.head_pose.basis is Array,"Contact pose exports as numeric analytics data")
	for kind in ["driver","iron","putter"]:
		var asset=load("res://addons/golfminus/assets/models/%s.glb"%kind).instantiate()
		var shaft:MeshInstance3D=asset.find_child("*concentric shaft*",true,false)
		var centered:=false
		if shaft!=null:
			var bounds:AABB=shaft.transform*shaft.get_aabb()
			centered=absf(bounds.get_center().x)<.0001 and absf(bounds.get_center().z)<.0001
		check(centered,kind+" shaft is concentric with the rubber grip")
		asset.free()
	game.release_borrowed_rig();game.queue_free();await process_frame
	print("PHYSICAL CLUB ",checks-failed,"/",checks," passed");quit(1 if failed else 0)
