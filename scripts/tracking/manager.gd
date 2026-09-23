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
var user_height := Scale.HEAD_HEIGHT
var height_measured := false
var height_confirmed := false
var height_candidate := 0.0
var height_stable_time := 0.0
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
		user_height=clampf(float(config.get_value("pose","user_eye_height",Scale.HEAD_HEIGHT)),.6,2.3)
		height_measured=config.has_section_key("pose","user_eye_height")
		height_confirmed=bool(config.get_value("pose","height_confirmed",false))
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
	if is_instance_valid(root_game): root_game.motor.tracked_hip = null
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
	_sample_height(delta)
	body=preload("res://scripts/tracking/poses.gd").validate_body(tracking.sample())
	# Store in tracking-origin space so physics can consume the same sample
	# twice without counting its room-scale translation twice.
	root_game.motor.tracked_hip = origin.transform.affine_inverse() * body.hips if body.has("hips") else null
	face=eyes.sample() if expressions_enabled else {}
	var allowed: bool=not seated and _activity_allows_calibration() and left.get_has_tracking_data() and right.get_has_tracking_data() and tracking.enabled
	var detected := t_pose_detector.sample(head.transform,left.position,right.position,delta,allowed)
	if t_pose_detector.held>0 or detected:
		if not tracking.full_body_available():
			calibration_notice="T-pose detected · enable body trackers or SlimeVR OSC"
			t_pose_detector.reset(); t_pose_detector.latched=false
		elif detected:
			# Body calibration must not move the floor or rescale every XR pose.
			# Recenter is an explicit action; a T-pose only aligns body sensors.
			tracking.calibrate(true)
		else: calibration_notice="Hold T-pose · %.1f s" % maxf(0,t_pose_detector.HOLD_SECONDS-t_pose_detector.held)
		calibration_notice_time=2.0 if detected else .25
	root_game.hud.calibration_message=calibration_notice
func calibrate() -> void:
	if not root_game.xr: message="Calibration requires an XR session"; return
	tracking.calibrate()
	message=tracking.status
func recenter() -> bool:
	if not root_game.xr or not focused or not _activity_allows_calibration():
		message="Finish the cast and put away the Guide before recentering"
		return false
	if not head_tracked() or head.position.y<.3: message="Head tracking is unavailable"; return false
	calibration_pending=false
	# Runtime poses stay in real metres. Avatar size follows the measured user,
	# never the reverse; recentering while crouched must not resize either.
	XRServer.world_scale=1.0
	origin.position.y=0
	apply_user_height()
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
	root_game.last_tip=root_game._strike_tip()
	message="Recentered · recalibrate body trackers in your new pose"
	return true
func _sample_height(delta:float) -> void:
	if height_confirmed or seated:return
	var measured:=head.position.y/XRServer.world_scale
	if measured<.6 or measured>2.3:return
	if absf(measured-height_candidate)>.025:
		height_candidate=measured;height_stable_time=0;return
	height_stable_time+=minf(delta,.05)
	if height_stable_time<1.0:return
	# The first stable pose supplies a provisional height. A later standing
	# pose can raise it; crouching and sitting never shrink a measured body.
	if not height_measured or height_candidate>user_height+.025:
		user_height=height_candidate;height_measured=true;apply_user_height();save()

func measure_height() -> void:
	if not root_game.xr or not focused or not head_tracked() or not _activity_allows_calibration():
		message="Stand straight with tracking active before measuring height";return
	user_height=clampf(head.position.y/XRServer.world_scale,.6,2.3)
	height_measured=true;height_confirmed=true;apply_user_height();save()
	message="Standing eye height measured: %.2f m"%user_height

func apply_user_height() -> void:
	if is_instance_valid(root_game.get("avatar")):root_game.avatar.set_user_height(user_height)

func save() -> void:
	var config:=ConfigFile.new(); config.load("user://tracking.cfg")
	config.set_value("pose","seated",seated); config.set_value("pose","expressions",expressions_enabled); config.set_value("pose","body",tracking.enabled)
	config.set_value("pose","tracked_leg_animation",tracked_leg_animation)
	if height_measured:config.set_value("pose","user_eye_height",user_height)
	config.set_value("pose","height_confirmed",height_confirmed)
	var error:=config.save("user://tracking.cfg")
	if error!=OK:push_warning("Cannot save tracking settings: "+error_string(error))

func head_tracked() -> bool:
	var tracker=XRServer.get_tracker("head") as XRPositionalTracker
	if not tracker or not tracker.has_pose("default"): return false
	var pose=tracker.get_pose("default")
	return pose!=null and pose.has_tracking_data

func _activity_allows_calibration() -> bool:
	if is_instance_valid(root_game.golf_activity) and root_game.golf_activity.active:
		return root_game.golf_activity.allows_calibration()
	return root_game.game.state==0 and not root_game.casting and not root_game.fish_guide.held
