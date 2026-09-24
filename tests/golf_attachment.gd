extends SceneTree
var failures:Array=[]
var trackers:Array[XRControllerTracker]=[]
var host
var golf
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func settle():
	for i in 3:await process_frame
func pose(hand:int,at:Vector3,basis:=Basis.IDENTITY):
	trackers[hand].set_pose("grip",Transform3D(basis,host.origin.to_local(at)),Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	await settle()
func run():
	host=load("res://scenes/main.tscn").instantiate();root.add_child(host);await create_timer(.5).timeout
	host.set_process(false);host.motor.set_physics_process(false)
	# This fixture drives synthetic trackers; desktop typing must not start casts.
	host.set_process_input(false);host.set_process_unhandled_input(false)
	for side in 2:
		var t:=XRControllerTracker.new();t.name="feedback_"+str(side);XRServer.add_tracker(t);trackers.append(t)
		var c:XRController3D=host.left if side==0 else host.right;c.tracker=t.name;c.pose="grip"
		t.set_input("grip",0.0);t.set_input("primary",Vector2.ZERO)
		await pose(side,host.head.global_position+Vector3((side*2-1)*.3,-.4,-.3))
	host.avatar_panel=MeshInstance3D.new();host.add_child(host.avatar_panel)
	host.menu_pointer=MeshInstance3D.new();host.add_child(host.menu_pointer)
	host.xr=true;host.motor.xr=true;host.tracking_manager.focused=true;host.tracking_manager.calibration_pending=false;host.tracking_manager.startup_settle_frames=0;host.motor.tracking_focused=true
	await host.golf_activity.join_course("spyglass");await settle()
	if not is_instance_valid(host.golf_activity.golf):
		check(false,"Preparation failed: "+host.golf_activity.status.text)
		host.ambience.stop();host.queue_free();await process_frame;quit(1);return
	golf=host.golf_activity.golf;golf.set_process_input(false);golf.set_process(false);golf.set_physics_process(false);host.motor.set_physics_process(false)
	host.golf_activity.start_play("solo");await settle();host.motor.set_physics_process(false)
	golf.focused=true;golf.set_hand(false);golf.club_reach=1.0
	golf.reset_club_attachment(0);golf.reset_club_attachment(1)
	# Exercise the actual hosted visual/contact pose before fitting, not only
	# the profile helper. A natural OpenXR grip must not require a sideways hand.
	for hand in 2:
		golf.set_hand(hand==0);golf.set_club(0);golf.equipment.set_stowed(false)
		var lean:=deg_to_rad(32.0);var side:float=1 if hand==0 else -1
		var x:=Vector3.FORWARD if hand==0 else Vector3.BACK
		var z:=Vector3(-side*sin(lean),-cos(lean),0)
		var grip:=Transform3D(Basis(x,z.cross(x),z),Vector3(side*.5,1,.1))
		trackers[hand].set_pose("grip",grip,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
		await settle();golf._update_club_pose()
		var expected_head:Basis=host.origin.global_basis.orthonormalized()*Basis(Vector3.RIGHT,deg_to_rad(11.0))
		check(golf.physical_head.global_basis.is_equal_approx(expected_head),"Hosted unfitted head faces shot with authored loft for hand %d"%hand)
		var relative:Basis=golf.club.global_basis.orthonormalized().inverse()*expected_head
		golf.equipment.set_stowed(true);golf.set_club(0)
		check(golf.physical_head.transform.basis.orthonormalized().is_equal_approx(relative),"Changing stowed club preserves head/handle alignment for hand %d"%hand)
		golf.equipment.set_stowed(false)
		golf.club_rotations[hand]+=Vector3(5,12,-8);golf._update_club_pose()
		check(golf.physical_head.global_basis.is_equal_approx(expected_head),"Hosted handle edits leave default head orientation independent for hand %d"%hand)
		golf.reset_club_attachment(hand)
	for hand in 2:await pose(hand,host.head.global_position+Vector3((hand*2-1)*.3,-.4,-.3))
	golf.set_hand(false)

	var initial_tier:int=host.game.tackle.equipped
	var initial_club:int=golf.club_index
	var peer=preload("res://scripts/network/remote_angler.gd").new();peer.session=host.network;root.add_child(peer);peer.set_process(false)
	for tier in 4:
		host.game.tackle.equipped=tier
		for index in 8:
			golf.set_club(index)
			check(golf.club.get_meta("tackle_style",-1)==tier,"New club inherits equipped tackle style")
		var snapshot=preload("res://scripts/network/state.gd").capture(host,tier)
		peer.receive_state(snapshot);peer._process(1.0)
		check(is_instance_valid(peer.golf_club) and peer.golf_club.get_meta("tackle_style",-1)==tier,"Existing multiplayer snapshot updates remote style")
	var same_club:Node3D=golf.club;var same_head:Transform3D=golf.physical_head.transform
	golf.last_swing_us=12345;golf.fitting_club=true
	host.game.tackle.equipped=0;golf.update_club_style()
	check(golf.club==same_club and golf.physical_head.transform==same_head and golf.last_swing_us==12345 and golf.fitting_club,"Tier-only update preserves club, fit and swing tracking")
	golf.fitting_club=false;golf.equipment.set_stowed(true);host.game.tackle.equipped=2;golf.update_club_style()
	check(golf.equipment.stowed and golf.club.get_meta("tackle_style")==2,"Stowed club updates cosmetically")
	golf.equipment.set_stowed(false);golf.set_hand(true)
	check(golf.club.get_meta("tackle_style")==2,"Left-handed replacement keeps style")
	host.game.tackle.equipped=initial_tier;golf.set_hand(false);golf.set_club(initial_club);peer.queue_free();await settle()

	var ui=golf.hud.attachment_controls
	check(host.avatar_menu.pages.controls.page.is_ancestor_of(ui),"Attachment calibration belongs to Golf Controls")
	var shared:Transform3D=host.controller_calibration.pose(1)
	ui.hand_choice.item_selected.emit(1)
	ui.fields.offset0.value=12.5;ui.fields.offset1.value=-8;ui.fields.offset2.value=30
	ui.fields.rotation0.value=25;ui.fields.rotation1.value=-40;ui.fields.rotation2.value=90
	ui.fields.head0.value=5
	ui.mounted.button_pressed=true
	check(golf.club_offsets[1].is_equal_approx(Vector3(.125,-.08,.3)),"Position controls convert centimetres to metres")
	check(golf.club_rotations[1]==Vector3(25,-40,90) and golf.club_fitted[1],"Shaft and clubface controls apply independently")
	check(golf.club_offsets[0]==Vector3.ZERO and golf.club_rotations[0]==golf.FIT_PROFILE.default_shaft_rotation(0) and not golf.club_controller_mount[0],"Right attachment edits leave left hand unchanged")
	check(host.controller_calibration.pose(1).is_equal_approx(shared),"Golf calibration leaves shared fishing/controller calibration untouched")
	golf.equipment.set_stowed(false);golf._update_club_pose()
	var expected:Transform3D=host.right.global_transform*shared*Transform3D(Basis.IDENTITY,golf.club_offsets[1])
	check(golf.club.global_position.is_equal_approx(expected.origin),"Mounted grip follows calibrated controller and local offset")
	var shaft_basis:Basis=expected.basis*Basis.from_euler(golf.club_rotations[1]*PI/180)
	check(golf.club.global_basis.orthonormalized().is_equal_approx(shaft_basis.orthonormalized()),"Mounted shaft applies local angular calibration")
	golf.support_hand.update(.05)
	check(golf.support_hand.global_position.distance_to(expected.origin-shaft_basis.y.normalized()*.105)<.001,"Support hand follows the calibrated attachment grip")
	golf.begin_club_fit();golf._update_fit_preview(.05)
	check(not golf.fit_session.samples.is_empty() and golf.fit_session.samples[0].origin.distance_to(expected.origin)<.001,"Address fitting samples the offset grip position")
	golf.cancel_club_fit()
	check(golf.club_offsets[1]==Vector3(.125,-.08,.3) and golf.club_controller_mount[1],"Cancelling address fit preserves attachment settings")
	host.avatar.right_grip=Transform3D(Basis.IDENTITY,Vector3(20,30,40));host.avatar.right_grip_frame=Engine.get_process_frames()
	host.golf_activity.attach_club_to_hand()
	check(golf.club.global_position.is_equal_approx(expected.origin),"Avatar palm cannot override controller-mounted attachment")
	ui.mounted.button_pressed=false
	host.golf_activity.attach_club_to_hand()
	check(golf.club.global_position.is_equal_approx(host.avatar.right_grip.origin+host.right.global_basis*shared.basis*golf.club_offsets[1]),"Avatar-hand mode retains configured positional offset")
	trackers[1].set_input("grip",1.0)
	golf.last_origin_basis=host.origin.global_basis;golf.last_swing_us=Time.get_ticks_usec()-14000;host.motor.last_motion=Vector3.ZERO
	golf._swing()
	var contact_pose:Transform3D=golf.physical_head.global_transform
	check(golf.swing.last_sample.head.is_equal_approx(contact_pose.origin),"Collision samples the rendered palm-adjusted clubhead")
	host.avatar.right_grip.origin+=Vector3(.1,0,0);host.avatar.right_grip_frame=Engine.get_process_frames()
	host.golf_activity.attach_club_to_hand()
	check(golf.physical_head.global_transform.is_equal_approx(contact_pose),"Late avatar update cannot separate the visible head from its collision sweep")
	trackers[1].set_input("grip",0.0)
	ui.mounted.button_pressed=true;golf._update_club_pose()
	# Capture at a palm displaced from the controller, then accept without
	# moving: changing attachment origin here used to lift the accepted head.
	golf.reset_club_attachment(1);golf.set_club(0)
	await pose(1,golf.ball.position+Vector3(-.5,.85,.1),golf.FIT_PROFILE.grip_basis(1).inverse())
	host.avatar.right_grip=host.controller_pose(1);host.avatar.right_grip.origin+=Vector3(.025,-.035,.02)
	host.avatar.right_grip_frame=Engine.get_process_frames()
	golf.begin_club_fit();golf.finish_club_fit()
	for frame in 12:golf._update_fit_preview(.05)
	check(golf.fit_session.candidate.has("capture_grip"),"Palm-mounted fit captures the actual attachment")
	var fitted_pose:Transform3D=golf.physical_head.global_transform
	golf.accept_club_fit();golf._update_club_pose()
	check(not golf.fitting_club and golf.physical_head.global_transform.is_equal_approx(fitted_pose),"Accepting a palm-mounted fit preserves head height and orientation")
	# Restore the controls fixture values for persistence/preview checks.
	golf.club_offsets[1]=Vector3(.125,-.08,.3);golf.club_rotations[1]=Vector3(25,-40,90)
	golf.club_head_rotations[1]=Vector3(5,0,0);golf.club_fitted[1]=true
	golf.club_controller_mount[1]=true;golf._update_club_pose();ui.refresh()
	host.golf_activity.open_settings("controls");await settle();ui._process(.016)
	if DisplayServer.get_name()!="headless":
		host.avatar_menu.pages.controls.view.scroll_vertical=int(ui.position.y)
		await settle();await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://test-results/golf-attachment-controls.png")
	check(ui.preview.visible and ui.preview_head.global_position.distance_to(golf.physical_head.global_position)<.001,"VR preview matches actual calibrated club head")
	check(ui.preview.find_children("*","CollisionObject3D",true,false).is_empty(),"Attachment preview has no collision objects")
	ui.hand_choice.item_selected.emit(0);ui.fields.offset2.value=-20
	check(is_equal_approx(golf.club_offsets[0].z,-.2) and ui.mounted.button_pressed==false,"Editor selects each hand without changing swing handedness")
	golf.hud.length_slider.value=1.12
	var cfg:=ConfigFile.new();cfg.load("user://golf_controls.cfg")
	check(cfg.get_value("golf","club_offset_1")==golf.club_offsets[1] and cfg.get_value("golf","club_controller_mount_1") and is_equal_approx(cfg.get_value("golf","reach"),1.12),"Position, mount and reach changes save immediately")
	golf.set_club_attachment(1,"offset",0,NAN)
	check(golf.club_offsets[1].x==.125,"Non-finite attachment edits are rejected")
	var saved_right:Vector3=golf.club_offsets[1]
	golf.reset_club_attachment(0)
	check(golf.club_offsets[0]==Vector3.ZERO and not golf.club_fitted[0] and golf.club_offsets[1]==saved_right,"Reset restores only the selected hand")
	host.golf_activity.close_settings();host.golf_activity.leave();await settle()
	await host.golf_activity.join_course("spyglass");golf=host.golf_activity.golf;golf.set_process(false);golf.set_physics_process(false);await settle()
	check(golf.club_offsets[1]==saved_right and golf.club_controller_mount[1] and golf.club_rotations[1]==Vector3(25,-40,90),"Attachment settings survive leaving and reopening golf")
	check(golf.club_fitted[1] and golf.club_head_rotations[1].x==5,"Explicit clubface correction survives reload")
	host.golf_activity.leave();host.ambience.stop()
	for tracker in trackers:XRServer.remove_tracker(tracker)
	host.queue_free();await process_frame;await create_timer(.3).timeout
	print("GOLF_ATTACHMENT_RESULT ",failures);quit(0 if failures.is_empty() else 1)
