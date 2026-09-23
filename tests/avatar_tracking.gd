extends SceneTree
var failures: Array=[]
func _initialize(): run.call_deferred()
func check(ok: bool,label: String):
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures.append(label)
func run():
	var game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	await process_frame
	game.set_process(false); game.motor.set_physics_process(false)
	var avatar=game.avatar
	var sk: Skeleton3D=avatar.skeleton
	check(avatar.mouth.binds.slice(0,5).any(func(b):return not b.is_empty()),"VRM vowel bindings survive animation stripping")
	check(avatar.eyes.eye_bones.size()==2 or avatar.eyes.binds.any(func(b):return not b.is_empty()),"VRM eyes and eyelids resolved")
	var frame: Transform3D=game.motor.global_transform
	var body={"left_curls":PackedFloat32Array([0,1,0,0,0]),"right_curls":PackedFloat32Array([0,0,0,0,0])}
	avatar.apply_tracking(frame,body,{"look":Vector2(.1,.05),"blink":Vector2(.5,.2),"gaze":true,"lids":true})
	avatar.update_targets(game.head,game.reel_hand_target,game.rod,game.motor.position.y,Vector3.ZERO,.016)
	avatar.solver._process_modification_with_delta(.016)
	var index:=sk.find_bone("LeftIndexProximal");var middle:=sk.find_bone("LeftMiddleProximal")
	check(not sk.get_bone_pose_rotation(index).is_equal_approx(sk.get_bone_rest(index).basis.get_rotation_quaternion()),"Individual index curl reaches skeleton")
	check(sk.get_bone_pose_rotation(middle).is_equal_approx(sk.get_bone_rest(middle).basis.get_rotation_quaternion()),"Uncurled middle finger stays open")
	avatar.eyes._process_modification_with_delta(.1)
	check(avatar.eyes.look.x>.08 and avatar.eyes.blink.x>.4,"Measured gaze and eyelids animate")
	avatar.mouth.speak(PackedFloat32Array([.8,.1,0,0,0]));avatar.mouth._process(.05)
	check(avatar.mouth.weights[0]>.5,"Viseme opens mouth")
	for i in range(60): avatar.mouth._process(.02)
	check(avatar.mouth.weights[0]<.001,"Viseme expires to neutral after speech")
	var foot:=sk.find_bone("LeftFoot")
	var planted: Vector3=sk.to_global(sk.get_bone_global_pose(foot).origin)
	body.left_foot=Transform3D(Basis.IDENTITY,frame.affine_inverse()*(planted+Vector3.UP*.22))
	avatar.apply_tracking(frame,body,{})
	avatar.update_targets(game.head,game.reel_hand_target,game.rod,game.motor.position.y,Vector3.ZERO,.016)
	avatar.solver._process_modification_with_delta(.016)
	check(sk.to_global(sk.get_bone_global_pose(foot).origin).y>planted.y+.12,"Tracked foot overrides procedural floor plant")
	avatar.apply_tracking(frame,{},{}); avatar.update_targets(game.head,game.reel_hand_target,game.rod,game.motor.position.y,Vector3(1,0,0),.2)
	avatar.solver._process_modification_with_delta(.2)
	check(avatar.speed>0 and avatar.phase>0,"Fallback gait advances with locomotion")
	game.head.rotation.y=.6;avatar.rotation.y=.6
	var oriented: Dictionary={}
	var expected: Dictionary={}
	for row in [["hips","Hips"],["chest","Chest"],["left_foot","LeftFoot"],["right_foot","RightFoot"]]:
		var id: int=sk.find_bone(row[1])
		if id<0: continue
		var reference: Basis=avatar.global_basis.inverse()*sk.global_basis.orthonormalized()*sk.get_bone_global_rest(id).basis.orthonormalized()
		expected[id]=Basis(Vector3.UP,.6)*reference
		oriented[row[0]]=Transform3D(Basis(Vector3.UP,.6),frame.affine_inverse()*sk.to_global(sk.get_bone_global_rest(id).origin))
	avatar.apply_tracking(frame,oriented,{})
	avatar.update_targets(game.head,game.reel_hand_target,game.rod,game.motor.position.y,Vector3.ZERO,.016)
	avatar.solver._process_modification_with_delta(.016)
	for id in expected:
		var actual: Basis=sk.global_basis.orthonormalized()*sk.get_bone_global_pose(id).basis.orthonormalized()
		check(actual.is_equal_approx(expected[id]),"Tracked "+sk.get_bone_name(id)+" orientation does not double player yaw")
	var target_before: Vector3=game._cast_direction()
	game.tracking_manager.face={"look":Vector2(.2,.1),"blink":Vector2.ZERO,"gaze":true,"lids":false}
	check(game._cast_direction().is_equal_approx(target_before),"Eye gaze never changes cast aim")
	var detector=preload("res://scripts/tracking/t_pose.gd").new()
	var fired:=false
	for i in range(100): fired=detector.sample(Transform3D(Basis.IDENTITY,Vector3(0,1.65,0)),Vector3(-.65,1.4,0),Vector3(.65,1.4,0),.02,true) or fired
	check(fired and detector.latched,"Steady T-pose calibrates once")
	check(not detector.sample(Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,.02,false),"Blocked calibration never triggers")
	var face_tracker:=XRFaceTracker.new(); face_tracker.name="/user/face_tracker"
	face_tracker.set_blend_shape(XRFaceTracker.FT_JAW_OPEN,.65)
	face_tracker.set_blend_shape(XRFaceTracker.FT_EYE_CLOSED_LEFT,.5)
	face_tracker.set_blend_shape(XRFaceTracker.FT_MOUTH_CORNER_PULL_LEFT,.6)
	face_tracker.set_blend_shape(XRFaceTracker.FT_MOUTH_CORNER_PULL_RIGHT,.6)
	XRServer.add_tracker(face_tracker)
	var gaze_tracker:=XRControllerTracker.new(); gaze_tracker.name="/user/eyes_ext"; XRServer.add_tracker(gaze_tracker)
	gaze_tracker.set_pose("eye_gaze_pose",Transform3D(Basis(Vector3.UP,.1),Vector3(0,1.65,0)),Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	await process_frame
	var measured: Dictionary=game.tracking_manager.eyes.sample()
	check(measured.get("gaze",false) and measured.blink.x>.4,"XR eye and face tracker samples are available")
	check(measured.mouth[0]>.6 and measured.expressions[0]>.35,"Tracked jaw and smile map to VRM expressions")
	game.tracking_manager.focused=false
	check(game.tracking_manager.eyes.sample().is_empty(),"Focus loss clears face sample")
	game.tracking_manager.focused=true
	XRServer.remove_tracker(face_tracker);XRServer.remove_tracker(gaze_tracker)
	check(game.tracking_manager.eyes.sample().is_empty(),"Missing face and eye devices return no fabricated measurements")
	var head_tracker:=XRPositionalTracker.new();head_tracker.type=XRServer.TRACKER_HEAD;head_tracker.name="head"
	head_tracker.set_pose("default",game.head.transform,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);XRServer.add_tracker(head_tracker)
	game.xr=true; game.game.state=game.Session.State.READY
	game.tracking_manager.calibration_pending=true
	game.motor.position.x+=1.5;game.head.position.x+=.8;game.head.rotation.y=.7
	for i in 12: game.tracking_manager.sample(.05)
	var spawn: Vector3=game.motor.safe_spawn
	check(not game.tracking_manager.calibration_pending and game.motor.tracking_focused and game.motor.global_position.is_equal_approx(spawn) and Vector2(game.head.global_position.x-spawn.x,game.head.global_position.z-spawn.z).length()<.001,"Startup automatically recenters offset room tracking at the safe spawn")
	game.motor.position.x+=.4
	var walked: Vector3=game.motor.position
	for i in 12:game.tracking_manager.sample(.05)
	check(game.motor.position.is_equal_approx(walked),"Startup recenter runs once and does not undo later movement")
	game.head.rotation.y=.4
	var anchor: Vector3=game.motor.global_position
	check(game.tracking_manager.recenter(),"Standing recenter accepted while idle")
	check(game.motor.global_position.is_equal_approx(anchor) and absf(game.head.global_position.x-anchor.x)<.001 and absf(game.head.global_position.z-anchor.z)<.001,"Recenter aligns head to capsule without relocating player")
	check(absf(game.head.global_basis.get_euler().y)<.001 and not game.tracking_was_valid and not game.reel_tracker.engaged,"Recenter resets facing and gesture baselines")
	game.game.state=game.Session.State.CASTING
	check(not game.tracking_manager.recenter(),"Recenter cannot turn an active cast into a gesture")
	game.game.state=game.Session.State.READY;game.tracking_manager.seated=true;game.head.position.y=1.1
	check(game.tracking_manager.recenter() and absf(game.head.global_position.y-anchor.y-1.1)<.01 and XRServer.world_scale==1.0,"Seated recenter preserves actual height and metre scale")
	var height_before:float=game.tracking_manager.user_height
	game.tracking_manager.seated=false;game.tracking_manager.height_confirmed=false;game.tracking_manager.height_measured=false
	game.head.position.y=1.42
	for i in 40:game.tracking_manager._sample_height(.05)
	check(absf(game.tracking_manager.user_height-1.42)<.001,"Stable physical eye height sizes the avatar")
	game.head.position.y=.9
	for i in 40:game.tracking_manager._sample_height(.05)
	check(absf(game.tracking_manager.user_height-1.42)<.001,"Crouching never shrinks a measured avatar")
	game.head.position.y=1.8
	for i in 40:game.tracking_manager._sample_height(.05)
	check(absf(game.tracking_manager.user_height-1.8)<.001,"Standing after seated startup corrects provisional height")
	game.tracking_manager.measure_height()
	game.head.position.y=1.9
	for i in 40:game.tracking_manager._sample_height(.05)
	check(absf(game.tracking_manager.user_height-1.8)<.001,"Explicit height measurement stays fixed")
	game.tracking_manager.user_height=height_before;game.tracking_manager.apply_user_height()
	# A body T-pose must not rebase the room or silently resize physical motion.
	game.tracking_manager.seated=false
	game.head.position=Vector3(.25,1.55,-.2);game.head.rotation=Vector3(0,.3,0)
	var body_tracker:=XRBodyTracker.new();body_tracker.name="regression_body";body_tracker.has_tracking_data=true
	for joint in range(XRBodyTracker.JOINT_MAX):body_tracker.set_joint_flags(joint,0)
	for joint in [XRBodyTracker.JOINT_HIPS,XRBodyTracker.JOINT_LEFT_FOOT,XRBodyTracker.JOINT_RIGHT_FOOT]:
		body_tracker.set_joint_flags(joint,XRBodyTracker.JOINT_FLAG_POSITION_VALID|XRBodyTracker.JOINT_FLAG_ORIENTATION_VALID)
		body_tracker.set_joint_transform(joint,Transform3D(Basis.IDENTITY,Vector3(0,.9 if joint==XRBodyTracker.JOINT_HIPS else .08,0)))
	XRServer.add_tracker(body_tracker)
	var controllers:Array[XRControllerTracker]=[]
	for side in 2:
		var tracker:=XRControllerTracker.new();tracker.name="tpose_regression_"+str(side);XRServer.add_tracker(tracker);controllers.append(tracker)
		var node:XRController3D=game.left if side==0 else game.right
		node.tracker=tracker.name;node.pose="grip"
		var at:Vector3=game.head.position+Basis(Vector3.UP,.3)*Vector3(-.65 if side==0 else .65,-.25,0)
		tracker.set_pose("grip",Transform3D(Basis.IDENTITY,at),Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	await process_frame
	var room_before:Transform3D=game.origin.transform
	var scale_before:float=XRServer.world_scale
	for i in 80:game.tracking_manager.sample(.02)
	check(game.tracking_manager.tracking.calibrated,"Live T-pose calibrates available body sensors")
	check(game.origin.transform.is_equal_approx(room_before) and XRServer.world_scale==scale_before,"T-pose preserves room origin, floor height, yaw and world scale")
	for tracker in controllers:XRServer.remove_tracker(tracker)
	XRServer.remove_tracker(body_tracker)
	head_tracker.invalidate_pose("default")
	check(not game.tracking_manager.recenter(),"Recenter rejects lost head tracking")
	XRServer.remove_tracker(head_tracker)
	XRServer.world_scale=1.0
	game.network.leave();game.queue_free();await process_frame;await create_timer(.15).timeout
	print("AVATAR_TRACKING_RESULT ",failures);quit(0 if failures.is_empty() else 1)
