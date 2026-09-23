extends SceneTree
const Photo=preload("res://scripts/guide_camera.gd")
var checks:=0
var failures:Array=[]
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize()->void:run.call_deferred()
func run()->void:
	var host=load("res://scenes/main.tscn").instantiate();root.add_child(host)
	await create_timer(.5).timeout
	host.set_process(false);host.motor.set_physics_process(false)
	var native:=OS.get_cmdline_user_args().has("--native-xr")
	if native and (not host.xr or not is_instance_valid(host.spectator)):
		push_error("Native simulated PC VR did not start");quit(1);return
	var fishing_photo=host.fish_guide.photo_camera
	var mirror=host.spectator
	await host.golf_activity.join_course("spyglass")
	await process_frame
	var golf=host.golf_activity.golf
	golf.set_process(false);golf.set_physics_process(false);host.motor.set_physics_process(false)
	var guide=golf.course_guide
	var photo=guide.photo_camera
	host.tracking_manager.body={"hips":Transform3D(Basis(Vector3.UP,.7),Vector3(0,.95,0))}
	golf.equipment.update();guide.update()
	var belt_before:Transform3D=golf.equipment.belt_pose
	var guide_before:Transform3D=guide.belt_pose
	var head_before:Transform3D=host.head.transform
	host.head.rotation.y+=1.0;host.head.position.z-=.3
	golf.equipment.update();guide.update()
	check(golf.equipment.belt_pose.is_equal_approx(belt_before) and guide.belt_pose.is_equal_approx(guide_before),"Golf club and course guide follow hip tracker instead of head turning or leaning")
	host.head.transform=head_before;host.tracking_manager.body.clear()
	check(is_instance_valid(photo) and photo.get_script()==Photo,"Golf reuses Fishing photo service")
	check(photo.view.world_3d==host.get_world_3d(),"Golf photo shares live course and avatar world")
	guide.toggle()
	check(guide.held,"Guide and camera available at clubhouse")
	golf._left_button("trigger_click");photo.update_pose()
	check(photo.active and guide.page_index==0,"Camera toggles without losing map page")
	check(guide.find_children("*","VisualInstance3D",true,false).all(func(n):return n.layers==Photo.UI_LAYER),"Guide excluded from photos and mirror without recursive screens")
	check(photo.camera.far==host.head.far,"Photo covers full course distance")
	golf._right_button("ax_button")
	check(photo.selfie and photo.camera.cull_mask==5,"Selfie includes complete avatar")
	photo.adjust_selfie(1,.1)
	check(photo.selfie_extension>0,"Selfie extension remains available")
	photo.toggle();golf._left_button("trigger_click")
	check(photo.active,"Guide-hand trigger opens camera")
	photo.selfie=false;golf._right_button("ax_button")
	check(photo.selfie,"Free-hand A toggles selfie")
	golf._left_button("trigger_click");guide.page(1)
	check(not photo.active and guide.page_index==1,"Map and scorecard remain usable after camera")
	guide.dock();golf.left_handed=true;guide.toggle(1)
	golf._right_button("trigger_click")
	check(photo.active,"Left-handed guide uses right trigger")
	photo.selfie=false;golf._left_button("ax_button")
	check(photo.selfie and guide.held_hand==1,"Left-handed photo and extension use free hand")
	golf.left_handed=false
	if native:
		check(root.get_camera_3d()==mirror.camera and host.xr_view.get_camera_3d()==host.head,"Clubhouse keeps third-person window and tracked stereo camera")
		check(not root.use_xr and host.xr_view.use_xr,"Mono mirror remains independent from headset")
		check(mirror.camera.cull_mask==5 and mirror.is_physics_processing(),"Mirror still renders full avatar and follows golfer")
		golf.toggle_menu(true);check(root.get_camera_3d()==mirror.camera,"Golf menu does not replace mirror")
		host.golf_activity.close_settings()
	guide.dock()
	check(photo.view.render_target_update_mode==SubViewport.UPDATE_DISABLED,"Docking stops photo render")
	host.golf_activity.start_play("solo");await process_frame
	golf.set_process(false);golf.set_physics_process(false)
	if native:
		mirror.update_pose(1.0)
		golf.focused=true
		check(golf.godview.enter(),"Godview enters in simulated XR")
		mirror.update_pose(1.0)
		check(not host.avatar.visible,"Godview keeps avatar hidden")
		check(root.get_camera_3d()==mirror.camera and host.xr_view.get_camera_3d()==host.head,"Godview leaves both cameras assigned")
		golf.godview.exit_view()
		check(host.avatar.visible,"Leaving Godview restores avatar")
	guide.toggle();photo.active=true;photo.selfie=false;photo.update_pose()
	if DisplayServer.get_name()!="headless":
		await photo.capture()
		check(FileAccess.file_exists(photo.last_path) and photo.last_path.get_file().begins_with("golf_"),"Actual renderer saves golf PNG through shared photo path")
		if FileAccess.file_exists(photo.last_path):
			var image:=Image.load_from_file(photo.last_path);check(image.get_size()==Vector2i(1920,1080),"Photo preserves Fishing capture resolution")
	else:
		golf._right_button("trigger_click");check(photo.status.contains("renderer") and not golf.ball.moving,"Shutter never starts a golf swing")
	guide.dock();host.golf_activity.leave();await process_frame
	check(host.fish_guide.photo_camera==fishing_photo,"Returning to Fishing retains original camera service")
	if native:check(root.get_camera_3d()==mirror.camera and host.xr_view.get_camera_3d()==host.head,"Returning to Fishing retains mirror and headset cameras")
	host.ambience.stop();host.queue_free();await process_frame;await create_timer(.3).timeout
	print("GOLF_CAMERA_RESULT ",checks-failures.size(),"/",checks," ",failures);quit(1 if not failures.is_empty() else 0)
