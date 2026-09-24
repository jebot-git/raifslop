extends SceneTree
## Deterministic synthetic tracking stress test; not Quest hardware or WiVRn emulation.
const Ball=preload("res://addons/golfminus/scripts/golf/ball_physics.gd")
const Head=preload("res://addons/golfminus/scripts/golf/club_head.gd")
const Clubs=preload("res://addons/golfminus/scripts/golf/clubs.gd")
const Swing=preload("res://addons/golfminus/scripts/golf/swing_tracker.gd")
const Solver=preload("res://addons/golfminus/scripts/golf/impact_solver.gd")
class Ground extends RefCounted:
	var turf:="green"
	var grade:=Vector2.ZERO
	func height(x:float,z:float)->float:return grade.x*x+grade.y*z
	func normal_at(_x:float,_z:float)->Vector3:return Vector3(-grade.x,1,-grade.y).normalized()
	func lie(_x:float,_z:float)->String:return turf
	func wind()->Vector3:return Vector3.ZERO
	func pin()->Vector3:return Vector3(10000,0,10000)
var rows:Array=[]
var impacts:Array=[]
var surfaces:Array=[]
var landing_surfaces:Array=[]
var rolls:Array=[]
var turf_contacts:Array=[]
var failures:Array=[]
var tracker:XRControllerTracker
var controller:XRController3D
var native:=false
var output:="res://test-results/physics-audit"
var rng:=RandomNumberGenerator.new()
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func vector(v:Vector3)->Array:return [v.x,v.y,v.z]
func head_energy(shape,v:Vector3,w:Vector3,basis:Basis)->float:
	var local:=basis.transposed()*w
	return .5*shape.mass*v.length_squared()+.5*local.dot(shape.inertia*local)
func ball_energy(b)->float:return .5*Ball.MASS*b.velocity.length_squared()+.5*Solver.BALL_INERTIA*b.spin.length_squared()+Ball.MASS*9.80665*(b.position.y-Ball.RADIUS)
func trajectory(shot:Dictionary,turf:String,hz:int)->Dictionary:
	var b:=Ball.new();b.model=Ground.new();b.model.turf=turf
	b.place(Vector3(0,Ball.RADIUS,0));b.launch(shot.velocity,shot.spin)
	var max_gain:=0.0;var before:=ball_energy(b);var first_bounce:Dictionary={}
	for i in hz*45:
		var airborne:bool=not b.grounded
		var vy:float=b.velocity.y
		b.step(1.0/hz)
		var after:=ball_energy(b);max_gain=maxf(max_gain,after-before);before=after
		if airborne and vy<0 and b.velocity.y>=0 and first_bounce.is_empty():first_bounce={"incoming_vertical":vy,"outgoing_vertical":b.velocity.y}
		if not b.moving:break
	return {"turf":turf,"hz":hz,"carry_m":b.carry,"roll_m":b.roll_distance,"end_m":vector(b.position),"peak_m":b.peak,"stop":b.stop_reason,"moving":b.moving,"max_energy_step_gain_j":max_gain,"first_bounce":first_bounce}
func balance(shape,v:Vector3,w:Vector3,hit:Dictionary,shot:Dictionary)->Dictionary:
	var basis:Basis=hit.head_basis
	var efficiency:float=shot.efficiency
	v*=efficiency;w*=efficiency
	var bv:Vector3=hit.get("ball_velocity",Vector3.ZERO);var bs:Vector3=hit.get("ball_spin",Vector3.ZERO)
	var before:=head_energy(shape,v,w,basis)+.5*Ball.MASS*bv.length_squared()+.5*Solver.BALL_INERTIA*bs.length_squared()
	var after:float=head_energy(shape,shot.head_velocity_after,shot.head_angular_velocity_after,basis)+.5*Ball.MASS*shot.velocity.length_squared()+.5*Solver.BALL_INERTIA*shot.spin.length_squared()
	var linear:Vector3=shape.mass*(v-shot.head_velocity_after)+Ball.MASS*(bv-shot.velocity)
	var tensor:Basis=basis*Basis.from_scale(shape.inertia)*basis.transposed()
	var arm:Vector3=hit.contact-hit.head_center+hit.normal*Ball.RADIUS
	var angular:Vector3=tensor*(w-shot.head_angular_velocity_after)+arm.cross(Ball.MASS*(bv-shot.velocity))+Solver.BALL_INERTIA*(bs-shot.spin)
	return {"energy_before_j":before,"energy_after_j":after,"energy_gain_j":after-before,"momentum_error_ns":linear.length(),"angular_momentum_error":angular.length(),"friction_excess_ns":shot.tangent_impulse_ns-shot.friction*shot.normal_impulse_ns}
func run()->void:
	rng.seed=20260923
	native="--native-xr" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(output)
	if native:
		var xr=XRServer.find_interface("OpenXR")
		check(xr!=null and xr.is_initialized(),"Native OpenXR initializes")
		if xr==null or not xr.is_initialized():finish();return
		root.use_xr=true
		var origin:=XROrigin3D.new();root.add_child(origin)
		var camera:=XRCamera3D.new();origin.add_child(camera)
		for frame in 60:await process_frame
		check(xr.get_view_count()==2 and xr.get_session_state()==OpenXRInterface.SESSION_STATE_FOCUSED,"Native simulated stereo session is focused")
	tracker=XRControllerTracker.new();tracker.name="/physics_audit_right";tracker.hand=XRPositionalTracker.TRACKER_HAND_RIGHT;XRServer.add_tracker(tracker)
	controller=XRController3D.new();controller.tracker=tracker.name;controller.pose="grip";root.add_child(controller)
	tracker.set_input("grip",1.0)
	var scenarios:Array=[{"name":"center"},{"name":"toe","offset":Vector2(.035,0)},{"name":"heel","offset":Vector2(-.035,0)},{"name":"high","offset":Vector2(0,.015)},{"name":"low","offset":Vector2(0,-.015)},{"name":"open","yaw":8.0},{"name":"closed","yaw":-8.0},{"name":"out_to_in","path":8.0},{"name":"in_to_out","path":-8.0},{"name":"descending","attack":-8.0},{"name":"ascending","attack":8.0},{"name":"slow","speed":.7},{"name":"jitter","noise":true},{"name":"short_dropout","gap":.033},{"name":"long_dropout","gap":.080},{"name":"wide_miss","offset":Vector2(.13,0)}]
	for seed_case in 24:
		scenarios.append({"name":"human_%02d"%seed_case,"offset":Vector2(rng.randf_range(-.020,.020),rng.randf_range(-.012,.012)),"yaw":rng.randf_range(-6,6),"path":rng.randf_range(-6,6),"attack":rng.randf_range(-6,6),"loft":rng.randf_range(-4,4),"speed":rng.randf_range(.85,1.15),"noise":true})
	for index in 8:
		var shape=Head.for_club(index)
		for hz in [72,90,120]:
			for scenario in scenarios:
				var sample:=Swing.new();var hit:Dictionary={};var statuses:Array=[]
				var speed:float=Clubs.BAG[index].speed*float(scenario.get("speed",1.0))
				var basis:=Basis(Vector3.UP,deg_to_rad(scenario.get("yaw",0.0)))*Basis(Vector3.RIGHT,shape.loft+deg_to_rad(scenario.get("loft",0.0)))
				var offset:Vector2=scenario.get("offset",Vector2.ZERO)
				var velocity:Vector3=Basis(Vector3.UP,deg_to_rad(scenario.get("path",0.0)))*Basis(Vector3.RIGHT,deg_to_rad(scenario.get("attack",0.0)))*Vector3.FORWARD*speed
				var centre:Vector3=-(basis*(shape.face_center+Vector3(offset.x,offset.y,0)))-basis*Vector3.FORWARD*Ball.RADIUS
				var t:float=-.10
				for frame in 40:
					var dt:float=1.0/hz
					if scenario.has("gap") and t<-.02 and t+dt>=-.02:dt=scenario.gap
					t+=dt
					var noise:=Vector3.ZERO;var rot:=basis
					if scenario.get("noise",false):
						noise=Vector3(rng.randf_range(-.002,.002),rng.randf_range(-.002,.002),rng.randf_range(-.002,.002))
						rot=basis*Basis.from_euler(Vector3(rng.randf_range(-.01,.01),rng.randf_range(-.01,.01),rng.randf_range(-.01,.01)))
					tracker.set_pose("grip",Transform3D(rot,centre+velocity*t+noise),velocity,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
					var tracked:XRPose=controller.get_pose()
					hit=sample.sample_pose(tracked.transform,shape,Vector3.ZERO,dt,controller.get_float("grip")>.55)
					statuses.append(sample.last_sample.status)
					if not hit.is_empty() or t>.08:break
				var row:Dictionary={"club":Clubs.BAG[index].name,"hz":hz,"scenario":scenario.name,"contact":not hit.is_empty(),"statuses":statuses}
				if not hit.is_empty():
					var shot:Dictionary=Clubs.impact(index,hit.velocity,hit.normal,"fairway",hit)
					if not shot.is_empty():
						row.merge({"speed_m_s":shot.velocity.length(),"velocity":vector(shot.velocity),"spin_rad_s":vector(shot.spin),"loft_deg":shot.dynamic_loft_degrees,"impulse_ns":shot.normal_impulse_ns,"balance":balance(shape,hit.velocity,hit.angular_velocity,hit,shot)})
						row.flight=trajectory(shot,"fairway",hz)
						if scenario.name=="center" and hz==90:
							for turf in ["green","fringe","fairway","rough","sand","water","out"]:
								var surface_shot:Dictionary=Clubs.impact(index,hit.velocity,hit.normal,turf,hit)
								var result:=trajectory(surface_shot,turf,hz);result.club=Clubs.BAG[index].name;result.launch_m_s=surface_shot.velocity.length();surfaces.append(result)
								var landing:=trajectory(shot,turf,hz);landing.club=Clubs.BAG[index].name;landing_surfaces.append(landing)
				rows.append(row)
			await process_frame
	# Pre-ball terrain resistance through the same synthetic XR pose route.
	for index in 8:
		var shape=Head.for_club(index)
		var bottom:=0.0
		for vertex in shape.surface_points:bottom=minf(bottom,vertex.y)
		for hz in [72,90,120]:
			for surface in ["fairway","rough","sand"]:
				for depth in [-.004,.004]:
					var ground:=Ground.new();ground.turf=surface
					var swing:=Swing.new();var hit:Dictionary={}
					var t:=-.08
					tracker.set_pose("grip",Transform3D(Basis.IDENTITY,Vector3(0,-bottom-depth,-20*t)),Vector3.FORWARD*20,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
					swing.sample_pose(controller.get_pose().transform,shape,Vector3(0,Ball.RADIUS,0),1.0/hz,false,Vector3.ZERO,ground)
					for frame in 20:
						t+=1.0/hz
						tracker.set_pose("grip",Transform3D(Basis.IDENTITY,Vector3(0,-bottom-depth,-20*t)),Vector3.FORWARD*20,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
						hit=swing.sample_pose(controller.get_pose().transform,shape,Vector3(0,Ball.RADIUS,0),1.0/hz,true,Vector3.ZERO,ground)
						if not hit.is_empty() or t>.04:break
					var row:Dictionary={"club":index,"hz":hz,"surface":surface,"depth_m":depth,"contact":not hit.is_empty()}
					if not hit.is_empty():
						row.turf=hit.turf
						var shot:Dictionary=Clubs.impact(index,hit.velocity,hit.normal,surface,hit)
						if not shot.is_empty():row.balance=balance(shape,hit.velocity,hit.angular_velocity,hit,shot)
					turf_contacts.append(row)
		await process_frame
	check(turf_contacts.size()==144 and turf_contacts.all(func(r):return r.contact and r.has("balance")),"144 clean/fat XR pose sweeps strike across clubs, surfaces and cadences")
	check(turf_contacts.all(func(r):return r.contact and ((r.depth_m<0 and r.turf.work_j==0 and r.turf.speed_scale==1) or (r.depth_m>0 and r.turf.work_j>0 and r.turf.speed_scale<1))),"Only measured pre-ball terrain contact attenuates XR swings")
	check(turf_contacts.all(func(r):return r.has("balance") and r.balance.energy_gain_j<.002 and r.balance.momentum_error_ns<.0001),"Turf-adjusted impacts preserve collision momentum and dissipate energy")
	# Broader momentum/energy budget: moving balls, face offsets, angular head motion and clean contacts across lies.
	for i in 2400:
		var shape=Head.for_club(i%8)
		var basis:=Basis.from_euler(Vector3(rng.randf_range(-.2,1),rng.randf_range(-.5,.5),rng.randf_range(-.2,.2)))
		var v:=Vector3(rng.randf_range(-8,8),rng.randf_range(-8,8),-rng.randf_range(.2,55))
		var w:=Vector3(rng.randf_range(-15,15),rng.randf_range(-15,15),rng.randf_range(-15,15))
		var hit:Dictionary={"normal":basis*Vector3.FORWARD,"head_center":Vector3.ZERO,"head_basis":basis,"contact":basis*(shape.face_center+Vector3(rng.randf_range(-.045,.045),rng.randf_range(-.018,.018),0)),"ball_velocity":Vector3(rng.randf_range(-2,2),0,rng.randf_range(-2,2)),"ball_spin":Vector3(rng.randf_range(-100,100),rng.randf_range(-50,50),0)}
		var shot:Dictionary=Solver.solve(shape,v,w,hit,["fairway","rough","sand"][i%3])
		if not shot.is_empty():impacts.append(balance(shape,v,w,hit,shot))
	for turf in ["green","fringe","fairway","rough","sand"]:
		for grade in [Vector2.ZERO,Vector2(0,.03),Vector2(0,-.03)]:
			for hz in [72,90,120]:
				for backspin in [0.0,150.0,-3.0/Ball.RADIUS]:
					var b:=Ball.new();b.model=Ground.new();b.model.turf=turf;b.model.grade=grade
					b.place(Vector3(0,Ball.RADIUS,0));b.launch(Vector3(0,0,-3),Vector3(backspin,0,0));b.grounded=true
					var before:=ball_energy(b);var gain:=0.0
					for frame in hz*45:
						b.step(1.0/hz);var after:=ball_energy(b);gain=maxf(gain,after-before);before=after
						if not b.moving:break
					rolls.append({"turf":turf,"grade":grade.y,"hz":hz,"spin_rad_s":backspin,"distance_m":b.roll_distance,"max_energy_step_gain_j":gain,"stop":b.stop_reason,"downhill":b.velocity.z*grade.y<0})
	check(rows.size()==960,"All 960 tracked swing scenarios completed")
	check(rows.filter(func(r):return r.scenario!="wide_miss" and r.scenario!="long_dropout").all(func(r):return r.has("flight")),"All 912 intended strikes register, including combined human errors")
	check(rows.filter(func(r):return r.scenario=="center").all(func(r):return r.has("speed_m_s")),"Centered swings register for every club at 72/90/120 Hz")
	check(rows.filter(func(r):return r.scenario=="wide_miss" or r.scenario=="long_dropout").all(func(r):return not r.contact),"Wide misses and 80 ms tracking gaps produce no phantom hit")
	check(impacts.all(func(r):return r.energy_gain_j<.002),"2400 sampled impacts remain passive")
	check(impacts.all(func(r):return r.momentum_error_ns<.0001 and r.angular_momentum_error<.0001),"Impact linear/angular momentum conserved")
	check(impacts.all(func(r):return r.friction_excess_ns<.00001),"Coulomb impulse bounds hold")
	check(rows.all(func(r):return not r.has("flight") or (not r.flight.moving and r.flight.stop!="simulation_fail_safe")),"All registered shots settle without fail-safe")
	check(rows.all(func(r):return not r.has("flight") or r.flight.max_energy_step_gain_j<.0001),"Calm flat-ground flight and bounces create no material mechanical energy")
	check(rolls.all(func(r):return r.max_energy_step_gain_j<.0001 and ((r.stop=="moving" and r.downhill) if r.grade!=0 and r.turf in ["green","fringe","fairway"] else r.stop=="rest")),"135 rolling/skid/slope cases dissipate energy and either settle or roll downhill on unbounded slopes")
	check(surfaces.all(func(r):return not r.moving and r.stop!="simulation_fail_safe"),"Surface and hazard shots terminate")
	finish()
func finish()->void:
	var report:Dictionary={"seed":20260923,"native_xr":native,"runtime_manifest":OS.get_environment("XR_RUNTIME_JSON"),"limitations":["Synthetic tracking; not a Quest 3 emulator","No WiVRn transport or device sensor accuracy measured","Prescribed club trajectory; solver recoil is diagnostic, not haptic feedback"],"rows":rows,"impact_budgets":impacts,"surfaces":surfaces,"same_launch_surfaces":landing_surfaces,"rolls":rolls,"turf_contacts":turf_contacts,"failures":failures}
	FileAccess.open(output.path_join("stress-native.json" if native else "stress-headless.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	if tracker!=null:XRServer.remove_tracker(tracker)
	print("GOLF_PHYSICS_STRESS_RESULT ",failures)
	quit(0 if failures.is_empty() else 1)
