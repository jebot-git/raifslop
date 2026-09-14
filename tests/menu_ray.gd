extends SceneTree
const Ray=preload("res://scripts/menu_ray.gd")
var failures:Array=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func run():
	var g=load("res://scenes/main.tscn").instantiate();root.add_child(g)
	await create_timer(.3).timeout;g.set_process(false);g.motor.set_physics_process(false)
	var controller:=XRControllerTracker.new();controller.name="laser_right";XRServer.add_tracker(controller)
	g.right.tracker=controller.name;g.right.pose="grip"
	for pose in ["grip","aim"]:controller.set_pose(pose,Transform3D(Basis.IDENTITY,Vector3(0,1.2,-.2)),Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	for i in 5:await process_frame
	g.xr=true;g.tracking_manager.focused=true
	g.avatar.right_index_tip=g.right.to_global(Vector3(.03,.01,-.1));g.avatar.right_index_tip_frame=Engine.get_process_frames()
	var ray:=Ray.sample(g)
	check(ray.get("source")=="avatar" and ray.origin.is_equal_approx(g.avatar.index_touch_position()),"Controller laser starts exactly at visible avatar fingertip")
	var before:Vector3=ray.origin;g.rod.position+=Vector3(2,3,4)
	check(Ray.sample(g).origin.is_equal_approx(before),"Moving rod cannot move menu laser origin")
	var hand:=XRHandTracker.new();hand.name="/user/hand_tracker/right";hand.has_tracking_data=true;XRServer.add_tracker(hand)
	var tip:=XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP
	var distal:=XRHandTracker.HAND_JOINT_INDEX_FINGER_PHALANX_DISTAL
	for joint in [tip,distal]:hand.set_hand_joint_flags(joint,XRHandTracker.HAND_JOINT_FLAG_POSITION_VALID)
	hand.set_hand_joint_transform(tip,Transform3D(Basis.IDENTITY,Vector3(.1,1.2,-.3)))
	hand.set_hand_joint_transform(distal,Transform3D(Basis.IDENTITY,Vector3(.1,1.2,-.27)))
	hand.hand_tracking_source = XRHandTracker.HAND_TRACKING_SOURCE_CONTROLLER
	var stable := Ray.sample(g)
	hand.set_hand_joint_transform(tip,Transform3D(Basis.IDENTITY,Vector3(.15,1.1,-.25)))
	g.avatar.right_index_tip += Vector3(.03,-.05,.04)
	var curled := Ray.sample(g)
	check(curled.source != "native" and curled.aim_origin.is_equal_approx(stable.aim_origin) and curled.direction.is_equal_approx(stable.direction),"Controller-inferred curl and avatar finger motion cannot move the aim ray")
	hand.set_hand_joint_transform(tip,Transform3D(Basis.IDENTITY,Vector3(.1,1.2,-.3)))
	hand.hand_tracking_source = XRHandTracker.HAND_TRACKING_SOURCE_UNOBSTRUCTED
	controller.invalidate_pose("aim")
	g.origin.rotation.y=.4;XRServer.world_scale=1.2
	ray=Ray.sample(g)
	check(ray.get("source")=="native" and ray.origin.is_equal_approx(g.origin.to_global(Vector3(.1,1.2,-.3)*1.2)),"Native fingertip takes priority and respects tracking world scale")
	check(ray.direction.dot(-g.origin.global_basis.z)>.999,"Native laser follows index finger direction")
	g.origin.rotation.y=0;XRServer.world_scale=1
	g.avatar_panel=MeshInstance3D.new();g.add_child(g.avatar_panel);g.avatar_panel.global_position=g.origin.to_global(Vector3(.1,1.2,-2))
	g.menu_pointer=MeshInstance3D.new();g.add_child(g.menu_pointer)
	g.menu_laser=MeshInstance3D.new();g.add_child(g.menu_laser)
	g.avatar_menu_view=SubViewport.new();g.avatar_menu_view.size=Vector2i(1000,720);g.add_child(g.avatar_menu_view)
	g.menu_open=true;g._update_menu_pointer()
	check(g._pointer_position().distance_to(Vector2(500,360))<.01,"Fingertip ray hits intended menu coordinates")
	var beam_start:Vector3=g.menu_laser.global_transform*Vector3(0,-.5,0)
	check(g.menu_laser.visible and beam_start.distance_to(Ray.sample(g).origin)<.0001,"Visible beam begins at the same fingertip as interaction ray")
	g.menu_mouse_down=true;hand.has_tracking_data=false;controller.invalidate_pose("grip")
	for i in 5:await process_frame
	g._update_menu_pointer()
	check(not g.menu_laser.visible and not g.menu_pointer.visible and not g.menu_mouse_down,"Tracking loss hides laser and releases pending UI drag")
	g.tracking_manager.focused=false
	check(Ray.sample(g).is_empty(),"Unfocused session cannot point at menu")
	XRServer.remove_tracker(hand);XRServer.remove_tracker(controller)
	g.queue_free();await process_frame;await create_timer(.3).timeout
	print("MENU_RAY_RESULT ",failures);quit(0 if failures.is_empty() else 1)
