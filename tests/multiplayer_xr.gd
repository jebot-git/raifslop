extends SceneTree
var game
var failures: Array=[]
var controllers: Array[XRControllerTracker]=[]
var extra_trackers: Array[XRTracker]=[]
var capture_effect=preload("res://tests/xr_capture.gd").new()
func _initialize() -> void: run.call_deferred()
func check(ok: bool, title: String) -> void:
	print("PASS " if ok else "FAIL ",title)
	if not ok: failures.append(title)
func wait_for(condition: Callable, seconds: float=15) -> bool:
	var end:=Time.get_ticks_msec()+seconds*1000
	while Time.get_ticks_msec()<end:
		if condition.call(): return true
		await create_timer(.03).timeout
	return false
func run() -> void:
	var xr_role: bool="xr" in OS.get_cmdline_user_args()
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game); current_scene=game
	await create_timer(1).timeout
	game.set_process(false); game.motor.set_physics_process(false)
	game.hud.hide()
	game._select_location("lakeside",false)
	game.motor.global_position=Vector3.ZERO if xr_role else Vector3(-1.2,0,-2.4)
	if xr_role:
		check(game.xr and game.head.get_viewport().use_xr,"Native OpenXR stereo session")
		if not game.xr: quit(1); return
		for hand in ["left_hand","right_hand"]:
			var tracker:=XRControllerTracker.new(); tracker.type=XRServer.TRACKER_CONTROLLER; tracker.name=hand; tracker.description="Synthetic multiplayer controller"
			XRServer.add_tracker(tracker); controllers.append(tracker)
		for i in range(2):
			var pose:=Transform3D(Basis.IDENTITY,Vector3(-.3 if i==0 else .3,1.35,-.45))
			for key in ["grip","aim","default"]: controllers[i].set_pose(key,pose,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
		controllers[0].set_input("grip",.3); controllers[0].set_input("trigger",.7)
		var body_tracker:=XRBodyTracker.new(); body_tracker.name="/user/body_tracker";body_tracker.has_tracking_data=true
		var body_basis=preload("res://scripts/tracking/body_basis.gd")
		body_basis.native_to_facing("hips",Basis.IDENTITY)
		for entry in [["hips",XRBodyTracker.JOINT_HIPS,Vector3(0,.92,0)],["left_foot",XRBodyTracker.JOINT_LEFT_FOOT,Vector3(-.13,.08,0)],["right_foot",XRBodyTracker.JOINT_RIGHT_FOOT,Vector3(.13,.08,0)]]:
			body_tracker.set_joint_flags(entry[1],XRBodyTracker.JOINT_FLAG_POSITION_VALID|XRBodyTracker.JOINT_FLAG_ORIENTATION_VALID)
			body_tracker.set_joint_transform(entry[1],Transform3D(Basis(Vector3.UP,PI)*body_basis.native_rest[body_basis.BONES[entry[0]]],entry[2]))
		XRServer.add_tracker(body_tracker);extra_trackers.append(body_tracker)
		var face_tracker:=XRFaceTracker.new();face_tracker.name="/user/face_tracker"
		face_tracker.set_blend_shape(XRFaceTracker.FT_JAW_OPEN,.4);face_tracker.set_blend_shape(XRFaceTracker.FT_EYE_CLOSED_LEFT,.3)
		XRServer.add_tracker(face_tracker);extra_trackers.append(face_tracker)
		game.tracking_manager.tracking.calibrate()
		await process_frame
		game.tracking_manager.sample(.016);game._update_avatar(.016)
		var compositor:=Compositor.new(); compositor.compositor_effects=[capture_effect]; game.head.compositor=compositor
		game.network.display_name="XR angler"; game.network.host(28570)
	else:
		game.head.rotation.y=PI
		game.desktop_left.position=Vector3(-.25,1.3,.3)
		game.network.display_name="Desktop angler"; game.network.join("127.0.0.1",28570)
	check(await wait_for(func(): return game.network.players.size()==2),"XR and desktop connected")
	game.game.state=game.Session.State.LANDED; game.game.fish_index=6
	game.game.journal.append({"length":63.0}); game._show_fish()
	if xr_role: game._update_catch(0)
	else: game.fish_display.transform=Transform3D(Basis(Vector3.FORWARD,-PI/2),Vector3(-.8,1.25,-2.6))
	check(await wait_for(func():
		for id in game.network.fighters:
			if game.network.states.has(id) and game.network.states[id].caught and not game.network.fighters[id].avatar_hash.is_empty(): return true
		return false),"Remote avatar and hanging fish loaded")
	await create_timer(2).timeout
	var peer: int=game.network.fighters.keys()[0] if not game.network.fighters.is_empty() else 0
	if peer and not xr_role:
		var state: Dictionary=game.network.states[peer]
		check(state.body.has("hips") and state.body.has("left_foot"),"Native full body sample replicated")
		check(state.body.get("left_curls",PackedFloat32Array()).size()==5 and state.body.left_curls[1]>.6,"Native controller finger curls replicated")
		check(state.face.has("mouth") and state.face.mouth[0]>.3,"Native face and mouth sample replicated")
		check(state.xr and state.left_valid and state.right_valid,"Both native XR controller poses replicated")
		check(state.left.origin.distance_to(state.right.origin)>.5,"Tracked hands remain distinct")
		check(state.fish.basis.x.dot(Vector3.UP)>.99,"Remote caught fish remains vertically head-up")
	if xr_role:
		capture_effect.request_capture("multiplayer")
		check(await wait_for(func(): return capture_effect.completed=="multiplayer",5),"Captured native multiplayer stereo render")
		check(capture_effect.results.size()==2,"Both eye buffers returned")
		for eye in range(capture_effect.results.size()):
			var frame: Image=capture_effect.results[eye]
			frame.convert(Image.FORMAT_RGBA8); frame.linear_to_srgb()
			frame.save_png("res://docs/multiplayer_eye%d.png" % eye)
		game.game.bait=5
	else:
		await wait_for(func(): return game.network.states.get(1,{}).get("bait",0)==5,25)
		game.head.rotation.y=0
		game.head.global_position=Vector3(1.8,1.7,1.5)
		game.head.look_at(Vector3(0,1.2,-.3))
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/multiplayer_desktop.png")
	await create_timer(2).timeout
	print("MULTIPLAYER_XR_RESULT ","xr" if xr_role else "desktop"," ",failures)
	game.network.leave()
	for tracker in controllers: XRServer.remove_tracker(tracker)
	for tracker in extra_trackers: XRServer.remove_tracker(tracker)
	game.queue_free(); await process_frame; await process_frame
	quit(0 if failures.is_empty() else 1)
