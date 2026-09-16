extends SceneTree
const S=preload("res://scripts/fishing_session.gd")
const Pull=preload("res://scripts/fight_input.gd")
const Haptics=preload("res://scripts/line_haptics.gd")
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func fight():
	var s=S.new();s.state=S.State.BITE;s.strike();s.distance=24;s.next_cue=100;return s
func run():
	var s=fight();s.stamina=.3;s.cue=0;s.cue_time=.01;s.tension=.55
	s.tick(.02,0,0)
	check(s.failed_counters==1 and absf(s.stamina-.48)<.0001,"Missed counter restores 18 percent stamina")
	check(absf(s.tension-.55)<.005,"Missed counter does not jump or release tension")
	s=fight();s.tension=.96;s.cue=0;s.gesture(0);s.tick(.01,.5,0)
	check(s.tension>.95,"Correct input releases tension gradually instead of snapping to .85")
	for fps in [30,72,90]:
		s=fight();s.tension=.60;s.phase=6;s.next_cue=100
		var elapsed:=0.0;var maximum:=0.0
		while s.state==S.State.FIGHT and elapsed<10:
			var before: float=s.tension;s.tick(1.0/fps,2,1);elapsed+=1.0/fps
			maximum=maxf(maximum,(s.tension-before)*fps)
		check(s.state==S.State.LOST and elapsed>4 and maximum<=S.MAX_TENSION_RISE+.0001,"Gradual tension gives warning/reaction time at "+str(fps)+" FPS")
	var h=Haptics.new();s=fight();h.sample(s,.01);s.tension=.62
	check(h.sample(s,.7).get("kind")=="tension","Haptic tension warning starts before red band")
	check(h.sample(s,.7).get("kind")=="tension","Elevated tension warning repeats even without further rise")
	var pull=Pull.new()
	check(pull.sample(2,Vector3(0,.9,-.5),Basis.IDENTITY,.65)==2,"Already raised rod counters swimming away")
	check(pull.sample(2,Vector3(0,.88,-.5),Basis.IDENTITY,.40)==2,"Raised-rod hysteresis tolerates hand tremor")
	check(pull.sample(2,Vector3(0,.8,-.5),Basis.IDENTITY,.1)==-1,"Lowering rod releases upward counter")
	pull.reset();pull.sample(2,Vector3.ZERO)
	check(pull.sample(2,Vector3(0,.14,0))==2,"Comfortable 14 cm lift engages upward counter")
	var g=load("res://scenes/main.tscn").instantiate();root.add_child(g);await create_timer(.3).timeout
	g.set_process(false);g.motor.set_physics_process(false);g.game.reset();g._update_line()
	check(g.bobber.visible and g.rod_status.bait_visual.visible and g.line_mesh.get_surface_count()==1,"Ready rod carries visible bobber, bait and hanging line")
	check(absf(g.tip.global_position.distance_to(g.bobber.global_position)-.30)<.001,"Float hangs from rod before casting")
	g._select_bait((g.game.bait+1)%S.BAITS.size())
	check(g.rod_status.label.visible and g.rod_status.label.text==S.BAITS[g.game.bait],"Bait change shows its name above rod")
	g.rod_status._process(2.3);check(not g.rod_status.label.visible,"Bait text disappears after a short confirmation")
	g.game.lose("Line snapped.");g._update_line();check(not g.bobber.visible,"Broken line vanishes during loss feedback")
	g.game.tick(1.3,0,0);g._update_line()
	check(g.game.state==S.State.READY and g.bobber.visible,"Loss automatically resets rod and tackle")
	g.game.lose("Line snapped.");g.xr=true;g.fish_guide.held=false;g.menu_open=false;g._right_pressed("trigger_click")
	check(g.casting and g.game.state==S.State.READY,"Trigger gesture rearms immediately after snapped line")
	g.casting=false
	var tracker:=XRPositionalTracker.new();tracker.name="head";tracker.type=XRServer.TRACKER_HEAD;XRServer.add_tracker(tracker)
	tracker.set_pose("default",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	for height in [1.2,1.65,2.1]:
		XRServer.world_scale=1;g.head.position.y=height;g.tracking_manager.seated=false;g.tracking_manager.focused=true;g.tracking_manager.calibration_pending=true
		g.tracking_manager.startup_pose_time=0
		for frame in 16:g.tracking_manager.sample(.02)
		check(not g.tracking_manager.calibration_pending and absf(XRServer.world_scale*height-1.65)<.001,"FPSloppa startup height calibration for "+str(height)+" m player")
		var scale: float=XRServer.world_scale;g.head.position.y=.8;g.tracking_manager.sample(.02)
		check(XRServer.world_scale==scale,"Crouching does not recalibrate avatar/player scale")
	XRServer.world_scale=1;XRServer.remove_tracker(tracker)
	g.xr=false;g.queue_free();await process_frame;await create_timer(.3).timeout
	print("SESSION_FEEDBACK_RESULT ",failures);quit(0 if failures.is_empty() else 1)
