extends Node
## Opt-in render-clock pose/input capture. Never records audio or network identities.
## Samples are engine observations, not unique hardware timestamps.
const SEGMENT_BYTES:=32*1024*1024
const MAX_SEGMENTS:=32
const MAX_SECONDS:=3600.0
const BUTTONS:=["trigger_click","grip_click","ax_button","by_button","primary_click","menu_button","trigger_touch","thumbrest_touch"]
var game_root:Node
var directory:=""
var file:FileAccess
var segment:=0
var sequence:=0
var elapsed:=0.0
var flush_elapsed:=0.0
var wired:=false
var enabled:=false

func _ready()->void:
	process_priority=1000
	enabled="--vr-test-capture" in OS.get_cmdline_user_args()
	set_process(enabled)
	if not enabled:return
	directory="user://vr_test_capture/%s-%d"%[Time.get_datetime_string_from_system(true).replace(":","-"),OS.get_process_id()]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--vr-capture-dir="):directory=arg.trim_prefix("--vr-capture-dir=")
	if DirAccess.make_dir_recursive_absolute(directory)!=OK:
		push_error("VR_TEST_CAPTURE: Cannot create "+directory);enabled=false;set_process(false);return
	open_segment()
	print("VR_TEST_CAPTURE ",ProjectSettings.globalize_path(directory))

func open_segment()->void:
	file=FileAccess.open(directory.path_join("controllers-%03d.jsonl"%segment),FileAccess.WRITE)
	if file==null:
		push_error("VR_TEST_CAPTURE: Cannot open controller log");enabled=false;set_process(false);return
	write_event("capture_segment",{"schema":1,"utc":Time.get_datetime_string_from_system(true),"segment":segment,"pid":OS.get_process_id(),"engine":Engine.get_version_info().string,"clock":"engine render polling; monotonic microseconds","units":"metres, radians, seconds; quaternion xyzw","space":"raw/controller_local/head_local in tracking origin; origin/club/ball in world","max_seconds":MAX_SECONDS,"max_bytes":MAX_SEGMENTS*SEGMENT_BYTES})

static func vector(v:Vector3)->Array:return [v.x,v.y,v.z]
static func pose_data(t:Transform3D)->Variant:
	if not t.is_finite() or absf(t.basis.determinant())<.00001:return null
	var q:=t.basis.orthonormalized().get_rotation_quaternion()
	return {"p":vector(t.origin),"q":[q.x,q.y,q.z,q.w]}

func write_event(kind:String,data:Dictionary)->void:
	if file==null:return
	sequence+=1
	file.store_line(JSON.stringify({"type":kind,"seq":sequence,"us":Time.get_ticks_usec(),"data":data}))

func button_event(button:String,pressed:bool,hand:int)->void:
	if enabled:write_event("button",{"hand":hand,"button":button,"pressed":pressed})

func controller_data(controller:XRController3D,hand:int)->Dictionary:
	var row:Dictionary={"hand":hand,"tracked":controller.get_has_tracking_data(),"active":controller.get_is_active(),"local":pose_data(controller.transform)}
	var pose:XRPose=controller.get_pose()
	if pose!=null:
		row.raw=pose_data(pose.transform);row.confidence=pose.tracking_confidence
		row.linear_velocity=vector(pose.linear_velocity);row.angular_velocity=vector(pose.angular_velocity)
	var tracker:=XRServer.get_tracker(controller.tracker) as XRPositionalTracker
	if tracker!=null and tracker.has_pose("aim"):
		var aim:XRPose=tracker.get_pose("aim")
		row.aim={"tracked":aim.has_tracking_data,"pose":pose_data(aim.transform)}
	var stick:=controller.get_vector2("primary")
	row.stick=[stick.x,stick.y];row.trigger=controller.get_float("trigger");row.grip=controller.get_float("grip")
	var pressed:Array=[]
	for button in BUTTONS:
		if controller.is_button_pressed(button):pressed.append(button)
	row.buttons=pressed
	row.calibrated_local=pose_data(game_root.controller_local_pose(hand))
	return row

func _process(delta:float)->void:
	if not enabled or not is_instance_valid(game_root) or not is_instance_valid(game_root.right):return
	elapsed+=delta;flush_elapsed+=delta
	if elapsed>=MAX_SECONDS:stop("time_limit");return
	if not wired:
		for hand in 2:
			var controller:XRController3D=game_root.left if hand==0 else game_root.right
			controller.button_pressed.connect(button_event.bind(true,hand))
			controller.button_released.connect(button_event.bind(false,hand))
		wired=true
	var g=game_root
	var row:Dictionary={"frame":Engine.get_process_frames(),"dt":delta,"xr":g.xr,"world_scale":XRServer.world_scale,"origin":pose_data(g.origin.global_transform),"head_local":pose_data(g.head.transform),"left":controller_data(g.left,0),"right":controller_data(g.right,1),"location":g.current_location,"menu":g.menu_open,"casting":g.casting,"head_aim":g.head_aimed_casting,"fishing_state":g.game.state}
	if is_instance_valid(g.tracking_manager):
		row.focused=g.tracking_manager.focused;row.user_height=g.tracking_manager.user_height
		row.calibrating=g.tracking_manager.calibration_pending
		if g.tracking_manager.body.get("hips") is Transform3D:row.hips_local=pose_data(g.tracking_manager.body.hips)
	if g.casting:
		row.cast={"tip":vector(g._tracked_cast_tip()),"axis":vector(g.cast_swing_axis),"strokes":g.game.fly.strokes,"back_m":g.game.fly.cast_back_travel,"forward_m":g.game.fly.cast_forward_travel,"swing":vector(g.cast_motion.swing_travel),"speed":g.cast_motion.swing_speed}
	if is_instance_valid(g.golf_activity) and g.golf_activity.active and is_instance_valid(g.golf_activity.golf):
		var golf=g.golf_activity.golf
		row.golf={"course":golf.course_id,"hole":golf.round_state.hole,"strokes":golf.round_state.strokes,"club":golf.club_index,"left_handed":golf.left_handed,"fitting":golf.fitting_club,"reach":golf.club_reach,"menu":golf.menu_open,"armed":golf.club_collision_enabled(),"ball":vector(golf.ball.position),"velocity":vector(golf.ball.velocity),"spin":vector(golf.ball.spin),"moving":golf.ball.moving}
		row.golf.grounded=golf.ball.grounded
		row.golf.lie=golf.model.lie(golf.ball.position.x,golf.ball.position.z)
		row.golf.ground_normal=vector(golf.model.normal_at(golf.ball.position.x,golf.ball.position.z))
		row.golf.stop_reason=golf.ball.stop_reason
		row.golf.teed=golf.contact_effects.tee_armed
		row.golf.adjusting_head=golf.fit_session.adjust_head
		if is_instance_valid(golf.physical_head):row.golf.head=pose_data(golf.physical_head.global_transform)
		if is_instance_valid(golf.club):row.golf.shaft=pose_data(golf.club.global_transform)
	write_event("frame",row)
	if flush_elapsed>=1:
		file.flush();flush_elapsed=0
		if file.get_error()!=OK:stop("write_error");return
	if file.get_position()>=SEGMENT_BYTES:
		file.flush();file.close();file=null;segment+=1
		if segment>=MAX_SEGMENTS:stop("size_limit")
		else:open_segment()

func stop(reason:String)->void:
	write_event("capture_stopped",{"reason":reason})
	if file!=null:file.flush();file.close();file=null
	enabled=false;set_process(false)
func _exit_tree()->void:
	stop("application_exit")
