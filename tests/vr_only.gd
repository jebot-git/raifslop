extends SceneTree
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func keys()->void:
	for code in [KEY_W,KEY_A,KEY_S,KEY_D,KEY_Q,KEY_E,KEY_SPACE,KEY_TAB,KEY_V,KEY_G,KEY_J,KEY_H,KEY_C,KEY_F,KEY_T,KEY_R,KEY_N,KEY_P,KEY_B,KEY_1,KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_ESCAPE]:
		var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=true
		Input.parse_input_event(event);Input.flush_buffered_events()
		event=event.duplicate();event.pressed=false;Input.parse_input_event(event);Input.flush_buffered_events()
	for button in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT,MOUSE_BUTTON_MIDDLE]:
		var event:=InputEventMouseButton.new();event.button_index=button;event.pressed=true;Input.parse_input_event(event)
		var motion:=InputEventMouseMotion.new();motion.relative=Vector2(150,100);Input.parse_input_event(motion)
		event=event.duplicate();event.pressed=false;Input.parse_input_event(event)
	Input.flush_buffered_events()
func run()->void:
	var host=load("res://scenes/main.tscn").instantiate();root.add_child(host)
	await create_timer(.4).timeout
	host.set_process(false);host.motor.set_physics_process(false)
	check(host.head is XRCamera3D,"Test fixture uses XR camera, never a desktop fallback")
	check(host.avatar_menu.get_viewport()==host.avatar_menu_view,"Menu exists only in the spatial viewport")
	check(host.avatar_menu.find_children("*","FileDialog",true,false).is_empty(),"Avatar import has no native file picker")
	check(not host.has_method("_unhandled_input") and not host.bbq.has_method("handle_input"),"Fishing and BBQ have no desktop gameplay handlers")
	var pose:Transform3D=host.head.transform
	var bait:int=host.game.bait
	keys();await process_frame
	check(not host.menu_open and not host.fish_guide.held and not host.casting and host.game.bait==bait and host.head.transform==pose and not host.network.voice.radio_active,"Keyboard/mouse cannot control fishing, menus, guide, camera or radio")
	var before:Vector3=host.motor.global_position
	host.motor.blocked=false;host.motor.tracking_focused=true
	var walk:=InputEventKey.new();walk.physical_keycode=KEY_W;walk.pressed=true;Input.parse_input_event(walk);Input.flush_buffered_events()
	host.motor._physics_process(.1)
	walk=walk.duplicate();walk.pressed=false;Input.parse_input_event(walk);Input.flush_buffered_events()
	check(host.motor.global_position==before and host.motor.velocity==Vector3.ZERO,"Missing controller tracking cannot fall back to keyboard locomotion")
	host.avatar_menu._open_import()
	check(host.avatar_menu.vrm_browser.visible,"Avatar import opens the in-world browser")
	host.avatar_menu.close_overlays()
	await host.golf_activity.join_course("spyglass")
	var golf=host.golf_activity.golf;golf.set_process(false);golf.set_physics_process(false)
	check(not golf.has_method("_input") and not golf.course_guide.has_method("camera_key"),"Golf has no keyboard swing, club, Godview or camera handlers")
	var club:int=golf.club_index;var hole:int=golf.round_state.hole
	pose=host.head.transform
	keys();await process_frame
	check(golf.club_index==club and golf.round_state.hole==hole and not golf.ball.moving and not golf.course_guide.held and not golf.godview.active and host.head.transform==pose,"Keyboard/mouse cannot alter golf play or viewpoint")
	check(golf.ui_viewport!=null and golf.hud.get_viewport()==golf.ui_viewport,"Golf keeps only its spatial menu")
	# Controller-routed shutter remains available without binding a keyboard key.
	golf.course_guide.toggle();golf._left_button("trigger_click")
	check(golf.course_guide.photo_camera.active,"Controller trigger still opens golf camera")
	golf._right_button("ax_button")
	check(golf.course_guide.photo_camera.selfie,"Controller button still selects selfie lens")
	golf.course_guide.dock();host.golf_activity.leave();host.ambience.stop();host.queue_free()
	await process_frame;await create_timer(.2).timeout
	print("VR_ONLY_RESULT ",failures);quit(0 if failures.is_empty() else 1)
