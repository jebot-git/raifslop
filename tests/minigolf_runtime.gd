extends SceneTree
var failures:Array=[]
func check(ok:bool,message:String)->void:
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures.append(message)
func _initialize()->void:run.call_deferred()
func run()->void:
	var host=load("res://scenes/main.tscn").instantiate();root.add_child(host)
	await create_timer(.5).timeout
	host.set_process(false);host.motor.set_physics_process(false)
	var activity=host.golf_activity
	activity.set_process(false)
	check(host.avatar_menu.pages.has("minigolf") and not host.avatar_menu.pages.has("golf"),"Minigolf replaces full-golf menu")
	var water:String=host.current_location
	var before:Vector3=host.motor.global_position
	activity.enter(water)
	await process_frame
	check(activity.active and activity.world.course.id==water,"Opens current-water course")
	check(host.current_location==water,"Minigolf retains shared location identity")
	check(activity.world.get_child_count()>18,"All 18 connected holes are present")
	check(activity.physical_head!=null,"Retained putter has independent physical face")
	activity.update_player(.011)
	activity.guide.toggle();activity.guide.update();activity.guide.page(2)
	check(activity.guide.held and activity.guide.page_index==2,"Guide supports participant score page")
	activity.guide.controller_button("trigger_click",host.left)
	check(activity.guide.photo_camera.active,"Existing guide camera is retained")
	activity.guide.controller_button("ax_button",host.right)
	check(activity.guide.photo_camera.selfie,"Existing selfie controls are retained")
	check(activity.guide.awaiting_grip,"Menu-opened guide waits for first grip before release docking")
	activity.guide.dock()
	check(not activity.guide.awaiting_grip,"Dock clears menu grip latch")
	var fit_position:Vector3=host.motor.global_position
	activity.begin_club_fit();check(activity.fitting.active,"Fit capture remains available")
	check(host.motor.global_position.is_equal_approx(fit_position),"Fitting never automatically positions player")
	activity.cancel_club_fit();check(not activity.fitting.active,"Fit cancellation disarms and restores")
	activity.ball.position=Vector2(activity.ball.layout.cup[0],activity.ball.layout.cup[1]+.16)
	activity.request_putt(Vector2(0,-.3))
	for i in 200:
		activity._physics_process(1.0/90)
		if not activity.ball.moving:break
	check(activity.scores==[1],"Completed putt records exactly one stroke")
	var stance:Vector3=host.motor.global_position
	activity.update_player(1.1)
	check(activity.hole==1 and activity.strokes==0,"Round advances to next hole")
	check(host.motor.global_position.is_equal_approx(stance),"Hole advance leaves player in place")
	activity.teleport_to_ball()
	check(host.motor.global_position.distance_to(activity.ball_position())<1,"Optional teleport to ball remains available")
	check(activity.world.has_node("ShoreShuttle")==activity.Catalog.needs_boat(water),"Only offshore courses have a moored boat")
	activity.save_round()
	activity.scores=[];activity.load_hole(0);activity.restore_round()
	check(activity.hole==1 and activity.scores==[1],"Current layout card resumes")
	var cfg:=ConfigFile.new();var save_path:="user://minigolf_%s.cfg"%water
	cfg.load(save_path);cfg.set_value("round","layout_version",1);cfg.save(save_path)
	activity.scores=[];activity.load_hole(0);activity.restore_round()
	check(activity.hole==0 and activity.scores.is_empty(),"Retired layout cannot resume a lie inside new obstacles")
	activity.toggle_menu(true);activity.update_player(.011);activity.toggle_menu(false)
	activity.leave();await process_frame
	check(not activity.active and host.current_location==water and host.motor.global_position.distance_to(before)<.1,"Returns to fishing at original pose")
	check(is_instance_valid(activity.world),"Course stays visible to anglers and BBQ players")
	host.ambience.stop();host.queue_free();await process_frame;await create_timer(.3).timeout
	print("MINIGOLF RUNTIME failures: ",failures);quit(0 if failures.is_empty() else 1)
