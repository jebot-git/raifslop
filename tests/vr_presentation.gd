extends SceneTree
var failures:Array=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func run():
	var g=load("res://scenes/main.tscn").instantiate();root.add_child(g)
	await create_timer(.3).timeout;g.set_process(false);g.motor.set_physics_process(false)
	var seats:=0
	for id in g.Shore.catalog():
		g.game.reset();g._select_location(id,false);await physics_frame;await physics_frame
		for proxy in g.Shore.catalog()[id].colliders:
			if proxy.role!="seat":continue
			seats+=1
			var query:=PhysicsPointQueryParameters3D.new();query.position=g.Shore.vector(proxy.position);query.collision_mask=1
			check(g.get_world_3d().direct_space_state.intersect_point(query).is_empty(),"Seat does not obstruct player: "+id+str(proxy.position))
		check(g.foreground.get_children().any(func(n):return n is StaticBody3D and n.get_meta("role","")=="floor"),"Walkable floor remains: "+id)
	check(seats==7,"All five benches and both boat seats covered")
	g._toggle_avatar_menu();g.avatar_menu.show_locations();g.game.state=g.Session.State.FIGHT
	g.avatar_menu.location_selected.emit("lakeside")
	check(g.menu_open and g.current_location=="bell_park_pier","Rejected travel leaves menu and location intact")
	g.game.reset();g.avatar_menu.location_selected.emit("lakeside")
	check(not g.menu_open and not g.motor.blocked and not g.avatar_menu.visible,"Successful travel closes menu and resumes movement")
	# Build the actual VR UI branch without a headset: no HUD SubViewport or panel.
	g.hud.queue_free();g.catch_label.queue_free();await process_frame
	g.xr=true;g._build_ui()
	check(not g.hud.visible and g.hud.get_parent()==g,"VR status HUD has no render viewport or visible surface")
	var tracker:=XRControllerTracker.new();tracker.name="held_catch_left";XRServer.add_tracker(tracker)
	g.left.tracker=tracker.name;g.left.pose="grip"
	tracker.set_pose("grip",Transform3D(Basis.IDENTITY,Vector3(-.3,1.2,-.5)),Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	tracker.set_input("grip",1.0)
	for i in 5:await process_frame
	g.tracking_manager.focused=true;g.game.state=g.Session.State.LANDED;g.game.fish_index=0
	g.game.journal=[{"name":"European perch","length":42.3,"weight":1.25}]
	g._show_fish();g._update_catch(0);g.catch_label._process(0)
	check(g.catch_label.visible and g.catch_label.text=="European perch\n42 cm · 1.25 kg","Held fish label uses recorded name and actual catch size")
	var bounds:AABB=g.fish_display.global_transform*g.catch_bounds
	check(g.catch_label.global_position.y>bounds.end.y+.1,"Text sits above the fish bounds")
	tracker.set_input("grip",0.0);g._update_catch(0);g.catch_label._process(0)
	check(not g.catch_label.visible,"Rod-hanging fish has no label")
	tracker.set_input("grip",1.0);g._update_catch(0);g.menu_open=true;g.catch_label._process(0)
	check(not g.catch_label.visible,"Menu is not covered by catch text")
	g.menu_open=false;g.game.reset();g.fish_display.hide();g.catch_label._process(0)
	check(not g.catch_label.visible,"Released catch clears the label")
	XRServer.remove_tracker(tracker);g.queue_free();await process_frame;await create_timer(.3).timeout
	print("VR_PRESENTATION_RESULT ",failures);quit(0 if failures.is_empty() else 1)
