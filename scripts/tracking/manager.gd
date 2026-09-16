extends Node
## Fishing adapter for FPSloppa tracking, calibration and recentering.
const Scale = preload("res://scripts/avatar_scale.gd")
var root_game: Node
var game: Node # Permission interface consumed by upstream tracking.
var origin: XROrigin3D
var head: Camera3D
var left: XRController3D
var right: XRController3D
var focused := true
# FPSloppa calibrates the physical player once, independently of avatar size.
var calibration_pending := true
var startup_pose_time := 0.0
var startup_settle_frames := 0
var seated := false
var expressions_enabled := true
var tracked_leg_animation := false
var calibration_notice_time := 0.0
var calibration_notice := ""
var body: Dictionary={}
var face: Dictionary={}
var tracking=preload("res://scripts/tracking/tracking.gd").new()
var eyes=preload("res://scripts/tracking/eyes.gd").new()
var t_pose_detector=preload("res://scripts/tracking/t_pose.gd").new()
var message := "Tracking ready"
func setup(root: Node) -> void:
	root_game=root; game=root.network
	origin=root.origin; head=root.head; left=root.left; right=root.right
	if root.xr: root.motor.tracking_focused=false
	add_child(tracking); tracking.setup(self)
	add_child(eyes); eyes.setup(self)
	var config:=ConfigFile.new()
	if config.load("user://tracking.cfg")==OK:
		seated=bool(config.get_value("pose","seated",false))
		expressions_enabled=bool(config.get_value("pose","expressions",true))
		tracked_leg_animation=bool(config.get_value("pose","tracked_leg_animation",false))
		tracking.enabled=bool(config.get_value("pose","body",true))
	tracking.calibration_completed.connect(func():
		message="Body calibrated"
		calibration_notice="Body calibrated · lower your arms"
		calibration_notice_time=2.0
		root_game._tone(880,.15)
		for controller_node in [left, right]: controller_node.trigger_haptic_pulse("haptic",0,0.4,0.12,0))
	var xr:=XRServer.find_interface("OpenXR") as OpenXRInterface
	if xr:
		xr.session_focussed.connect(func(): focused=true)
		xr.session_visible.connect(func(): focused=false)
		xr.session_stopping.connect(func(): focused=false; clear_samples())
func controller(node_name: String, tracker_name: String, pose_name: String) -> XRController3D:
	var node:=XRController3D.new(); node.name=node_name; node.tracker=tracker_name; node.pose=pose_name; origin.add_child(node)
	return node
func clear_samples() -> void:
	body.clear(); face.clear(); t_pose_detector.reset()
	if is_instance_valid(root_game): root_game.hud.calibration_message=""
func sample(delta: float) -> void:
	var xr := XRServer.find_interface("OpenXR") as OpenXRInterface
	if root_game.xr and xr and xr.is_initialized():
		focused = xr.get_session_state() == OpenXRInterface.SESSION_STATE_FOCUSED
	if root_game.xr and calibration_pending:
		if focused and head_tracked() and head.position.y > .5:
			startup_pose_time += minf(delta, .05)
			if startup_pose_time >= .25:
				root_game.motor.relocate(root_game.motor.safe_spawn)
				if recenter(): startup_settle_frames=2
		else: startup_pose_time=0.0
	elif startup_settle_frames > 0 and focused and head_tracked():
		# XR world scale reaches camera poses on the next tracking update.
		var offset: Vector3=head.global_position-root_game.motor.global_position
		offset.y=0
		origin.global_position-=offset
		startup_settle_frames-=1
	calibration_notice_time=maxf(0,calibration_notice_time-delta)
	if calibration_notice_time<=0: calibration_notice=""
	root_game.motor.tracking_focused=focused and (not root_game.xr or (not calibration_pending and startup_settle_frames==0))
	if not root_game.xr or not focused or not head_tracked():
		clear_samples(); return
	body=preload("res://scripts/tracking/poses.gd").validate_body(tracking.sample())
	face=eyes.sample() if expressions_enabled else {}
	var allowed: bool=not seated and root_game.game.state==0 and not root_game.casting and not root_game.fish_guide.held and left.get_has_tracking_data() and right.get_has_tracking_data() and tracking.enabled
	var detected := t_pose_detector.sample(head.transform,left.position,right.position,delta,allowed)
	if t_pose_detector.held>0 or detected:
		if not tracking.full_body_available():
			calibration_notice="T-pose detected · enable body trackers or SlimeVR OSC"
			t_pose_detector.reset(); t_pose_detector.latched=false
		elif detected:
			if recenter(): tracking.calibrate(true)
		else: calibration_notice="Hold T-pose · %.1f s" % maxf(0,t_pose_detector.HOLD_SECONDS-t_pose_detector.held)
		calibration_notice_time=2.0 if detected else .25
	root_game.hud.calibration_message=calibration_notice
func calibrate() -> void:
	if not root_game.xr: message="Calibration requires an XR session"; return
	tracking.calibrate()
	message=tracking.status
func recenter() -> bool:
	if not root_game.xr or not focused or root_game.game.state!=0 or root_game.casting or root_game.fish_guide.held:
		message="Finish the cast and put away the Guide before recentering"
		return false
	if not head_tracked() or head.position.y<.3: message="Head tracking is unavailable"; return false
	calibration_pending=false
	# FPSloppa height calibration: standing scale or seated height translation.
	if seated:
		var physical_height:=head.position.y/XRServer.world_scale
		XRServer.world_scale=1.0
		origin.position.y=clampf(Scale.HEAD_HEIGHT-physical_height,-.5,1.4)
	else:
		XRServer.world_scale=Scale.world_scale(XRServer.world_scale,head.position.y)
		origin.position.y=0
	var yaw:=atan2(head.global_basis.z.x,head.global_basis.z.z)
	root_game.motor.turn(-yaw)
	var offset: Vector3=head.global_position-root_game.motor.global_position; offset.y=0
	origin.global_position-=offset
	tracking.corrections.clear(); tracking.native_corrections.clear(); tracking.native_foot_offsets.clear()
	tracking.osc_alignment=Transform3D.IDENTITY; tracking.calibrated=false
	clear_samples()
	root_game.motor.velocity=Vector3.ZERO; root_game.motor.last_motion=Vector3.ZERO
	root_game.peak_speed=0; root_game.casting=false; root_game.reel_tracker.engaged=false
	root_game.tracking_was_valid=false; root_game.gesture_cooldown=.5
	root_game.last_tip=origin.to_local(root_game.tip.global_position)
	message="Recentered · recalibrate body trackers in your new pose"
	return true
func save() -> void:
	var config:=ConfigFile.new(); config.load("user://tracking.cfg")
	config.set_value("pose","seated",seated); config.set_value("pose","expressions",expressions_enabled); config.set_value("pose","body",tracking.enabled)
	config.set_value("pose","tracked_leg_animation",tracked_leg_animation)
	var error:=config.save("user://tracking.cfg")
	if error!=OK:push_warning("Cannot save tracking settings: "+error_string(error))

func head_tracked() -> bool:
	var tracker=XRServer.get_tracker("head") as XRPositionalTracker
	if not tracker or not tracker.has_pose("default"): return false
	var pose=tracker.get_pose("default")
	return pose!=null and pose.has_tracking_data
