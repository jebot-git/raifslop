extends SceneTree
var effect=preload("res://tests/xr_capture.gd").new()
var failures:Array=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func capture(g,label:String):
	for i in 20:
		g._update_avatar(.014)
		await process_frame
	effect.request_capture(label)
	for i in 180:
		await process_frame
		if effect.completed==label:break
	check(effect.completed==label and effect.views==2,"Live stereo capture: "+label)
	for eye in effect.results.size():
		var frame:Image=effect.results[eye];frame.convert(Image.FORMAT_RGBA8);frame.linear_to_srgb()
		frame.save_png("res://test-results/vr-fixes/feedback-"+label+"-eye%d.png"%eye)
func run():
	var g=load("res://scenes/main.tscn").instantiate();root.add_child(g);current_scene=g
	await create_timer(3).timeout
	check(g.xr,"WiVRn OpenXR initialized")
	if not g.xr:quit(1);return
	for i in 4:
		await create_timer(2).timeout
		print("FEEDBACK_LIVE ",JSON.stringify({"fps":Engine.get_frames_per_second(),"focused":g.tracking_manager.focused,"head":g.tracking_manager.head_tracked(),"left":g.left.get_has_tracking_data(),"right":g.right.get_has_tracking_data()}))
	g.set_process(false);g.motor.set_physics_process(false);g.fishing_feedback.set_process(false)
	g.fish_guide.dock();g.menu_open=false;g.avatar_panel.hide();g.hud.tracking_lost=false;g.hud.calibration_message="";g.game.reset();g.hud.queue_redraw()
	var compositor=Compositor.new();compositor.compositor_effects=[effect];g.head.compositor=compositor
	g._toggle_avatar_menu();g.avatar_menu.leaderboard_button.pressed.emit()
	await capture(g,"leaderboard-menu")
	check(g.avatar_menu.active_page=="leaderboard","Leaderboard lives inside the menu")
	g._toggle_avatar_menu()
	g.game.state=g.Session.State.BITE;g.game.message="BITE! Lift the rod to set the hook.";g.hud.queue_redraw()
	g.fishing_feedback._process(.014)
	await create_timer(.4).timeout
	g.game.strike();g.fishing_feedback._process(.014)
	g.game.cue=0;g.game.resistance=.62;g.game.counter_active=true;g.game.tension=.55;g.game.message="Hold the rod against the fish's pull.";g.hud.queue_redraw();g.fishing_feedback._process(.014)
	await capture(g,"fight")
	g.game.tension=.88;g.fishing_feedback._process(1)
	g.fish_guide.held=true;g.fish_guide.selected=-1;g.fish_guide.screen.queue_redraw()
	g.fish_guide.global_transform=g.head.global_transform*Transform3D(Basis.IDENTITY,Vector3(0,-.02,-.43))
	await capture(g,"guide")
	g.fish_guide.held=false;g.fish_guide.hide();g._toggle_avatar_menu()
	await capture(g,"quit-menu")
	g.head.compositor=null;g.queue_free();await process_frame;await create_timer(.3).timeout
	print("FEEDBACK_LIVE_RESULT ",failures);quit(0 if failures.is_empty() else 1)
