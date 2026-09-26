extends SceneTree
const Gestures=preload("res://scripts/tracking/hand_gestures.gd")
const IK=preload("res://scripts/avatar_ik.gd")
var failures:Array=[]
var hands:Array[XRHandTracker]=[]
var hardware:Array[XRControllerTracker]=[]
var g:Node
var positions:=[Vector3(-.25,1.2,-.3),Vector3(.25,1.3,-.3)]
func check(ok:bool,label:String)->void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize()->void:run.call_deferred()
func pose(side:int,select:=false,menu:=false,fist:=false,basis:=Basis.IDENTITY)->void:
	var hand:=hands[side]
	var wrist_basis:Basis=basis*IK.controller_hand_basis(side==0)
	var wrist:=Transform3D(wrist_basis,positions[side]+basis.y*.06)
	for joint in 26:
		hand.set_hand_joint_flags(joint,15)
		hand.set_hand_joint_transform(joint,wrist)
	for finger in 5:
		var bend:=2.4 if fist and finger>=2 else 0.0
		var x:float=-.03 if finger==0 else float(finger)*.035
		var points:=[Vector3(x,0,0),Vector3(x,.03,0),Vector3(x,.05,0),Vector3(x+sin(bend)*.03,.05+cos(bend)*.03,0)]
		for i in 4:hand.set_hand_joint_transform(Gestures.Hands.FINGERS[finger][i],Transform3D(wrist_basis,wrist*points[i]))
	var thumb:Vector3=hand.get_hand_joint_transform(5).origin
	if select:hand.set_hand_joint_transform(10,Transform3D(wrist_basis,thumb+wrist_basis*Vector3(.015,0,0)))
	if menu:hand.set_hand_joint_transform(15,Transform3D(wrist_basis,thumb+wrist_basis*Vector3(.015,0,0)))
func tick(frames:=1)->void:
	for frame in frames:
		g.hand_actions._process(.02)
		await process_frame
func neutral()->void:
	for side in 2:pose(side)
	await tick(8)
func run()->void:
	g=load("res://scenes/main.tscn").instantiate();root.add_child(g)
	await create_timer(.4).timeout
	g.set_process(false);g.motor.set_physics_process(false);g.hand_actions.set_process(false)
	g.xr=true;g.tracking_manager.focused=true;g.head.position=Vector3(0,1.65,.65)
	for side in 2:
		var device:=XRControllerTracker.new();device.name="hand_test_controller_"+str(side);XRServer.add_tracker(device);hardware.append(device)
		var controller:XRController3D=g.left if side==0 else g.right;controller.tracker=device.name;controller.pose="grip"
		var hand:=XRHandTracker.new();hand.name="/user/hand_tracker/"+("left" if side==0 else "right");hand.has_tracking_data=true
		hand.hand_tracking_source=XRHandTracker.HAND_TRACKING_SOURCE_UNOBSTRUCTED;XRServer.add_tracker(hand);hands.append(hand)
	for side in 2:pose(side,true)
	await tick(10)
	check(not g.casting and not g.right.is_button_pressed("trigger_click"),"Acquiring a pinched hand requires opening it before actions")
	await neutral()
	check(g.hand_actions.active==[true,true] and g.left.get_has_tracking_data() and g.right.get_has_tracking_data(),"Optical joints supply both gameplay hand poses without controllers")
	check(g.controller_local_pose(1).origin.distance_to(positions[1])<.001,"Hand tool pose matches the avatar wrist mapping")
	g.controller_calibration.offsets[1]=Vector3(.1,.1,.1)
	check(g.controller_calibration.pose(1)==Transform3D.IDENTITY,"Stored controller offsets do not distort optical hands")
	check(g.left.get_vector2("primary")==Vector2.ZERO and g.right.get_vector2("primary")==Vector2.ZERO,"Hands never generate locomotion or turn axes")
	pose(0,false,true);await tick(35)
	check(g.menu_open,"Held thumb-middle pinch opens the shared menu")
	await tick(40);check(g.menu_open,"Holding menu gesture toggles once")

	# Point a real hand ray at a menu button, then pinch/release through UI input.
	var button:Button=g.avatar_menu.pages.controls.button
	var pixel:Vector2=button.get_global_rect().get_center()
	var target:Vector3=g.origin.to_local(g.avatar_panel.to_global(Vector3((pixel.x/1000-.5)*1.8,(.5-pixel.y/720)*1.296,0)))
	var wrist_origin:=Vector3(.25,1.3,-.3)
	var aim:=Basis.looking_at((target-wrist_origin).normalized(),Vector3.UP)
	var wrist_basis:=Basis(-aim.x,-aim.z,-aim.y)
	var grip_basis:=wrist_basis*IK.controller_hand_basis(false).inverse()
	positions[1]=wrist_origin-grip_basis.y*.06
	pose(1,false,false,false,grip_basis);await tick(8);g._update_menu_pointer()
	pose(1,true,false,false,grip_basis);await tick(3)
	check(g.menu_mouse_down,"Hand index pinch presses the actual menu cursor")
	pose(1,false,false,false,grip_basis);await tick(3)
	check(g.avatar_menu.active_page=="controls" and not g.menu_mouse_down,"Releasing pinch selects the pointed menu tab")
	var cancelled_clicks:Array=[];button.pressed.connect(func():cancelled_clicks.append(true))
	g._update_menu_pointer();pose(1,true,false,false,grip_basis);await tick(3)
	hands[1].has_tracking_data=false;await tick(3)
	check(not g.menu_mouse_down and cancelled_clicks.is_empty(),"Losing a pinched hand cancels the UI press without clicking")
	hands[1].has_tracking_data=true
	positions[1]=Vector3(.25,1.3,-.3)

	await neutral();pose(0,false,true);await tick(35)
	check(not g.menu_open,"A new menu gesture closes the menu")
	await neutral()
	# A real two-stroke cast reaches existing motion/release logic.
	g._select_location("meadow_bend",false);g.game.reset();g.head_aimed_casting=false
	g.rod.reparent(g.right);g.rod.top_level=true
	pose(1,true);await tick(3)
	check(g.casting,"Index pinch starts casting")
	for step in 5:
		positions[1].z+=.08;pose(1,true);await tick();g._sample_cast_swing(.05)
	for step in 7:
		positions[1].z-=.10;pose(1,true);await tick();g._sample_cast_swing(.05)
	pose(1);await tick()
	check(g.game.state==g.Session.State.CASTING,"Pinch release casts after a physical back/forward stroke")
	g.game.reset();await neutral();pose(1,true);await tick(3)
	g.game.fly.strokes=1
	hands[1].has_tracking_data=false;await tick()
	check(not g.casting and g.game.state!=g.Session.State.CASTING,"Tracking loss cancels a charged cast instead of releasing it")
	hands[1].has_tracking_data=true;pose(1,true);await tick(10)
	check(not g.casting,"Reacquisition with fingers pinched cannot start another cast")
	await neutral();pose(1,true);await tick(3);g.game.fly.strokes=1
	positions[1].x+=1;pose(1,true);await tick()
	check(not g.casting and not g.right.is_button_pressed("trigger_click"),"An optical pose jump cancels the cast and disarms gestures")
	positions[1].x-=1
	await neutral();pose(0,true);await tick(3)
	check(g._reel_grab_pressed() and g.left.get_float("grip")>.55,"Offhand pinch engages the existing reel and fly-line grip")
	var reel=preload("res://scripts/reel_tracker.gd").new()
	var retrieved:=0.0
	for step in 12:
		var angle:=step*.12
		retrieved+=reel.sample(Vector3(0,cos(angle)*.09,sin(angle)*.09),g._reel_grab_pressed(),.02,true)
	check(retrieved>0,"Pinched offhand circular movement retrieves line through existing reel tracker")
	pose(0);await tick();check(not g._reel_grab_pressed(),"Opening offhand releases reel")
	# Native/controller-inferred joints must not commandeer a physical device.
	hands[1].hand_tracking_source=XRHandTracker.HAND_TRACKING_SOURCE_CONTROLLER
	hardware[1].set_pose("grip",Transform3D(Basis.IDENTITY,positions[1]),Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	await tick()
	check(g.right.tracker==hardware[1].name and not g.hand_actions.active[1],"Picking up a controller restores its original tracker")
	check(g.controller_calibration.pose(1).origin==Vector3(.1,.1,.1),"Controller calibration returns after handoff")
	check(not Gestures.optical(hands[1],hardware[1]),"Controller-inferred fingers never produce gesture actions")
	hands[1].hand_tracking_source=XRHandTracker.HAND_TRACKING_SOURCE_UNKNOWN
	check(not Gestures.optical(hands[1],hardware[1]),"Unknown joints cannot override a tracked physical controller")
	hands[1].hand_tracking_source=XRHandTracker.HAND_TRACKING_SOURCE_UNOBSTRUCTED
	await neutral()
	g.tracking_manager.focused=false;await tick()
	check(not g.hand_actions.active[0] and not g.hand_actions.active[1],"Focus loss releases both hands")
	g.tracking_manager.focused=true;await neutral()
	# Golf uses the same optical grip and the existing physical strike gate.
	await g.golf_activity.join_course("spyglass");g.golf_activity.start_play("solo")
	var golf=g.golf_activity.golf;golf.set_process(false);golf.set_physics_process(false);golf.focused=true;golf.toggle_menu(false)
	await neutral();golf.reset_swing()
	check(not golf.club_input_active(),"An open hand leaves golf strikes disarmed")
	pose(1,false,false,true);await tick(3)
	check(golf.club_input_active() and golf.club_collision_enabled(),"Curling striking hand arms the real golf club")
	var old_head:Vector3=golf._update_club_pose();positions[1].x+=.08;pose(1,false,false,true);await tick()
	check(golf._update_club_pose().distance_to(old_head)>.06,"Optical wrist motion drives physical golf club head")

	# Sweep the real hand-driven physical club into a ball, then apply the hit.
	golf.set_club(7);golf._update_club_pose()
	var face:Vector3=-golf.physical_head.global_basis.z.normalized()
	var ball_start:Vector3=golf.ball.position
	var shift:Vector3=ball_start-face*.20-golf.physical_head.global_position
	positions[1]+=g.origin.global_basis.inverse()*shift
	await neutral();pose(1,false,false,true);await tick(3);golf._update_club_pose()
	golf.swing.reset();golf.swing.cooldown=0
	golf.swing.sample_pose(golf.physical_head.global_transform,golf.head_shape,golf.ball.position,.02,golf.club_collision_enabled())
	var contact:Dictionary={}
	for step in 12:
		positions[1]+=g.origin.global_basis.inverse()*face*.035
		pose(1,false,false,true);await tick();golf._update_club_pose()
		contact=golf.swing.sample_pose(golf.physical_head.global_transform,golf.head_shape,golf.ball.position,.02,golf.club_collision_enabled())
		if not contact.is_empty():break
	check(not contact.is_empty(),"Optical hand swing produces physical club-ball contact")
	if not contact.is_empty():check(golf.strike(contact.velocity,contact.normal,contact) and golf.ball.moving,"Hand-driven club contact launches the golf ball")
	golf.ball.place(ball_start)
	pose(1);await tick();check(not golf.club_input_active(),"Opening striking hand disarms immediately")
	pose(1,false,false,true);await tick();hands[1].has_tracking_data=false;hardware[1].invalidate_pose("grip");await tick()
	check(not golf.club_input_active(),"Lost hand tracking cannot strike a golf ball")
	g.golf_activity.leave();g.queue_free();await process_frame
	for hand in hands:XRServer.remove_tracker(hand)
	for device in hardware:XRServer.remove_tracker(device)
	await create_timer(.2).timeout
	print("HAND_ACTIONS_RESULT ",failures);quit(0 if failures.is_empty() else 1)
