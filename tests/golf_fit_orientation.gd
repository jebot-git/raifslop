extends SceneTree
var failures:Array=[]
var trackers:Array[XRControllerTracker]=[]
var host
var golf
var saved:Array[Dictionary]=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func settle():
	for frame in 3:await process_frame
func pose(hand:int,basis:Basis):
	var at:Vector3=golf.ball.position+Vector3(.5 if hand==0 else -.5,.85,.1)
	trackers[hand].set_pose("grip",Transform3D(host.origin.global_basis.inverse()*basis,host.origin.to_local(at)),Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	await settle()
func activate():
	golf=host.golf_activity.golf;golf.set_process(false);golf.set_physics_process(false)
	host.golf_activity.start_play("solo");await settle()
	host.motor.set_physics_process(false);golf.focused=true
func run():
	host=load("res://scenes/main.tscn").instantiate();root.add_child(host);await create_timer(.5).timeout
	host.set_process(false);host.motor.set_physics_process(false)
	host.xr=true;host.motor.xr=true;host.tracking_manager.focused=true
	for hand in 2:
		var tracker:=XRControllerTracker.new();tracker.name="fit_orientation_"+str(hand);XRServer.add_tracker(tracker);trackers.append(tracker)
		var controller:XRController3D=host.left if hand==0 else host.right
		controller.tracker=tracker.name;controller.pose="grip"
	await host.golf_activity.join_course("spyglass");await activate()
	for hand in 2:
		golf.set_hand(hand==0);golf.reset_club_attachment(hand);golf.club_controller_mount[hand]=true
		var basis:Basis=Basis.from_euler(Vector3(.35,.7,1.4))*golf.FIT_PROFILE.grip_basis(hand).inverse()
		await pose(hand,basis);golf.equipment.set_stowed(false);golf._update_club_pose()
		var shaft:Basis=golf.club.global_basis.orthonormalized()
		var face:Basis=golf.physical_head.global_basis
		golf.begin_club_fit();golf.finish_club_fit()
		for frame in 12:golf._update_fit_preview(.05)
		check(golf.fit_session.candidate.has("capture_grip"),"Tilted controller pose captures for hand "+str(hand))
		if golf.fit_session.candidate.has("capture_grip"):
			check(golf.fit_session.candidate.controller_grip.basis.is_equal_approx(basis*golf.calibration.pose(hand).basis),"Capture retains full tracked controller rotation")
		shaft=golf.club.global_basis.orthonormalized();face=golf.physical_head.global_basis
		var target:Vector3=golf.fit_session.candidate.target
		check(golf.physical_head.global_position.distance_to(target)<.001,"Fitted shaft places head at address target behind ball")
		var forward:Vector3=golf.aim_direction();forward.y=0;forward=forward.normalized()
		check((golf.physical_head.global_position-golf.ball.position).dot(forward)<-.074,"Head centre stays behind ball")
		for vertex in golf.head_shape.surface_points:
			if ((golf.physical_head.global_transform*vertex)-golf.ball.position).dot(forward)>-golf.head_shape.BALL_RADIUS-.009:
				check(false,"Entire head clears ball at address");break
		check(golf.club.global_position.distance_to(golf.club_world_grip_pose().origin)<.001,"Handle remains attached to the actual hand")
		var normal:Vector3=preload("res://addons/golfminus/scripts/golf/club_fit.gd").ground_normal(golf.ball.position,golf.world.surface_height)
		var expected_loft:float=sin(golf.head_shape.loft)
		check(absf((-face.z).dot(normal)-expected_loft)<.001,"Chosen controller pose gives authored head loft at address")
		golf.accept_club_fit();golf._update_club_pose()
		check(not golf.fitting_club and golf.club.global_basis.orthonormalized().is_equal_approx(shaft) and golf.physical_head.global_basis.is_equal_approx(face),"Acceptance cannot rotate handle or face")
		var accepted_rotation:Vector3=golf.club_pose_rotations[hand]
		golf.begin_club_fit();golf.finish_club_fit()
		for frame in 12:golf._update_fit_preview(.05)
		check(Basis.from_euler(golf.fit_session.candidate.pose_rotation*PI/180).is_equal_approx(Basis.from_euler(accepted_rotation*PI/180)),"Recapturing the same pose does not accumulate rotation")
		golf.cancel_club_fit();golf._update_club_pose()
		check(golf.club_pose_rotations[hand]==accepted_rotation and golf.physical_head.global_basis.is_equal_approx(face),"Cancelling calibration restores accepted grip")
		saved.append({"controller":basis,"shaft":shaft,"face":face})
		for axis in [Vector3.RIGHT,Vector3.UP,Vector3.BACK]:
			var delta:=Basis(axis,.45)
			await pose(hand,delta*basis);golf._update_club_pose()
			check(golf.club.global_basis.orthonormalized().is_equal_approx(delta*shaft) and golf.physical_head.global_basis.is_equal_approx(delta*face),"Controller rotation moves complete club about axis "+str(axis))
		await pose(hand,basis);golf._update_club_pose()
		check(golf.physical_head.global_basis.is_equal_approx(face),"Returning to captured grip returns initial face")
	host.golf_activity.leave();await settle()
	await host.golf_activity.join_course("spyglass");await activate()
	for hand in 2:
		golf.set_hand(hand==0);golf.equipment.set_stowed(false)
		await pose(hand,saved[hand].controller);golf._update_club_pose()
		check(golf.club.global_basis.orthonormalized().is_equal_approx(saved[hand].shaft) and golf.physical_head.global_basis.is_equal_approx(saved[hand].face),"Saved fit restores same controller-relative orientation after rejoining: "+str(hand))
	host.golf_activity.leave();host.ambience.stop()
	for tracker in trackers:XRServer.remove_tracker(tracker)
	host.queue_free();await process_frame
	print("GOLF_FIT_ORIENTATION_RESULT ",failures);quit(0 if failures.is_empty() else 1)
