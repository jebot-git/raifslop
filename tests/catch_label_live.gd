extends SceneTree
var effect=preload("res://tests/xr_capture.gd").new()
func _initialize():run.call_deferred()
func run():
	var g=load("res://scenes/main.tscn").instantiate();root.add_child(g)
	await create_timer(2).timeout
	if not g.xr:push_error("OpenXR unavailable");quit(1);return
	g.set_process(false);g.motor.set_physics_process(false);g.fishing_feedback.set_process(false)
	var hand:=XRControllerTracker.new();hand.name="catch_label_left";XRServer.add_tracker(hand)
	g.left.tracker=hand.name;g.left.pose="grip";hand.set_input("grip",1.0)
	g.game.state=g.Session.State.LANDED;g.game.fish_index=0;g.game.journal=[g.game.SPECIES[0].duplicate()];g._show_fish()
	var compositor:=Compositor.new();compositor.compositor_effects=[effect];g.head.compositor=compositor
	for i in 180:
		var at:Vector3=g.head.global_position-g.head.global_basis.z*.85-g.head.global_basis.x*.12+Vector3.UP*.05
		hand.set_pose("grip",g.origin.global_transform.affine_inverse()*Transform3D(Basis.IDENTITY,at),Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
		g.tracking_manager.sample(.014);g._update_catch(0);g._update_avatar(.014);g._update_line()
		await process_frame
	g.avatar.hide() # Keep this visual check focused on the catch and label.
	g.catch_label._process(0)
	if not g.catch_label.visible or g.hud.visible or g.hud.get_parent()!=g:push_error("Held label or hidden HUD failed");quit(1);return
	effect.request_capture("held_label")
	for i in 120:
		await process_frame
		if effect.completed=="held_label":break
	if effect.views!=2 or effect.completed!="held_label":push_error("Stereo capture failed");quit(1);return
	for eye in 2:
		var frame:Image=effect.results[eye];frame.convert(Image.FORMAT_RGBA8);frame.linear_to_srgb();frame.save_png("res://test-results/vr-fixes/held-label-eye%d.png"%eye)
	print("CATCH_LABEL_LIVE ",JSON.stringify({"label":g.catch_label.text,"position":str(g.catch_label.global_position),"fps":Engine.get_frames_per_second(),"fish_bounds":str(g.catch_bounds),"fish_transform":str(g.fish_display.global_transform),"status_panel_absent":g.hud.get_parent()==g and not g.hud.visible}))
	hand.set_input("grip",0.0);g._update_catch(0);g.catch_label._process(0)
	if g.catch_label.visible:push_error("Released label remained visible");quit(1);return
	g.head.compositor=null;XRServer.remove_tracker(hand);g.queue_free();await process_frame;await create_timer(.3).timeout
	print("CATCH_LABEL_LIVE_RESULT PASS");quit()
