extends SceneTree
var failures:Array=[]
var tracker:XRControllerTracker
var g
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func settle():
	for i in 8:await process_frame
func aim(at:Vector3):
	var pose:=Transform3D(g.origin.global_basis.inverse(),g.origin.to_local(at+Vector3(0,0,1)))
	tracker.set_pose("aim",pose,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	# Deliberately different grip: the wall must use runtime aim, not grip -Z.
	pose.basis=g.origin.global_basis.inverse()*Basis(Vector3.UP,PI*.5)
	tracker.set_pose("grip",pose,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	await settle()
func run():
	g=load("res://scenes/main.tscn").instantiate();root.add_child(g);await create_timer(.5).timeout
	g.set_process(false);g.motor.set_physics_process(false)
	g.avatar_panel=MeshInstance3D.new();g.add_child(g.avatar_panel)
	g.menu_pointer=MeshInstance3D.new();g.add_child(g.menu_pointer)
	g.menu_laser=MeshInstance3D.new();g.add_child(g.menu_laser)
	g.avatar_menu_view=SubViewport.new();g.avatar_menu_view.size=Vector2i(1000,720);g.add_child(g.avatar_menu_view)
	g.avatar_menu.reparent(g.avatar_menu_view);g.avatar_menu.position=Vector2(50,30);g.avatar_menu.scale=Vector2.ONE
	tracker=XRControllerTracker.new();tracker.name="golf_input_right";XRServer.add_tracker(tracker)
	g.right.tracker=tracker.name;g.right.pose="grip"
	g.xr=true;g.tracking_manager.focused=true
	await g.golf_activity.join_course("spyglass");await settle()
	var golf=g.golf_activity.golf;golf.set_process(false);golf.set_physics_process(false);g.motor.set_physics_process(false)
	g.golf_activity.open_settings("golf");await settle()
	var tab:Button=g.avatar_menu.pages.controls.button
	var pixel:=tab.get_global_rect().get_center()
	var point:Vector3=g.avatar_panel.to_global(Vector3((pixel.x/1000-.5)*1.8,(.5-pixel.y/720)*1.296,0))
	await aim(point);g._update_menu_pointer()
	check(g.menu_pointer.visible,"Golf settings receives the runtime aim ray")
	tracker.set_input("trigger_click",true);await settle()
	check(g.menu_mouse_down,"Tracked trigger-down reaches shared golf settings")
	tracker.set_input("trigger_click",false);await settle()
	check(g.avatar_menu.pages.controls.page.is_visible_in_tree() and not g.menu_mouse_down,"Tracked trigger release activates the settings tab")
	g.avatar_menu.show_page("golf");await settle()
	var handed:CheckButton=golf.hud.hand_choice
	g.avatar_menu.pages.golf.view.ensure_control_visible(handed);await settle()
	pixel=handed.get_global_rect().get_center()
	point=g.avatar_panel.to_global(Vector3((pixel.x/1000-.5)*1.8,(.5-pixel.y/720)*1.296,0))
	await aim(point);g._update_menu_pointer()
	for frame in 45:
		g._update_menu_pointer();await process_frame
	var previous_hand:bool=golf.left_handed
	tracker.set_input("trigger_click",true);await settle()
	tracker.set_input("trigger_click",false);await settle()
	check(golf.left_handed!=previous_hand,"Tracked menu ray directly toggles handedness without a popup")
	golf.set_hand(false)
	g.golf_activity.close_settings();await settle()
	var board=g.golf_activity.clubhouse_board;board.set_process(false)
	var solo:Button
	for b in board.viewport.find_children("*","Button",true,false):
		if b.text=="Start new solo round":solo=b
	var clicks:Array=[];solo.pressed.connect(func():clicks.append(true))
	pixel=solo.get_global_rect().get_center()
	point=board.to_global(Vector3((pixel.x/960-.5)*3,(.5-pixel.y/640)*2,0))
	await aim(point);board._process(.016)
	check(board.pointer.visible and board.laser.visible,"Wall panel displays cursor with grip facing sideways")
	tracker.set_input("trigger_click",true);board._process(.016);await settle()
	tracker.set_input("trigger_click",false);board._process(.016);await settle()
	check(clicks.size()==1 and g.golf_activity.clubhouse_round==null,"Digital runtime trigger clicks Play solo and starts the round")
	g.golf_activity.arrive_clubhouse();await settle();await aim(point)
	tracker.set_input("trigger",1.0);board._process(.016);await settle()
	tracker.set_input("trigger",0.0);board._process(.016);await settle()
	check(clicks.size()==2,"Analog trigger also activates wall controls")
	g.golf_activity.arrive_clubhouse();await settle();await aim(point)
	g.avatar.right_index_tip=point+Vector3(0,0,.015);g.avatar.right_index_tip_frame=Engine.get_process_frames()
	board._process(.016)
	check(board.down,"Visible fingertip touches the wall control")
	g.avatar.right_index_tip=point+Vector3(0,0,.08);g.avatar.right_index_tip_frame=Engine.get_process_frames()
	board._process(.016);await settle()
	check(clicks.size()==3,"Lifting fingertip activates the touched control")
	# Repeat the wall/menu path with only a left controller connected.
	g.right.tracker="missing_feedback_right";g.left.tracker=tracker.name;g.left.pose="grip"
	g.golf_activity.arrive_clubhouse();await settle();await aim(point);board._process(.016)
	tracker.set_input("trigger_click",true);board._process(.016);await settle()
	tracker.set_input("trigger_click",false);board._process(.016);await settle()
	check(clicks.size()==4,"Sole left controller ray and trigger activate wall controls")
	g.golf_activity.open_settings("golf");await settle()
	pixel=tab.get_global_rect().get_center()
	point=g.avatar_panel.to_global(Vector3((pixel.x/1000-.5)*1.8,(.5-pixel.y/720)*1.296,0))
	await aim(point);g._update_menu_pointer()
	tracker.set_input("trigger_click",true);await settle()
	check(g.menu_mouse_down,"Sole left trigger reaches shared settings")
	tracker.set_input("trigger_click",false);await settle()
	check(not g.menu_mouse_down,"Sole left trigger release reaches shared settings")
	g.golf_activity.close_settings();await settle()
	tracker.set_input("trigger_click",true);board._process(.016)
	g.tracking_manager.focused=false;board._process(.016)
	check(not board.down and not board.pointer.visible,"Focus loss cancels wall input")
	g.tracking_manager.focused=true;g.golf_activity.leave();XRServer.remove_tracker(tracker)
	g.ambience.stop();g.queue_free();await process_frame;await create_timer(.3).timeout
	print("GOLF_VR_INPUT_RESULT ",failures);quit(0 if failures.is_empty() else 1)
