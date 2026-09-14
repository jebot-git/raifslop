extends SceneTree
var failures:Array[String]=[]
var g
var controller:XRControllerTracker
var effect=preload("res://tests/xr_capture.gd").new()
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func settle():
	for i in 45:await process_frame
func click(control:Control):
	var point:=control.get_global_rect().get_center()
	var target:Vector3=g.avatar_panel.to_global(Vector3((point.x/1000.0-.5)*1.8,(.5-point.y/720.0)*1.296,0))
	var position:Vector3=g.right.global_position
	var pose:=Transform3D(Basis.IDENTITY,position).looking_at(target,Vector3.UP)
	controller.set_pose("aim",g.origin.global_transform.affine_inverse()*pose,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	await settle()
	check(g.menu_last_position.distance_to(point)<4,"Laser reaches "+control.name)
	var before:Vector2=g._pointer_position()
	controller.set_input("trigger",1.0);controller.set_input("trigger_click",true)
	for i in 8:await process_frame
	check(g._pointer_position().distance_to(before)<1,"Trigger curl preserves aim")
	controller.set_input("trigger_click",false);controller.set_input("trigger",0.0)
	await settle()
func capture(label:String):
	effect.request_capture(label)
	for i in 120:
		await process_frame
		if effect.completed==label:break
	check(effect.completed==label and effect.results.size()==2,"Stereo "+label)
	DirAccess.make_dir_recursive_absolute("res://test-results/menu-input-xr")
	for eye in effect.results.size():
		var frame:Image=effect.results[eye];frame.convert(Image.FORMAT_RGBA8);frame.linear_to_srgb();frame.save_png("res://test-results/menu-input-xr/%s-eye%d.png"%[label,eye])
func run():
	g=load("res://scenes/main.tscn").instantiate();root.add_child(g);await settle()
	if not g.xr:push_error("OpenXR unavailable");quit(1);return
	g.fishing_feedback.set_process(false)
	controller=XRControllerTracker.new();controller.name="/menu_test_right";controller.hand=XRPositionalTracker.TRACKER_HAND_RIGHT;XRServer.add_tracker(controller)
	var position:Vector3=g.head.position+Vector3(.2,-.35,-.35)
	for name in ["grip","aim","default"]:controller.set_pose(name,Transform3D(Basis.IDENTITY,position),Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	controller.set_input("primary",Vector2.ZERO);controller.set_input("trigger",0.0);controller.set_input("trigger_click",false)
	g.right.tracker=controller.name;g.right.pose="grip"
	var compositor:=Compositor.new();compositor.compositor_effects=[effect];g.head.compositor=compositor
	g._toggle_avatar_menu();await settle()
	await click(g.avatar_menu.import_button)
	check(g.avatar_menu.vrm_browser.visible and not g.avatar_menu.picker.visible,"Laser opens headset VRM browser")
	await capture("vrm-browser")
	g.avatar_menu.close_overlays()
	await click(g.avatar_menu.pages.together.button)
	var field:LineEdit=g.avatar_menu.multiplayer_page.find_children("*","LineEdit",true,false)[0];field.text=""
	await click(field)
	check(g.avatar_menu.keyboard.visible,"Laser focus opens keyboard")
	var scroll:int=g.avatar_menu.pages.together.view.scroll_vertical
	for letter in ["v","r"]:
		for b in g.avatar_menu.keyboard.find_children("*","Button",true,false):
			if b.text==letter:await click(b);break
	check(field.text=="vr" and g.avatar_menu.pages.together.view.scroll_vertical==scroll,"Laser types text without moving underlying page")
	for b in g.avatar_menu.keyboard.find_children("*","Button",true,false):
		check(Rect2(Vector2.ZERO,Vector2(g.avatar_menu_view.size)).encloses(b.get_global_rect()),"Keyboard key fits VR surface: "+b.text)
	await capture("keyboard")
	for b in g.avatar_menu.keyboard.find_children("*","Button",true,false):
		if b.text=="Done":await click(b);break
	check(not g.avatar_menu.keyboard.visible,"Laser dismisses keyboard using visible Done key")
	print("MENU_CONTROLS_XR_RESULT ",failures," FPS=",Engine.get_frames_per_second())
	g.head.compositor=null;XRServer.remove_tracker(controller);g.queue_free();await process_frame;await create_timer(.3).timeout;quit(0 if failures.is_empty() else 1)
