extends SceneTree
var game
var failures: Array=[]
var tracker: XRControllerTracker
func _initialize(): run.call_deferred()
func check(ok: bool,label: String):
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func settle():
	for i in range(10): await process_frame
	await RenderingServer.frame_post_draw
func click(control: Control):
	var point: Vector2=control.get_global_rect().get_center()
	var target: Vector3=game.avatar_panel.to_global(Vector3((point.x/1000.0-.5)*1.8,(.5-point.y/720.0)*1.296,0))
	var pose: Transform3D=game.right.global_transform.looking_at(target,Vector3.UP)
	for key in ["grip","aim","default"]:tracker.set_pose(key,game.origin.global_transform.affine_inverse()*pose,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	await settle();game._menu_click(true);await process_frame;game._menu_click(false);await settle()
func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);current_scene=game
	await settle();game._toggle_avatar_menu();await settle()
	var menu=game.avatar_menu
	if game.xr:
		tracker=XRControllerTracker.new();tracker.name="right_hand";XRServer.add_tracker(tracker)
		tracker.set_pose("grip",Transform3D(Basis.IDENTITY,Vector3(.3,1.3,-.4)),Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
		await settle()
	for id in menu.pages:
		if game.xr: await click(menu.pages[id].button)
		else: menu.show_page(id)
		await settle()
		check(menu.active_page==id,"Tab interaction: "+id)
		check(menu.size.x<=900 and menu.position.y+menu.size.y<=720 if game.xr else menu.size.y<=700,"Menu fits viewport: "+id)
		var frame: Image=game.avatar_menu_view.get_texture().get_image() if game.xr else root.get_texture().get_image()
		frame.save_png("res://docs/menu_"+id+("_xr" if game.xr else "")+".png")
	if game.xr:
		await click(menu.pages.together.button)
		var field: LineEdit=menu.multiplayer_page.find_children("*","LineEdit",true,false)[0]
		await click(field)
		check(menu.keyboard.visible,"Tracked ray opens in-panel keyboard")
		await click(menu.keyboard.get_child(0).get_child(0).get_child(0))
		check(field.text.contains("1"),"Tracked ray keyboard enters text")
		XRServer.remove_tracker(tracker)
	game.network.leave();game.queue_free();await process_frame;await process_frame
	print("PRESENTATION_RESULT ",failures);quit(0 if failures.is_empty() else 1)
