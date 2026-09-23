extends SceneTree
const Fit=preload("res://addons/golfminus/scripts/golf/fit_session.gd")
const Solver=preload("res://addons/golfminus/scripts/golf/club_fit.gd")
const Clubs=preload("res://addons/golfminus/scripts/golf/clubs.gd")
const Swing=preload("res://addons/golfminus/scripts/golf/swing_tracker.gd")
const Telemetry=preload("res://addons/golfminus/scripts/golf/shot_telemetry.gd")
var checks:=0
var failures:=0
func check(ok:bool,description:String)->void:
	checks+=1
	if ok:print("PASS ",description)
	else:failures+=1;push_error(description)
func _initialize()->void:call_deferred("run")
func run()->void:
	var rotations:Array[Vector3]=[Vector3(5,10,15),Vector3(30,180,20)]
	var fit:=Fit.new();fit.begin(.8,rotations,1)
	var proposal:={"reach":.95,"rotation":Vector3(20,160,10),"target":Vector3(0,.02,0)}
	check(fit.stage(proposal),"Valid fit can be previewed")
	proposal.rotation=Vector3.ZERO
	check(fit.candidate.rotation!=proposal.rotation and rotations[1]==Vector3(30,180,20),"Preview isolates candidate from live preferences and caller")
	fit.adjust(2,.01)
	check(is_equal_approx(fit.candidate.reach,.96) and fit.baseline.reach==.8,"Fine adjustments affect preview only")
	fit.cancel();check(fit.candidate.is_empty() and fit.undo_state.is_empty(),"Cancel discards preview without accepting or replacing undo")
	fit.begin(.8,rotations,0);fit.stage(proposal)
	var accepted:Dictionary=fit.accept()
	check(accepted.rotations[0]==Vector3.ZERO and accepted.rotations[1]==rotations[1],"Accept changes selected hand only")
	check(is_equal_approx(accepted.reach,.95),"Accept returns preview reach")
	fit.begin(accepted.reach,accepted.rotations,0);fit.stage(proposal);fit.cancel()
	var undone:Dictionary=fit.undo()
	check(undone.reach==.8 and undone.rotations==rotations,"Undo restores full prior fit even after a cancelled preview")
	check(fit.undo().is_empty(),"Undo is consumed once")
	fit.begin(.8,rotations,1)
	check(not fit.stage({"reach":NAN,"rotation":Vector3.ZERO,"target":Vector3.ZERO}),"Nonfinite fit cannot be accepted")
	check(not fit.stage({"reach":2.0,"rotation":Vector3.ZERO,"target":Vector3.ZERO}),"Unreachable fit cannot be accepted")
	check(fit.accept().is_empty(),"Accept before capture does nothing")
	var capture:=Fit.new();capture.begin(1.0,rotations,1)
	for i in 40:capture.sample_pose(Transform3D(Basis.IDENTITY,Vector3(.001*sin(i),1,0)),.012,true)
	check(not capture.stable_pose().is_empty() and absf(capture.stable_pose().pose.origin.x)<.001,"Steady capture averages controller jitter")
	capture.sample_pose(Transform3D(Basis.IDENTITY,Vector3(.1,1,0)),.012,true)
	check(capture.stable_pose().is_empty(),"Moving hand restarts stability window")
	for i in 40:capture.sample_pose(Transform3D(Basis.IDENTITY,Vector3(.1,1,0)),.012,true)
	capture.sample_pose(Transform3D.IDENTITY,.012,false)
	check(capture.stable_pose().is_empty(),"Tracking loss discards stale calibration samples")
	capture.capture_requested=true;capture.cancel()
	check(not capture.capture_requested and capture.samples.is_empty(),"Cancel removes pending automatic capture")
	for index in 8:
		var shape=preload("res://addons/golfminus/scripts/golf/club_head.gd").for_club(index)
		for slope in [0.0,.12,-.12]:
			var ground:Callable=func(x:float,z:float)->float:return x*slope+z*.03
			var grip:=Transform3D(Basis.from_euler(Vector3(.2,-.3,.1)),Vector3(.22,.9,.18))
			var fitted:=Solver.solve_grounded(grip,Vector3(0,.021335,0),Vector3.FORWARD,float(Clubs.BAG[index].length),shape,ground)
			check(not fitted.is_empty(),"Club %d fits slope %.2f"%[index,slope])
			if fitted.is_empty():continue
			var fitted_pose:=Solver.head_pose(grip,fitted,float(Clubs.BAG[index].length),shape)
			check(absf(Solver.clearance(fitted_pose,shape,ground)-Solver.SOLE_CLEARANCE)<.0006,"Club %d actual mesh sole clears terrain"%index)
			var shaft_basis:Basis=grip.basis.orthonormalized()*Basis.from_euler(fitted.rotation*PI/180.0)
			check((shaft_basis.inverse()*fitted_pose.basis).is_equal_approx(Basis(Vector3.RIGHT,shape.loft)),"Club %d fit preserves rigid head-to-shaft loft"%index)
			check(fitted_pose.origin.distance_to(fitted.target)<.0001,"Club %d preview marker matches physical head"%index)
	for index in 8:
		var shape=preload("res://addons/golfminus/scripts/golf/club_head.gd").for_club(index)
		var hit:={"normal":Vector3.FORWARD,"contact":shape.face_center,"head_center":Vector3.ZERO,"head_basis":Basis.IDENTITY}
		var straight:Dictionary=Clubs.impact(index,Vector3(0,0,-2),Vector3.FORWARD,"green",hit)
		var swipe:Dictionary=Clubs.impact(index,Vector3(8,5,-2),Vector3.FORWARD,"green",hit)
		check(is_equal_approx(straight.normal_impulse_ns,swipe.normal_impulse_ns) and swipe.tangent_impulse_ns<=swipe.friction*swipe.normal_impulse_ns+.000001,"Club %d: tangential transfer is friction bounded, not extra normal power"%index)
	check(Clubs.impact(7,Vector3.RIGHT*5,Vector3.FORWARD,"green").is_empty(),"Motion parallel to a flat face produces no impulse")
	check(Clubs.impact(7,Vector3.BACK*5,Vector3.FORWARD,"green").is_empty(),"Backwards putter contact rejected")
	check(Clubs.impact(7,Vector3(NAN,0,0),Vector3.FORWARD,"green").is_empty(),"Nonfinite impact rejected before launch")
	var speeds:Array[float]=[]
	for hz in [72.0,90.0,120.0]:
		var swing:=Swing.new();var dt:float=1.0/hz
		for i in int(hz*.5):swing.sample(Vector3(0,0,-float(i)*dt),Vector3(100,0,0),dt,true)
		speeds.append(swing.filtered_velocity.length())
	check(speeds.max()-speeds.min()<.001,"Swing filter response is stable across 72/90/120 Hz")
	var tracker:=Swing.new();tracker.sample(Vector3.ZERO,Vector3.ZERO,.01,true)
	tracker.sample(Vector3(0,0,-2),Vector3.ZERO,.01,true)
	check(tracker.last_sample.status=="discontinuity" and not tracker.valid,"Tracking jump logged and invalidates swing")
	tracker.sample(Vector3.ZERO,Vector3.ZERO,.1,true)
	check(tracker.last_sample.status=="invalid_interval","Long poll gap invalidates swing")
	var game=preload("res://addons/golfminus/scripts/main.gd").new();root.add_child(game)
	game.set_process(false);game.set_physics_process(false);game.body.set_physics_process(false)
	game.start_practice()
	var original_reach:float=game.club_reach
	var original_rotations:Array=game.club_rotations.duplicate()
	var original_origin:Transform3D=game.origin.transform
	game.fit_session.begin(game.club_reach,game.club_rotations,1);game.fit_session.stage(proposal)
	game.fitting_club=true;game.body.blocked=true
	game._left_button("ax_button")
	check(game.fit_session.axis==1 and game.club_index==7,"Fitting consumes club-change button for fine-adjustment axis")
	check(not game.strike(Vector3.FORWARD,Vector3.FORWARD),"Preview cannot launch a ball")
	game.accept_club_fit()
	check(game.fitting_club and game.club_reach==original_reach,"Untracked controller cannot accept preview")
	game._right_button("by_button")
	check(not game.fitting_club and not game.body.blocked and game.club_rotations==original_rotations and game.origin.transform==original_origin,"Cancel restores play without changing accepted fit or tracking origin")
	check(not game.telemetry.enabled,"Detailed swing capture defaults off")
	game.toggle_analytics();check(game.telemetry.enabled,"User can start local capture")
	var capture_path:String=game.telemetry.path
	for i in 40:game.telemetry.sample_swing({"head":Vector3(i,0,0),"ball":Vector3.ZERO,"dt_s":.014,"active":true,"status":"miss","raw_velocity":Vector3(0,0,-2),"club":7})
	check(game.telemetry.window.size()==24,"Pre-impact sample window is bounded")
	game.telemetry.sample_swing({"head":Vector3.ZERO,"active":false,"status":"inactive","inactive_reason":"grip_released"})
	check(game.telemetry.swing_segment.is_empty(),"Grip release closes a missed swing segment")
	var outcomes:Array[Dictionary]=[]
	game.bridge.shot_completed.connect(func(payload):outcomes.append(payload))
	check(game.strike(Vector3(0,0,-1),Vector3.FORWARD,{"raw_velocity":Vector3(0,0,-1.1)}),"Instrumented putt launches")
	var shot_id:String=game.telemetry.pending.shot_id
	for i in 3000:
		game._physics_process(1.0/90)
		if not game.ball.moving:break
	check(outcomes.size()==1 and outcomes[0].shot_id==shot_id,"Launch and final outcome share one shot ID")
	check(outcomes[0].completed and outcomes[0].roll_path_m>0 and outcomes[0].total_path_m>=outcomes[0].roll_path_m,"Outcome contains completed rolling and travel distances")
	game._complete_shot();check(outcomes.size()==1,"Outcome is emitted only once")
	check(game.strike(Vector3(0,0,-2),Vector3.FORWARD),"Second instrumented shot launches")
	game.load_hole(0)
	check(outcomes.size()==2 and not outcomes[1].completed and outcomes[1].stop_reason=="course_change","Course change closes an interrupted shot explicitly")
	game.toggle_analytics()
	var rows:Array[Dictionary]=[]
	var log_file:=FileAccess.open(capture_path,FileAccess.READ)
	while log_file.get_position()<log_file.get_length():
		var line:=log_file.get_line()
		if not line.is_empty():rows.append(JSON.parse_string(line))
	log_file.close()
	var launches:=0;var completed:=0;var contacts:=0;var misses:=0
	for row in rows:
		if row.type=="shot_launched":
			launches+=1;check(row.data.velocity is Array and row.data.velocity.size()==3,"Telemetry vectors export as numeric JSON arrays")
		if row.type=="shot_completed":completed+=1
		if row.type=="contact_attempt":contacts+=1
		if row.type=="swing_segment_finished" and row.data.contacts==0:
			misses+=1;check(row.data.end_reason=="grip_released" and row.data.samples==40,"Missed swing records sample count and release reason")
	check(misses==1,"No-contact swing is retained once in export")
	check(launches==2 and completed==2 and contacts==2,"JSONL retains matching contact, launch and outcome records")
	check(rows[-1].type=="capture_stopped" and not game.telemetry.enabled,"Stop flushes capture footer and closes recorder")
	game.telemetry.record("ignored",{});check(game.telemetry.queue.is_empty(),"Disabled capture records nothing")
	DirAccess.remove_absolute(capture_path)
	game.queue_free();await process_frame
	print("FITTING / IMPACT / ANALYTICS %d/%d passed"%[checks-failures,checks]);quit(1 if failures else 0)
