extends SceneTree
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures.append(label)
func _initialize() -> void: run.call_deferred()
func settle() -> void:
	for i in 5: await process_frame
func run() -> void:
	var g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	await settle()
	g.set_process(false)
	g.motor.set_physics_process(false)
	var guide = g.fish_guide
	guide.ingest(g.game.SPECIES)
	# Exercise live XRController3D inputs without stealing the physical WiVRn session.
	var trackers: Array[XRControllerTracker] = []
	var nodes: Array[XRController3D] = []
	for side in ["left", "right"]:
		var tracker := XRControllerTracker.new()
		tracker.name = "test_guide_" + side
		XRServer.add_tracker(tracker)
		trackers.append(tracker)
		var node := XRController3D.new()
		node.tracker = tracker.name
		node.pose = "grip"
		g.origin.add_child(node)
		nodes.append(node)
	g.left = nodes[0]; g.right = nodes[1]; g.xr = true
	var head_tracker := XRPositionalTracker.new()
	head_tracker.name = "head"; head_tracker.type = XRServer.TRACKER_HEAD
	head_tracker.set_pose("default", g.head.transform, Vector3.ZERO, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	XRServer.add_tracker(head_tracker)
	g.head.rotation = Vector3(0, 0.8, 0)
	guide.update_device()
	var hip: Vector3 = guide.dock_grip_position()
	check(absf(hip.y - (g.head.global_position.y - 0.70)) < .01, "Guide handle is at reachable hip height")
	var yaw := Basis(Vector3.UP, 0.8)
	check((hip-g.head.global_position).dot(yaw.x) < -.2, "Guide follows physical body heading, including room-scale turns")
	var grip := Transform3D(Basis.from_euler(Vector3(.3,.7,-.2)),g.origin.to_local(hip))
	trackers[0].set_pose("grip",grip,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	trackers[0].set_input("grip",0.0)
	await settle(); guide.update_device()
	trackers[0].set_input("grip",1.0)
	await settle(); guide.update_device()
	check(guide.held, "Grip near the holstered handle picks up guide")
	check(guide.to_global(guide.GRIP_ANCHOR).distance_to(g.left.global_position)<.001, "Rotated grip keeps authored handle anchored in the fist")
	check(guide.global_basis.y.dot(-g.left.global_basis.z)>.999, "Guide extends toward thumb rather than wrist")
	# Press and release each actual model button, including reverse-side/jump guards.
	for i in 2:
		guide.reset_touch()
		var before: int = guide.selected
		var center: Vector3 = guide.BUTTON_CENTERS[i]
		guide.press_buttons(guide.to_global(center+Vector3(0,0,-.02)))
		check(guide.selected==before,"Back-side button entry does not click")
		guide.press_buttons(guide.to_global(center+Vector3(0,0,.05)))
		guide.press_buttons(guide.to_global(center+Vector3(0,0,.005)))
		var expected := posmod(before+1+(-1 if i==0 else 1),guide.entries.size()+1)-1
		check(guide.selected==expected,"Physical button press changes page")
		for frame in 10: guide.press_buttons(guide.to_global(center))
		check(guide.selected==expected,"Holding button does not repeat page changes")
		guide.press_buttons(guide.to_global(center+Vector3(0,0,.04)))
		guide.press_buttons(guide.to_global(center))
		check(guide.selected==posmod(expected+1+(-1 if i==0 else 1),guide.entries.size()+1)-1,"Button release rearms next press")
	# Real hand-tracker path: converted fingertip positions must activate the same buttons.
	var hand := XRHandTracker.new()
	hand.name = "/user/hand_tracker/right";hand.has_tracking_data = true
	XRServer.add_tracker(hand)
	var tip_joint := XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP
	hand.set_hand_joint_flags(tip_joint, XRHandTracker.HAND_JOINT_FLAG_POSITION_VALID)
	var center: Vector3 = guide.BUTTON_CENTERS[1]
	var selected_before: int = guide.selected
	for depth in [.05, -.04]:
		var world: Vector3 = guide.to_global(center + Vector3(0,0,depth))
		hand.set_hand_joint_transform(tip_joint,Transform3D(Basis.IDENTITY,g.origin.to_local(world)/XRServer.world_scale))
		var touch = guide.touch_position()
		check(touch is Vector3 and touch.distance_to(world)<.0001,"Native right index tip converts into guide world coordinates")
		guide.press_buttons(touch)
	var next_page := posmod(selected_before+2,guide.entries.size()+1)-1
	check(guide.selected==next_page,"Native right fingertip sweep turns one guide page")
	for depth in [.02, .005]:
		var world: Vector3 = guide.to_global(center + Vector3(0,0,depth))
		hand.set_hand_joint_transform(tip_joint,Transform3D(Basis.IDENTITY,g.origin.to_local(world)/XRServer.world_scale))
		guide.press_buttons(guide.touch_position())
	check(guide.selected==posmod(next_page+2,guide.entries.size()+1)-1,"Two-centimetre finger withdrawal rearms another press")
	hand.has_tracking_data=false
	trackers[1].set_pose("grip",Transform3D(Basis.IDENTITY,Vector3(.3,1.1,-.3)),Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	await settle();g._update_avatar(.016)
	g.avatar.solver._process_modification_with_delta(.016);g.avatar._capture_index_tip()
	var expected_tip: Vector3 = g.avatar.skeleton.to_global(g.avatar.skeleton.get_bone_global_pose(g.avatar.index_tip_bone)*g.avatar.index_tip_offset)
	g.avatar.skeleton.reset_bone_poses()
	check(guide.touch_position() is Vector3 and guide.touch_position().distance_to(expected_tip)<.0001,"Controller fallback follows rendered index tip, retaining the final IK pose")
	check(guide.previous_touch==Vector3(INF,INF,INF),"Switching between native and avatar tips resets contact history")
	g.fish_guide.held=true
	g._process(.016)
	check(g.rod_visual.visible and g.rod.visible,"Holding guide keeps tracked rod visible in right hand")
	trackers[1].invalidate_pose("grip");await settle()
	check(guide.touch_position()==null,"Untracked right hand cannot press with a stale avatar fingertip")
	XRServer.remove_tracker(hand)
	trackers[0].invalidate_pose("grip")
	await settle(); guide.update_device()
	check(not guide.held,"Tracking loss docks guide")
	g.xr = false
	# Verify reel model angle, not just scalar retrieval, in both directions.
	var reel = preload("res://scripts/reel_tracker.gd").new()
	var visual = g.crank
	visual.rotation.x = 0
	for direction in [1,-1]:
		reel.engaged=false
		var before: float = visual.rotation.x
		var turns := 0.0
		for i in 101:
			var a: float = direction*i*TAU/100.0
			turns += reel.sample(Vector3(0,cos(a)*.08,sin(a)*.08),true,.01)*.01
			visual.rotation.x += reel.angular_delta
		check(absf(visual.rotation.x-before-direction*TAU)<.001,"Reel visual follows signed circular motion: "+str(direction))
		check(absf(turns-1)<.001,"Either winding direction retrieves one turn")
	# Every page stays inside the menu; footer scrolling reaches the last control.
	g.menu_open=true; g.avatar_menu.show(); g._layout_avatar_menu()
	for id in g.avatar_menu.pages:
		g.avatar_menu.show_page(id)
		await settle()
		var view: ScrollContainer = g.avatar_menu.pages[id].view
		var footer: Control = g.avatar_menu.shell.get_child(g.avatar_menu.shell.get_child_count()-1)
		check(view.get_global_rect().end.y <= footer.get_global_rect().position.y+.5,"Page remains above fixed footer: "+id)
		g.avatar_menu.scroll_page(10000)
		await settle()
		var bar := view.get_v_scroll_bar()
		check(view.scroll_vertical>=bar.max_value-bar.page-1,"Scrolling reaches bottom of page: "+id)
	g.menu_open=false
	var page_before: String = g.avatar_menu.active_page
	g._right_pressed("ax_button")
	check(not g.menu_open and g.avatar_menu.active_page == page_before,"Idle right A cannot open a tutorial popup")
	# FPSloppa gesture tolerates normal high-refresh tracking jitter.
	var detector = preload("res://scripts/tracking/t_pose.gd").new()
	var fired := 0
	for frame in 240:
		var jitter := .003 if frame%2==0 else -.003
		if detector.sample(Transform3D(Basis.IDENTITY,Vector3(0,1.65,0)),Vector3(-.6+jitter,1.4,0),Vector3(.6-jitter,1.4,0),1.0/90,true): fired+=1
	check(fired==1,"Noisy physical T-pose calibrates once")
	var body_tracker := XRBodyTracker.new()
	body_tracker.name = "/user/body_tracker"
	body_tracker.has_tracking_data = true
	for joint in [XRBodyTracker.JOINT_HIPS, XRBodyTracker.JOINT_LEFT_FOOT, XRBodyTracker.JOINT_RIGHT_FOOT]:
		body_tracker.set_joint_flags(joint, XRBodyTracker.JOINT_FLAG_POSITION_VALID | XRBodyTracker.JOINT_FLAG_ORIENTATION_VALID)
		body_tracker.set_joint_transform(joint, Transform3D(Basis.IDENTITY, Vector3(0, .92 if joint == XRBodyTracker.JOINT_HIPS else .08, 0)))
	XRServer.add_tracker(body_tracker)
	g.xr = true; g.menu_open = true; g.head.rotation = Vector3.ZERO
	var manager = g.tracking_manager
	manager.left = nodes[0]; manager.right = nodes[1]
	manager.focused = true; manager.seated = false; manager.tracking.enabled = true
	for i in 2:
		trackers[i].set_pose("grip",Transform3D(Basis.IDENTITY,g.head.position+Vector3(-.6 if i==0 else .6,-.25,0)),Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	await settle()
	for frame in 120: manager.sample(1.0/90.0)
	check(manager.tracking.calibrated and manager.t_pose_detector.latched,"Physical controller T-pose reaches body calibration through the game adapter")
	check(manager.calibration_notice.begins_with("Body calibrated"),"Gesture calibration gives visible completion feedback")
	XRServer.remove_tracker(body_tracker)
	for tracker in trackers: XRServer.remove_tracker(tracker)
	XRServer.remove_tracker(head_tracker)
	g.network.leave();g.queue_free();await settle();await create_timer(.15).timeout
	print("VR_INTERACTIONS_RESULT ",failures)
	quit(0 if failures.is_empty() else 1)
