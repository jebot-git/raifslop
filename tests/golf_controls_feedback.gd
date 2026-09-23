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
func pose(hand:int,at:Vector3):
	trackers[hand].set_pose("grip",Transform3D(Basis.IDENTITY,host.origin.to_local(at)),Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	await settle()
func run():
	host=load("res://scenes/main.tscn").instantiate();root.add_child(host);await create_timer(.5).timeout
	host.set_process(false);host.motor.set_physics_process(false)
	for side in 2:
		var t:=XRControllerTracker.new();t.name="feedback_"+str(side);XRServer.add_tracker(t);trackers.append(t)
		var c:XRController3D=host.left if side==0 else host.right;c.tracker=t.name;c.pose="grip"
		t.set_input("grip",0.0);t.set_input("primary",Vector2.ZERO)
		await pose(side,host.head.global_position+Vector3((side*2-1)*.3,-.4,-.3))
	host.xr=true;host.motor.xr=true;host.tracking_manager.focused=true;host.tracking_manager.calibration_pending=false;host.tracking_manager.startup_settle_frames=0;host.motor.tracking_focused=true
	await host.golf_activity.join_course("spyglass");await settle()
	golf=host.golf_activity.golf;golf.set_process(false);golf.set_physics_process(false);host.motor.set_physics_process(false)
	host.golf_activity.start_play("solo");await settle();host.motor.set_physics_process(false)
	golf.focused=true;golf.set_hand(false);golf.club_reach=1.0
	golf.address_offset=Vector3(INF,INF,INF);golf.aim=.8;golf.address_ball()
	var offset:Vector3=host.head.global_position-golf.ball.position;offset.y=0
	check(offset.length()>=.85 and offset.dot(golf.aim_direction().cross(Vector3.UP))<-.8,"Initial address gives room beside the shot direction")
	var stance:=Vector3(-1.12,0,.48)
	golf.remember_address(golf.ball.position+stance)
	var local_stance:Vector3=golf.address_offset
	var local_facing:Vector3=golf.address_facing
	golf.aim=-.7;golf.ball.position+=Vector3(3,0,-4)
	golf.ball.position.y=golf.world.surface_height(golf.ball.position.x,golf.ball.position.z)+golf.BALL.RADIUS
	golf.address_ball()
	offset=host.head.global_position-golf.ball.position;offset.y=0
	var expected:Vector3=golf.address_basis()*local_stance
	var facing:Vector3=-host.head.global_basis.z;facing.y=0
	check(offset.is_equal_approx(expected) and facing.normalized().dot(golf.address_basis()*local_facing)>.999,"Address rotates saved stance and facing with current ball-to-pin direction")
	var aligned:Transform3D=host.origin.global_transform
	golf.address_ball()
	check(host.origin.global_transform.is_equal_approx(aligned),"Repeated address does not accumulate yaw or room-space offset")
	var original_ball:Vector3=golf.ball.position
	for handed in [false,true]:
		golf.set_hand(handed);golf.address_offset=Vector3(INF,INF,INF);golf.address_facing=Vector3.ZERO;golf.address_ball()
		var stance_local:Vector3=golf.address_basis().inverse()*(host.head.global_position-golf.ball.position);stance_local.y=0
		golf.remember_address(host.head.global_position)
		for approach in [Vector3(30,0,0),Vector3(0,0,30),Vector3(-30,0,0),Vector3(0,0,-30)]:
			golf.ball.position=golf.model.pin()+approach
			golf.address_ball()
			var actual:Vector3=host.head.global_position-golf.ball.position;actual.y=0
			var look:Vector3=-host.head.global_basis.z;look.y=0
			check(actual.distance_to(golf.address_basis()*stance_local)<.001 and look.normalized().dot(-actual.normalized())>.99,"Address follows ball across approach quadrants and handedness: %s / %s"%[handed,approach])
	var tracked_head:Transform3D=host.head.transform
	host.head.rotation.x=-PI*.5
	var downward_head:Transform3D=host.head.transform
	golf.ball.position=golf.model.pin()+Vector3(30,0,0);golf.address_ball()
	var down_facing:Vector3=Vector3.UP.cross(host.head.global_basis.x).normalized()
	check(down_facing.dot(golf.address_basis()*golf.address_facing)>.999 and host.head.transform.is_equal_approx(downward_head),"Looking straight down still aligns teleport yaw without altering tracked head pose")
	host.head.transform=tracked_head
	golf.ball.position=original_ball;golf.set_hand(false);golf.address_ball()
	check(host.motor.single_controller_controls,"Golf enables single-controller locomotion")
	for hand in [1,0]:
		var other:int=1-hand
		trackers[other].invalidate_pose("grip");await settle()
		for frame in 22:golf._update_controller_hand(.05)
		check(golf.left_handed==(hand==0) and golf.pointer_controller()==(host.left if hand==0 else host.right),"Sole controller becomes club and menu hand: "+str(hand))
		golf.equipment.set_stowed(false);golf.course_guide.dock();host.motor.catch_controls=false;host.motor.blocked=false;host.motor.turn_reserved=false
		trackers[hand].set_input("primary",Vector2(0,1));host.motor._physics_process(.016)
		check(Vector2(host.motor.velocity.x,host.motor.velocity.z).length()>.01,"Sole controller stick moves: "+str(hand))
		var before_turn:Basis=host.origin.global_basis
		host.motor.turn_latched=false
		trackers[hand].set_input("primary",Vector2(1,0));host.motor._physics_process(.016)
		check(not host.origin.global_basis.is_equal_approx(before_turn),"Sole controller stick turns: "+str(hand))
		trackers[hand].set_input("primary",Vector2.ZERO)
		golf.begin_club_fit()
		trackers[hand].set_input("primary",Vector2(.8,.6));golf._update_fit_preview(.05)
		check(not golf.fit_session.candidate.is_empty() and golf.fit_session.candidate.reach>golf.club_reach,"Fitting stick adjusts before auto capture: "+str(hand))
		var shaft:Vector3=golf.fit_session.candidate.rotation
		var face:Vector3=golf.fit_session.candidate.head_rotation
		var click:Callable=golf._left_button if hand==0 else golf._right_button
		var release:Callable=golf._left_released if hand==0 else golf._right_released
		click.call("primary_click");golf._update_fit_preview(.05)
		check(golf.fit_session.axis==1 and not golf.godview.active and not golf.club_radial.opened,"Fit stick click selects axis without opening another UI: "+str(hand))
		check(golf.fit_session.candidate.rotation.is_equal_approx(shaft) and not golf.fit_session.candidate.head_rotation.is_equal_approx(face),"Fine adjustment changes face without tilting shaft: "+str(hand))
		trackers[hand].set_input("primary",Vector2.ZERO);click.call("ax_button")
		check(not golf.fitting_club and golf.club_fitted[hand],"Sole controller accepts the preview: "+str(hand))
		var fit_origin:Transform3D=host.origin.global_transform
		click.call("ax_button")
		check(host.origin.global_transform.is_equal_approx(fit_origin),"Held/repeated fit confirmation cannot teleport to the ball: "+str(hand))
		release.call("ax_button")
		# Auto-fit keeps the head rigidly attached even with a leaning shaft.
		await pose(hand,golf.ball.position+Vector3(-.5 if hand==1 else .5,.85,0))
		# The host process is deliberately disabled in this synthetic fixture.
		host.avatar.right_grip=host.controller_pose(1);host.avatar.left_grip=host.controller_pose(0)
		host.avatar.right_grip_frame=Engine.get_process_frames()
		var correction:Vector3=golf.head_correction(hand)
		golf.begin_club_fit();click.call("trigger_click")
		for frame in 12:golf._update_fit_preview(.05)
		check(golf.fit_session.candidate.has("capture_grip"),"One trigger automatically captures the steady address: "+str(hand)+" · "+golf.status_text)
		var clearance:float=preload("res://addons/golfminus/scripts/golf/club_fit.gd").clearance(golf.physical_head.global_transform,golf.head_shape,golf.world.surface_height)
		var relative:Basis=golf.club.global_basis.orthonormalized().inverse()*golf.physical_head.global_basis
		check(relative.is_equal_approx(Basis.from_euler(correction*PI/180)*Basis(Vector3.RIGHT,golf.head_shape.loft)) and absf(clearance-.004)<.001,"Auto-fit keeps head fixed to intended shaft axis and clears turf: "+str(hand))
		click.call("ax_button");check(not golf.fitting_club,"Automatic fit remains acceptable from sole controller: "+str(hand)+" · "+golf.status_text);release.call("ax_button")
		var guide=golf.course_guide
		guide.dock();guide.update()
		var hip:Transform3D=golf.equipment.hip_pose(1.0 if golf.left_handed else -1.0)
		var grip:Transform3D=Transform3D(Basis.IDENTITY,hip.origin)*golf.calibration.pose(hand).affine_inverse()
		await pose(hand,grip.origin)
		trackers[hand].set_input("grip",0.0);guide.update()
		trackers[hand].set_input("grip",1.0);guide.update()
		check(guide.held and guide.held_hand==hand,"Tablet can be grabbed by sole hand: "+str(hand))
		click.call("trigger_click");check(guide.photo_camera.active,"Sole tablet hand opens camera: "+str(hand))
		click.call("by_button");check(not guide.photo_camera.active and guide.held,"Sole tablet hand closes camera without losing tablet: "+str(hand))
		trackers[hand].set_input("grip",0.0);guide.update();check(not guide.held,"Releasing the holding grip docks tablet: "+str(hand))
		await pose(other,host.head.global_position+Vector3((other*2-1)*.3,-.4,-.3))
	for frame in 22:golf._update_controller_hand(.05)
	check(golf.left_handed==golf.preferred_left_handed,"Returning controller restores the saved handedness preference")
	# A direct VR-safe handedness toggle moves the implement and persists choice.
	golf.equipment.set_stowed(false)
	for value in [true,false]:
		golf.hud.hand_choice.button_pressed=value
		check(golf.left_handed==value and golf.club.get_parent()==(host.left if value else host.right),"Handedness control moves club to selected hand")
		var cfg:=ConfigFile.new();cfg.load("user://golf_controls.cfg")
		check(cfg.get_value("golf","left_handed")==value,"Handedness control saves preference immediately")
		check(golf.pointer_controller()==(host.left if value else host.right),"Menu pointer follows selected hand when both controllers are tracked")
		if value:
			golf._left_button("primary_click");golf._left_released("primary_click")
			check(golf.club_radial.opened and not golf.godview.active,"Left-handed club hand opens club bag")
			golf._left_button("primary_click");golf._left_released("primary_click")
	golf.equipment.set_stowed(false);golf.course_guide.dock();host.motor.catch_controls=false
	# Latched radial: release does nothing; centre commits the highlighted club.
	trackers[1].set_input("primary",Vector2.ZERO)
	golf._right_button("primary_click");golf._right_released("primary_click");golf.club_radial.update()
	check(golf.club_radial.opened,"Club radial stays open after releasing the opening click")
	golf._right_button("primary_click");check(not golf.club_radial.opened,"Second click cancels club radial")
	golf._right_released("primary_click");golf._right_button("primary_click");golf._right_released("primary_click")
	trackers[1].set_input("primary",Vector2(1,0));golf.club_radial.update()
	check(golf.club_radial.opened and golf.club_radial.choice==2,"Radial deflection highlights without closing")
	trackers[1].set_input("primary",Vector2.ZERO);golf.club_radial.update()
	check(not golf.club_radial.opened and golf.club_index==2,"Returning to centre equips selected club")
	# Grip and trigger independently enable collision and block both sticks.
	for input in ["grip","trigger","trigger_click"]:
		trackers[1].set_input(input,true if input.ends_with("click") else 1.0)
		check(golf.club_collision_enabled(),"Club collision accepts "+input)
		golf.last_origin_basis=host.origin.global_basis;golf.last_swing_us=Time.get_ticks_usec()-14000;host.motor.last_motion=Vector3.ZERO
		golf._swing()
		check(golf.swing.last_sample.get("active",false),"Collision sampler receives active "+input)
		trackers[0].set_input("primary",Vector2(.8,.8));trackers[1].set_input("primary",Vector2(.8,.8))
		host.motor.turn_reserved=false;host.motor.turn_latched=false;host.motor.velocity=Vector3(1,0,1)
		var before_lock:Basis=host.origin.global_basis
		host.motor._physics_process(.016)
		check(Vector2(host.motor.velocity.x,host.motor.velocity.z).length()<.001 and host.origin.global_basis.is_equal_approx(before_lock),"Armed club prevents walking and turning with "+input)
		trackers[1].set_input(input,false if input.ends_with("click") else 0.0);host.motor._physics_process(.016)
		check(host.motor.stick_release_pending,"Release cannot apply an accidentally held stick")
		for t in trackers:t.set_input("primary",Vector2.ZERO)
		host.motor._physics_process(.016);check(not host.motor.stick_release_pending,"Neutral sticks restore locomotion after releasing club")
	# Resting/absent offhand and nearby manual grip all share a visual target.
	for handed in [false,true]:
		golf.set_hand(handed)
		var off:int=1 if handed else 0
		await pose(off,host.head.global_position+Vector3(-.7,-.8,.3))
		golf.support_hand.reset();trackers[off].set_input("trigger_touch",true)
		for frame in 12:golf.support_hand.update(.1)
		check(not golf.support_hand.engaged,"A touched controller stays tracked even when held still")
		trackers[off].set_input("trigger_touch",false)
		for frame in 12:golf.support_hand.update(.1)
		check(golf.support_hand.engaged and golf.support_hand.automatic,"Laid-down tracked controller snaps support hand: "+str(off))
		host.golf_activity.update_player(.016)
		check((host.avatar.right_target if handed else host.avatar.left_target)==golf.support_hand,"Live avatar follows support target instead of laid-down controller")
		var packet:Dictionary=preload("res://scripts/network/state.gd").capture(host,1)
		var side:String="right" if handed else "left"
		check(packet[side].is_equal_approx(golf.support_hand.global_transform) and preload("res://scripts/network/state.gd").valid(packet),"Remote golfer receives the same valid support grip")
		var target_before:Transform3D=golf.support_hand.global_transform
		var raw_before:Transform3D=(host.left if off==0 else host.right).global_transform
		check(raw_before.origin.distance_to(target_before.origin)>.3,"Support grip does not move the raw controller")
		await pose(off,raw_before.origin+Vector3(.1,0,0));golf.support_hand.update(.016)
		check(not golf.support_hand.engaged,"Picking up controller restores tracked offhand")
		trackers[off].invalidate_pose("grip");await settle();golf.support_hand.update(.016)
		check(golf.support_hand.engaged,"Missing controller also uses support grip")
		await pose(off,golf.support_hand.global_position)
		trackers[off].set_input("trigger",1.0);golf.support_hand.update(.016)
		check(golf.support_hand.engaged and not golf.support_hand.automatic,"Trigger grabs nearby club grip like fishing reel")
		trackers[off].set_input("trigger",0.0);golf.support_hand.update(.016)
		check(not golf.support_hand.engaged,"Releasing manual grip frees offhand")
	golf.set_hand(false);golf.begin_club_fit()
	trackers[0].set_input("primary",Vector2(.8,0));golf._update_fit_preview(.05)
	check(not golf.fit_session.candidate.is_empty(),"Other hand stick also adjusts club fit")
	golf.cancel_club_fit();trackers[0].set_input("primary",Vector2.ZERO)
	golf._update_club_pose();var shaft_pose:Transform3D=golf.club.global_transform;var head_position:Vector3=golf.physical_head.global_position
	var face_before:Vector3=-golf.physical_head.global_basis.z
	var face_up:Vector3=(golf.physical_head.global_basis*Basis(Vector3.RIGHT,-golf.head_shape.loft)).y
	golf.flip_club_face();golf._update_club_pose()
	check(golf.club.global_transform.is_equal_approx(shaft_pose) and golf.physical_head.global_position.is_equal_approx(head_position),"Reversing face preserves shaft and head position")
	var face_after:Vector3=-golf.physical_head.global_basis.z
	var before_tangent:Vector3=face_before-face_up*face_before.dot(face_up)
	var after_tangent:Vector3=face_after-face_up*face_after.dot(face_up)
	check(after_tangent.normalized().dot(before_tangent.normalized())<-.999 and absf(face_after.dot(face_up)-face_before.dot(face_up))<.001,"Reverse face turns 180 degrees about the club axis while preserving loft")
	host.golf_activity.leave();check(not host.motor.single_controller_controls,"Leaving golf restores fishing controls")
	for t in trackers:XRServer.remove_tracker(t)
	host.ambience.stop();host.queue_free();await process_frame;await create_timer(.3).timeout
	print("GOLF_CONTROLS_FEEDBACK_RESULT ",failures);quit(0 if failures.is_empty() else 1)
