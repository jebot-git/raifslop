extends SceneTree
var failures:Array=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func settle():
	for i in 5:await process_frame
func run():
	var g=load("res://scenes/main.tscn").instantiate();root.add_child(g)
	await create_timer(.3).timeout;g.set_process(false);g.motor.set_physics_process(false)
	var trackers:Array[XRControllerTracker]=[]
	for side in ["left","right"]:
		var tracker:=XRControllerTracker.new();tracker.name="warning_"+side;XRServer.add_tracker(tracker)
		var node:XRController3D=g.left if side=="left" else g.right
		node.tracker=tracker.name;node.pose="grip"
		tracker.set_pose("grip",Transform3D(Basis.IDENTITY,Vector3(.2,1.2,-.3)),Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
		trackers.append(tracker)
	await settle()
	g.xr=true;g.tracking_manager.focused=true;g._update_tracking_warning(.7)
	check(not g.hud.tracking_lost,"Tracked controllers never show warning")
	g.tracking_manager.focused=false;g._update_tracking_warning(1)
	check(not g.hud.tracking_lost,"Unfocused compositor is not reported as lost controllers")
	g.tracking_manager.focused=true;trackers[0].invalidate_pose("grip");await settle()
	g._update_tracking_warning(.2)
	check(not g.hud.tracking_lost,"Brief tracking dropout does not flash warning")
	g._update_tracking_warning(.31)
	check(g.hud.tracking_lost,"Sustained controller loss still warns")
	g.menu_open=true;g._update_tracking_warning(.01)
	check(not g.hud.tracking_lost,"Menu clears stale warning before its early return")
	g.menu_open=false;g._update_tracking_warning(.6);g.fish_guide.held=true;g._update_tracking_warning(.01)
	check(not g.hud.tracking_lost,"Guide clears stale warning before its early return")
	g.fish_guide.held=false;g._update_tracking_warning(.6)
	trackers[0].set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	await settle();g._update_tracking_warning(.01)
	check(not g.hud.tracking_lost and g.tracking_warning_time==0,"Recovery clears warning immediately")
	# Exercise the actual pause path; warning debounce must not accept stale motion.
	g.xr=false;g.tracking_manager.focused=true
	g.xr=true;g.game.state=g.Session.State.BITE;g.game.timer=1;g.casting=true
	trackers[0].invalidate_pose("grip");await settle()
	g._process(.01)
	check(g.game.timer==1 and not g.casting and not g.hud.tracking_lost,"Fishing pauses immediately during warning grace period")
	for tracker in trackers:XRServer.remove_tracker(tracker)
	g.queue_free();await process_frame;await create_timer(.3).timeout
	print("TRACKING_WARNING_RESULT ",failures);quit(0 if failures.is_empty() else 1)
