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
func remote_club_pickup(hand:int,label:String):
	golf.course_guide.dock();golf.equipment.set_stowed(true)
	await pose(hand,host.head.global_position+Vector3((hand*2-1)*.45,-.35,-.65))
	trackers[hand].set_input("grip",0.0);trackers[hand].set_input("grip_click",false)
	golf.equipment.update();golf.course_guide.update()
	trackers[hand].set_input("grip_click",true);golf.equipment.update();golf.course_guide.update()
	check(not golf.equipment.stowed and not golf.course_guide.held,"Empty-hand grip equips club away from hip: "+label)
	golf.equipment.update()
	check(not golf.equipment.stowed,"Holding equip grip cannot stow club: "+label)
	trackers[hand].set_input("grip_click",false);golf.equipment.update();golf.course_guide.update()
	trackers[hand].set_input("grip",1.0);golf.equipment.update();golf.course_guide.update()
	check(not golf.equipment.stowed,"Grip away from hip keeps held club equipped: "+label)
	trackers[hand].set_input("grip",0.0);golf.equipment.update();golf.course_guide.update()
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
	check(is_equal_approx(golf.aim,.8),"Address preserves player-selected aim")
	golf._reset_lane_aim();var lane_aim:float=golf.aim
	golf.address_ball()
	check(is_equal_approx(golf.aim,lane_aim) and golf.model.guide_clear(golf.ball.position,golf.model.guide_target(golf.ball.position)),"Address preserves routed lane aim through integrated rig")
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
	check(offset.is_equal_approx(expected) and facing.normalized().dot(golf.address_basis()*local_facing)>.999 and is_equal_approx(golf.aim,-.7),"Address rotates saved stance and facing with selected shot direction")
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
		await remote_club_pickup(hand,"sole controller "+str(hand))
		golf.begin_club_fit()
		trackers[hand].set_input("primary",Vector2(.8,.6));golf._update_fit_preview(.05)
		check(not golf.fit_session.candidate.is_empty() and golf.fit_session.candidate.reach>golf.club_reach,"Fitting stick adjusts before auto capture: "+str(hand))
		var shaft:Vector3=golf.fit_session.candidate.rotation
		var face:Vector3=golf.fit_session.candidate.head_rotation
		var click:Callable=golf._left_button if hand==0 else golf._right_button
		var release:Callable=golf._left_released if hand==0 else golf._right_released
		click.call("primary_click");golf._update_fit_preview(.05)
		check(not golf.godview.active and not golf.club_radial.opened,"Fit stick click is consumed without opening another UI: "+str(hand))
		check(golf.fit_session.candidate.rotation.is_equal_approx(shaft) and golf.fit_session.candidate.head_rotation.is_equal_approx(face),"Fine adjustment preserves handle and head angles: "+str(hand))
		shaft=golf.fit_session.candidate.rotation
		click.call("grip_click");golf._update_fit_preview(.05)
		check(golf.fit_session.candidate.head_rotation.is_equal_approx(face) and golf.fit_session.candidate.rotation.is_equal_approx(shaft),"Grip cannot enable angle changes during length fitting: "+str(hand))
		click.call("grip_click")
		trackers[hand].set_input("primary",Vector2.ZERO);click.call("ax_button")
		check(not golf.fitting_club and golf.club_rotations[hand].is_equal_approx(shaft),"Sole controller accepts the preview: "+str(hand))
		var fit_origin:Transform3D=host.origin.global_transform
		click.call("ax_button")
		check(host.origin.global_transform.is_equal_approx(fit_origin),"Held/repeated fit confirmation cannot teleport to the ball: "+str(hand))
		release.call("ax_button")
		# Auto-fit keeps the head rigidly attached even with a leaning shaft.
		await pose(hand,golf.ball.position+Vector3(-.5 if hand==1 else .5,.85,0),golf.FIT_PROFILE.grip_basis(hand).inverse())
		# The host process is deliberately disabled in this synthetic fixture.
		host.avatar.right_grip=host.controller_pose(1);host.avatar.left_grip=host.controller_pose(0)
		host.avatar.right_grip_frame=Engine.get_process_frames()
		golf.begin_club_fit();golf._update_club_pose()
		var initial_head_profiles:Array=golf.club_head_rotations.duplicate()
		var initial_flags:Array=golf.club_fitted.duplicate()
		click.call("trigger_click")
		for frame in 12:golf._update_fit_preview(.05)
		check(golf.fit_session.candidate.has("capture_grip"),"One trigger automatically captures the steady address: "+str(hand)+" · "+golf.status_text)
		var clearance:float=preload("res://addons/golfminus/scripts/golf/club_fit.gd").clearance(golf.physical_head.global_transform,golf.head_shape,golf.world.surface_height)
		check(is_equal_approx(golf.club.scale.x,1.0) and is_equal_approx(golf.club.scale.z,1.0),"Auto-fit retains shaft thickness")
		check(golf.physical_head.global_position.distance_to(golf.fit_session.candidate.target)<.001 and absf(clearance-.004)<.001,"Auto-fit connects hand to grounded address target: "+str(hand))
		click.call("ax_button");check(not golf.fitting_club,"Automatic fit remains acceptable from sole controller: "+str(hand)+" · "+golf.status_text);release.call("ax_button")
		check(golf.club_head_rotations==initial_head_profiles and golf.club_fitted==initial_flags,"Accepting length preserves default/manual head settings for every club")
		var guide=golf.course_guide
		guide.dock();guide.update()
		var hip:Transform3D=golf.equipment.hip_pose(1.0 if golf.left_handed else -1.0)
		var grip:Transform3D=Transform3D(Basis.IDENTITY,hip.origin)*golf.calibration.pose(hand).affine_inverse()
		await pose(hand,grip.origin)
		golf.equipment.set_stowed(true)
		trackers[hand].set_input("grip",0.0);golf.equipment.update();guide.update()
		trackers[hand].set_input("grip_click",true);golf.equipment.update();guide.update()
		check(golf.equipment.stowed,"Guide pickup takes priority over remote club equip: "+str(hand))
		trackers[hand].set_input("grip_click",false);trackers[hand].set_input("grip",1.0)
		check(guide.held and guide.held_hand==hand,"Tablet can be grabbed by sole hand: "+str(hand))
		await pose(hand,host.head.global_position+Vector3(0,-.3,-.6))
		golf.equipment.grip_was_down[hand]=false;golf.equipment.update()
		check(golf.equipment.stowed and guide.held,"Occupied guide hand cannot equip club: "+str(hand))
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
	trackers[1].set_input("grip",.6);check(golf.club_collision_enabled(),"Integrated grip engages above threshold")
	trackers[1].set_input("grip",.5);check(golf.club_collision_enabled(),"Integrated grip stays armed through pressure noise")
	host.golf_activity.pending_shot={"contact":{"tracking_correction_m":.002}}
	check(not golf.club_collision_enabled(),"Pending multiplayer approval inhibits duplicate contact")
	host.golf_activity.pending_shot.clear()
	golf.swing.cooldown=.8;golf.reject_contact({},"test_rejection")
	check(golf.swing.cooldown==0 and golf.last_contact_state=="rejected","Rejected contact releases cooldown in live game")
	trackers[1].set_input("grip",0.0);check(not golf.club_collision_enabled(),"Integrated release immediately disarms")
	check(golf.telemetry.start_capture(),"Tracking-loss diagnostic capture starts")
	trackers[1].invalidate_pose("grip");await settle()
	golf.last_origin_basis=host.origin.global_basis;golf.last_swing_us=Time.get_ticks_usec()-14000
	golf._swing()
	check(golf.last_swing_state=="tracking_lost" and golf.telemetry.queue.any(func(event):return event.type=="swing_state" and event.data.get("status")=="tracking_lost"),"Tracking loss is recorded before sampler returns")
	await pose(1,host.head.global_position+Vector3(.3,-.4,-.3))
	golf.last_swing_us=Time.get_ticks_usec()-14000;golf._swing()
	check(golf.telemetry.queue.any(func(event):return event.type=="swing_state" and event.data.get("status")=="tracking_reacquired"),"Reacquisition emits a diagnostic without reconstructing lost motion")
	golf.telemetry.stop_capture()
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
		var held:int=1-off
		for t in trackers:t.set_input("grip",0.0);t.set_input("trigger",0.0);t.set_input("primary",Vector2.ZERO)
		host.motor.blocked=false;host.motor.catch_controls=false;host.motor.turn_reserved=false;host.motor.stick_release_pending=false
		check(golf.one_hand_controller()==(host.left if held==0 else host.right),"Tracked idle offhand enables held-stick locomotion")
		for direction in [1.0,-1.0]:
			trackers[held].set_input("primary",Vector2(0,direction));host.motor.velocity=Vector3.ZERO
			host.motor._physics_process(.016)
			var held_facing:Vector3=-host.head.global_basis.z;held_facing.y=0
			check(host.motor.velocity.dot(held_facing)*direction>.01,"Held stick moves forward/back with offhand still tracked: %s / %s"%[held,direction])
		for smooth in [false,true]:
			host.motor.smooth_turn=smooth;host.motor.turn_latched=false
			var start:Basis=host.origin.global_basis
			trackers[held].set_input("primary",Vector2(.9,0));host.motor._physics_process(.016)
			check(not host.origin.global_basis.is_equal_approx(start),"Held stick turns in snap/smooth mode with tracked offhand: %s / %s"%[held,smooth])
		host.motor.smooth_turn=false;trackers[held].set_input("primary",Vector2.ZERO)
		golf.equipment.set_stowed(true);golf.support_hand.update(.016)
		check(golf.one_hand_controller()==(host.left if held==0 else host.right),"One-hand controls remain active while club is stowed")
		await remote_club_pickup(held,"tracked idle offhand "+str(held))
		golf.support_hand.update(.016)
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
		golf.equipment.set_stowed(true)
		await pose(held,host.head.global_position+Vector3(0,-.35,-.65))
		golf.equipment.update()
		trackers[held].set_input("grip",1.0);golf.equipment.update()
		check(golf.equipment.stowed,"Two active controllers still require hip pickup: "+str(held))
		trackers[held].set_input("grip",0.0);golf.equipment.update();golf.equipment.set_stowed(false)
	golf.set_hand(false);golf.begin_club_fit()
	trackers[0].set_input("primary",Vector2(0,.8));golf._update_fit_preview(.05)
	check(not golf.fit_session.candidate.is_empty(),"Other hand stick also adjusts club fit")
	golf.cancel_club_fit();trackers[0].set_input("primary",Vector2.ZERO)
	golf._update_club_pose();var shaft_pose:Transform3D=golf.club.global_transform
	var face_before:Vector3=-golf.physical_head.global_basis.z
	var face_up:Vector3=(golf.physical_head.global_basis*Basis(Vector3.RIGHT,-golf.head_shape.loft)).y
	golf.flip_club_face();golf._update_club_pose()
	check(golf.club.global_transform.is_equal_approx(shaft_pose) and (golf.physical_head.global_position-golf.physical_head.global_basis.x*.055).distance_to(golf.club.to_global(Vector3(0,-1.13 if golf.club_index<2 else -.86 if golf.club_index==7 else -.93,0)))<.001,"Explicit face reversal preserves shaft and hosel connection")
	var face_after:Vector3=-golf.physical_head.global_basis.z
	var before_tangent:Vector3=face_before-face_up*face_before.dot(face_up)
	var after_tangent:Vector3=face_after-face_up*face_after.dot(face_up)
	check(after_tangent.normalized().dot(before_tangent.normalized())<-.999 and absf(face_after.dot(face_up)-face_before.dot(face_up))<.001,"Reverse face turns 180 degrees about the club axis while preserving loft")
	host.golf_activity.leave();check(not host.motor.single_controller_controls,"Leaving golf restores fishing controls")
	for t in trackers:XRServer.remove_tracker(t)
	host.ambience.stop();host.queue_free();await process_frame;await create_timer(.3).timeout
	print("GOLF_CONTROLS_FEEDBACK_RESULT ",failures);quit(0 if failures.is_empty() else 1)
