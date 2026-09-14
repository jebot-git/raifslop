extends SceneTree
const S = preload("res://scripts/fishing_session.gd")
var failures: Array = []
func _initialize():run.call_deferred()
func check(ok: bool, label: String):
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func fight():
	var s=S.new();s.state=S.State.BITE;s.strike();s.distance=24;return s
func run():
	for rod in range(4):
		var s=fight();s.tackle.equipped=rod
		for miss in range(3):
			s.cue=0;s.cue_time=.01;s.tension=.4
			s.tick(.02,.5,0)
			check(s.failed_counters==miss+1 and s.state==(S.State.LOST if miss==2 else S.State.FIGHT),"Three missed counters lose fish with rod %d, miss %d" % [rod,miss+1])
		check(s.journal.is_empty() and s.tackle.shekels==0 and s.cue==-1,"Escape cannot pay a catch or leave an active cue")
		s.reset();s.state=S.State.BITE;s.strike()
		check(s.failed_counters==0 and s.danger_time==0,"Next fish starts with clean failure state")
	for high in [false,true]:
		var s=fight();s.next_cue=100;s.tension=.95 if high else .05
		for i in range(200):
			s.tick(.02,2.0 if high else 0.0,0)
			if s.state!=S.State.FIGHT:break
		check(s.state==S.State.LOST,"Sustained dangerous tension loses fish: "+str(high))
		s=fight();s.next_cue=100;s.tension=.95 if high else .05
		for i in range(20):s.tick(.02,2.0 if high else 0.0,0)
		s.tension=.4;s.tick(.02,.65,0)
		check(s.state==S.State.FIGHT and s.danger_time==0,"Brief tension excursion is recoverable: "+str(high))
	var legacy:=ConfigFile.new();legacy.set_value("hud","tutorial",true);legacy.save("user://interface.cfg")
	var g=load("res://scenes/main.tscn").instantiate();root.add_child(g);current_scene=g
	await create_timer(.3).timeout
	g.set_process(false);g.motor.set_physics_process(false)
	check(g.avatar_menu.active_page!="help" and not g.menu_open,"Even legacy tutorial preference cannot open instructions at startup")
	for entry in g.Locations.CATALOG:
		g.game.reset();g._select_location(entry.id,false)
		await physics_frame;await physics_frame
		g._cast(24)
		var threshold:float=g.game.landing_distance
		print("LANDING ",entry.id," ",threshold)
		check(g.game.state==S.State.CASTING and threshold>3 and threshold<20,"Landing threshold accounts for foreground: "+entry.id)
		g.game.state=S.State.BITE;g.game.strike();g.game.distance=threshold;g.game.stamina=.8;g.game.next_cue=100
		g.game.tick(.05,1,0);g._update_line()
		check(g.game.state==S.State.FIGHT and g.game.distance>=threshold,"Untired fish stays outside the foreground: "+entry.id)
		var ray:=PhysicsRayQueryParameters3D.create(g.head.global_position,g.bobber.global_position,1)
		check(g.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"Float remains visible at retrieval limit: "+entry.id)
		g.game.stamina=.2;g.game.tick(.05,1,0)
		check(g.game.state==S.State.LANDED,"Tired fish lands before float reaches pier: "+entry.id)
		g.game.reset();g._cast(5)
		if threshold>4.5:check(g.game.state==S.State.READY,"Cast behind landing limit is rejected: "+entry.id)
	g.game.reset();g._toggle_avatar_menu();g.avatar_menu.show_locations()
	for i in 8:g._layout_avatar_menu();await process_frame
	var menu=g.avatar_menu
	var view:ScrollContainer=menu.pages.waters.view
	check(view.scroll_vertical==0 and menu.get_global_rect().encloses(menu.visit_button.get_global_rect()) and menu.visit_button.get_global_rect().position.y >= view.get_global_rect().end.y,"Fish here is fully visible without scrolling")
	menu.scroll_page(10000)
	for i in 4:await process_frame
	check(menu.get_global_rect().encloses(menu.visit_button.get_global_rect()),"Fish here remains available after scrolling")
	menu.tutorial_button.pressed.emit()
	for i in 8:await process_frame
	check(menu.active_page=="help" and menu.get_global_rect().encloses(menu.tutorial_button.get_global_rect()),"Fixed tutorial button opens menu instructions")
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://test-results/vr-fixes/tutorial-menu.png")
		menu.show_locations()
		for i in 8:await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://test-results/vr-fixes/waters-action.png")
	g.game.state=S.State.FIGHT;g.game.cue=0;g.game.lose("The fish broke free.");g._update_line()
	check(not g.bobber.visible and g.line_mesh.get_surface_count()==0,"Lost fish removes float and attached line")
	g.queue_free();await process_frame;await create_timer(.3).timeout
	print("PIER_GAMEPLAY_RESULT ",failures);quit(0 if failures.is_empty() else 1)
