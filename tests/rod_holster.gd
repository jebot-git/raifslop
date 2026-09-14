extends SceneTree
var failures: Array=[]
func _initialize(): run.call_deferred()
func check(ok: bool, label: String):
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures.append(label)
func run():
	var g=load("res://scenes/main.tscn").instantiate();root.add_child(g)
	await create_timer(.4).timeout
	g.set_process(false);g.motor.set_physics_process(false)
	var h=g.rod_holster
	for tier in 4:
		g.rod_visual.equip(tier)
		var folded: AABB=preload("res://scripts/fish_size.gd").bounds(g.rod_visual.folded_model)
		check(folded.size.z<.73 and folded.size.z>.6,"Rod folds into compact sections: "+str(tier))
	var tracker:=XRControllerTracker.new();tracker.name="holster_test_right";XRServer.add_tracker(tracker)
	var right:=XRController3D.new();right.tracker=tracker.name;right.pose="grip";g.origin.add_child(right);g.right=right;g.xr=true;g.tracking_manager.focused=true
	g.head.rotation.y=.7;h.update_holster()
	var yaw=Basis(Vector3.UP,.7)
	check((h.belt_pose.origin-g.head.global_position).dot(yaw.x)>.25,"Holster sits on right hip after physical turn")
	check(absf(h.belt_pose.origin.y-(g.head.global_position.y-.7))<.01,"Holster grip remains at hip height")
	var grip:=Transform3D(Basis.IDENTITY,g.origin.to_local(h.belt_pose.origin))
	tracker.set_pose("grip",grip,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	tracker.set_input("grip",0.0);await process_frame;h.update_holster()
	tracker.set_input("grip",1.0);await process_frame;h.update_holster()
	check(h.stowed and g.rod.get_parent()==g and g.rod_visual.folded,"Right grip near hip folds and stashes rod")
	for i in 10:h.update_holster()
	check(h.stowed,"Holding grip cannot immediately retrieve the rod")
	var rod_pose: Transform3D=g.rod.global_transform
	grip.origin+=Vector3(.5,.2,-.3);tracker.set_pose("grip",grip,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	await process_frame;h.update_holster()
	check(g.rod.global_transform.is_equal_approx(rod_pose),"Stashed rod stays at hip when right hand moves away")
	g._right_pressed("trigger_click");g._cast(12)
	check(not g.casting and g.game.state==g.Session.State.READY,"Free-hand trigger cannot cast the stashed rod")
	var state=preload("res://scripts/network/state.gd").capture(g,1)
	check(preload("res://scripts/network/state.gd").valid(state) and h.remote_stowed(state),"Existing network poses convey folded rod without changing protocol")
	tracker.invalidate_pose("grip");await process_frame;h.update_holster()
	grip.origin=g.origin.to_local(h.belt_pose.origin);tracker.set_pose("grip",grip,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	await process_frame;h.update_holster()
	check(h.stowed,"Tracking recovery with grip held cannot grab accidentally")
	tracker.set_input("grip",0.0);await process_frame;h.update_holster()
	tracker.set_input("grip",1.0);await process_frame;h.update_holster()
	check(not h.stowed and g.rod.get_parent()==right and g.rod.transform.is_equal_approx(h.HELD_POSE) and not g.rod_visual.folded,"New grip at hip retrieves and unfolds rod at original hand mount")
	state=preload("res://scripts/network/state.gd").capture(g,2)
	check(not h.remote_stowed(state),"Remote held rod is not folded")
	check(not g.reel_tracker.engaged and not g.tracking_was_valid and g.peak_speed==0,"Retrieval resets reel and casting motion samples")
	for active in [g.Session.State.CASTING,g.Session.State.WAITING,g.Session.State.BITE,g.Session.State.FIGHT,g.Session.State.LANDED]:
		g.game.state=active
		check(not h.set_stowed(true) and not h.stowed,"Active cast/catch cannot be discarded by stashing: "+str(active))
	g.game.reset();g.casting=true
	check(not h.set_stowed(true),"Held casting gesture blocks stashing")
	g.casting=false;h.set_stowed(true)
	g.motor.position+=Vector3(1,0,2);h.update_holster()
	check(g.rod.global_transform.is_equal_approx(h.belt_pose),"Holstered rod follows locomotion")
	g.xr=false;XRServer.remove_tracker(tracker)
	g.queue_free();await process_frame;await create_timer(.3).timeout
	print("ROD_HOLSTER_RESULT ",failures);quit(0 if failures.is_empty() else 1)
