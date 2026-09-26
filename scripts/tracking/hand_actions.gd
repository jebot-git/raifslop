extends Node
## Adapt optical hands into the same per-hand action channels as controllers.
## Original runtime trackers remain untouched. No locomotion axes are generated.
const Gestures=preload("res://scripts/tracking/hand_gestures.gd")
var host:Node
var controllers:Array[XRController3D]=[]
var originals:Array[StringName]=[]
var original_poses:Array[StringName]=[]
var proxies:Array[XRControllerTracker]=[]
var gestures:Array=[]
var active:=[false,false]
var previous:=[Transform3D.IDENTITY,Transform3D.IDENTITY]
var announced:=false
func setup(game:Node)->void:
	host=game;name="HandActions";add_to_group("activity_services")
	process_priority=-50
	controllers.assign([game.left,game.right])
	for side in 2:
		originals.append(controllers[side].tracker)
		original_poses.append(controllers[side].pose)
		var proxy:=XRControllerTracker.new();proxy.name="/ubs/optical/"+str(get_instance_id())+"/"+str(side)
		proxy.hand=XRPositionalTracker.TRACKER_HAND_LEFT if side==0 else XRPositionalTracker.TRACKER_HAND_RIGHT
		proxy.set_input("primary",Vector2.ZERO);proxy.set_input("secondary",Vector2.ZERO)
		XRServer.add_tracker(proxy);proxies.append(proxy);gestures.append(Gestures.new())
func _process(delta:float)->void:
	if not is_instance_valid(host):return
	var focused:bool=host.xr and is_instance_valid(host.tracking_manager) and host.tracking_manager.focused
	for side in 2:
		if not active[side]:
			originals[side]=controllers[side].tracker;original_poses[side]=controllers[side].pose
		var runtime:=XRServer.get_tracker(originals[side]) as XRPositionalTracker
		var hand:=XRServer.get_tracker("/user/hand_tracker/"+("left" if side==0 else "right")) as XRHandTracker
		var optical:bool=focused and Gestures.optical(hand,runtime)
		var sample:Dictionary=gestures[side].sample(hand,side==0,delta) if optical else {}
		if sample.is_empty():
			gestures[side].reset()
			if active[side]:_release(side)
			continue
		var proxy:XRControllerTracker=proxies[side]
		if not active[side]:
			_cancel(side);active[side]=true
			host.controller_calibration.optical_hands[side]=true
			previous[side]=sample.grip_pose
			if not announced:
				announced=true
				host.game.message="Hands: hold thumb + middle finger to open the menu. Index pinch casts; left pinch reels."
		var pose:Transform3D=sample.grip_pose
		# Reacquisition and optical jumps must not release a charged cast or hit a ball.
		var jump:bool=pose.origin.distance_to(previous[side].origin)>maxf(.15,12*delta) or pose.basis.get_rotation_quaternion().angle_to(previous[side].basis.get_rotation_quaternion())>maxf(.5,65*delta)
		if jump:
			_cancel(side);gestures[side].reset();sample.select=false;sample.grasp=0.0;sample.menu=false
		previous[side]=pose
		var aim:Transform3D=sample.aim_pose
		if runtime and str(runtime.profile).contains("hand_interaction") and runtime.has_pose("aim") and runtime.get_pose("aim").has_tracking_data:
			aim=runtime.get_pose("aim").transform
		var confidence:=XRPose.XR_TRACKING_CONFIDENCE_HIGH if sample.reliable else XRPose.XR_TRACKING_CONFIDENCE_LOW
		proxy.set_pose("grip",pose,Vector3.ZERO,Vector3.ZERO,confidence)
		proxy.set_pose("aim",aim,Vector3.ZERO,Vector3.ZERO,confidence)
		# XRNode3D binds to an existing XRPose; create it before switching source.
		if controllers[side].tracker!=proxy.name:
			controllers[side].tracker=proxy.name;controllers[side].pose="grip"
		host.calibrated_hands[side].transform=Transform3D.IDENTITY
		if sample.menu:
			_cancel(side)
			if is_instance_valid(host.golf_activity) and host.golf_activity.active:host.golf_activity.golf.toggle_menu(not host.menu_open)
			else:host._toggle_avatar_menu()
		# Offhand pinch can hold the reel or fly line. The rod hand's pinch is
		# exclusively the trigger, so charging a cast cannot stow the rod.
		var grip:float=maxf(sample.grasp,float(sample.select)) if side==0 else sample.grasp
		proxy.set_input("grip",grip);proxy.set_input("grip_click",grip>.65)
		# Fishing's left grip+trigger releases a landed catch. A single pinch
		# must only grab it/reel, not accidentally perform both actions at once.
		var selects:bool=sample.select and (side==1 or host.menu_open or is_instance_valid(host.golf_activity) and host.golf_activity.active and host.golf_activity.golf.pointer_controller()==controllers[side])
		proxy.set_input("trigger",float(selects));proxy.set_input("trigger_click",selects)
func _cancel(side:int)->void:
	if side==1:
		host.casting=false;host.game.fly.charging=false
		host.cast_preparation.clear();host.cast_pose_sampler.ready=false
	host.tracking_was_valid=false;host.reel_tracker.engaged=false;host.game.fly.release_strip(true)
	host.fight_input.reset()
	if host.menu_mouse_down:host._menu_click(false,true)
	if is_instance_valid(host.golf_activity) and host.golf_activity.active:
		if host.golf_activity.golf.fitting_club:host.golf_activity.golf.cancel_club_fit()
		host.golf_activity.golf.reset_swing()
		if is_instance_valid(host.golf_activity.clubhouse_board):host.golf_activity.clubhouse_board.cancel_input()
func _release(side:int)->void:
	_cancel(side)
	var proxy:XRControllerTracker=proxies[side]
	proxy.invalidate_pose("grip");proxy.invalidate_pose("aim")
	for key in ["trigger_click","grip_click"]:proxy.set_input(key,false)
	for key in ["trigger","grip"]:proxy.set_input(key,0.0)
	controllers[side].tracker=originals[side]
	controllers[side].pose=original_poses[side]
	active[side]=false;host.controller_calibration.optical_hands[side]=false
	host.calibrated_hands[side].transform=host.controller_calibration.pose(side)
func _exit_tree()->void:
	for side in proxies.size():
		if is_instance_valid(controllers[side]) and controllers[side].tracker==proxies[side].name:
			controllers[side].tracker=originals[side];controllers[side].pose=original_poses[side]
		if is_instance_valid(host):host.controller_calibration.optical_hands[side]=false
		XRServer.remove_tracker(proxies[side])
