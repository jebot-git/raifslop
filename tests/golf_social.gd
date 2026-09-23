extends SceneTree
var checks:=0
var failures:=0
func _initialize()->void:run.call_deferred()
func check(ok:bool,message:String)->void:
	checks+=1
	if ok:print("PASS ",message)
	else:failures+=1;push_error(message)
func run()->void:
	var g=load("res://scenes/main.tscn").instantiate();root.add_child(g);await process_frame
	g.set_process(false);g.motor.set_physics_process(false)
	var a=g.golf_activity
	var original:String=g.current_location
	var identities:=[g.network.get_instance_id(),g.avatar.get_instance_id(),g.shoulder_radio.get_instance_id()]
	check(g.network.host(28974,"127.0.0.1")==OK,"Shared server starts")
	await a.join_course("spyglass");g.motor.set_physics_process(false);await process_frame
	check(a.active and g.current_location=="golf_spyglass_clubhouse","Course selection arrives at clubhouse")
	check(not a.enrolled(),"Visiting clubhouse does not enroll in competition")
	check(is_instance_valid(a.clubhouse_board) and a.clubhouse_board.start_button.disabled,"Wall-bound competition UI awaits players")
	var pose:Transform3D=load("res://addons/golfminus/scripts/golf/host_locations.gd").pose(g.current_location)
	check(g.motor.global_position.distance_to(pose.origin)<.1,"Arrival stands on clubhouse deck")
	check(a.golf.equipment.stowed,"Club is safely stashed on arrival")
	check(identities==[g.network.get_instance_id(),g.avatar.get_instance_id(),g.shoulder_radio.get_instance_id()],"Avatar, radio and session identities preserved")
	a.start_play("solo");await process_frame
	check(a.enrolled() and a.service.view.mode=="solo","Solo play explicitly enrolls its own round")
	check(g.current_location=="golf_spyglass_00" and a.clubhouse_round==null,"Solo play moves from clubhouse to tee")
	var palm:Vector3=g.head.global_position+Vector3(.24,-.5,-.4)
	g.avatar.right_grip=Transform3D(Basis.IDENTITY,palm);g.avatar.right_grip_frame=Engine.get_process_frames()
	a.attach_club_to_hand()
	check(a.golf.club.global_position.distance_to(palm)<.001,"Club grip follows resolved avatar palm")
	check(a.notice.remaining<=0,"Solo play has no turn notification")
	check(load("res://scripts/network/state.gd").valid(load("res://scripts/network/state.gd").capture(g,1)),"Golf pose is valid")
	check(a.golf.world.find_children("CanopyCaps","",true,false).is_empty(),"Cutout trees have no visible collision spheres")
	check(a.golf.world.find_children("GolfTree*","StaticBody3D",true,false).size()>0,"Tree collision retained")
	check(a.course_life.birds.bird_count>0 and a.course_life.insects.insect_count>0 and a.course_life.animals.size()==3,"Course has birds, insects and ground wildlife")
	check(a.course_life.sound.playing,"Course ambience is playing")
	var Icons=load("res://addons/golfminus/scripts/golf/pictograms.gd")
	Icons.enabled=false;a.course_life._process(.01);check(not a.course_life.marker.visible,"Guiding off hides current-hole beacon")
	Icons.enabled=true;a.course_life._process(.01);check(a.course_life.marker.visible,"Guiding on restores current-hole beacon")
	await process_frame
	a.golf.hud.map.prepare()
	var pins_fit:=true
	for i in 18:
		if not a.golf.hud.map.rect.grow(1).has_point(a.golf.hud.map.project(a.golf.model.pin_for(i))):pins_fit=false
	check(pins_fit and a.golf.hud.map.project(a.golf.model.pin_for(0)).distance_to(a.golf.hud.map.project(a.golf.model.pin_for(17)))>1,"Unified minimap includes distinct pins for every hole")
	a.golf.toggle_menu(true)
	check(g.menu_open and a.settings_open,"Golf opens shared menu")
	var texts:Array=[]
	for b in g.avatar_menu.pages.golf.page.find_children("*","Button",true,false):texts.append(b.text)
	check(not texts.has("Go fishing") and not texts.has("Clubhouse BBQ") and not texts.has("Stash / retrieve club") and not texts.has("Avatar & settings"),"Redundant golf menu actions removed")
	a.close_settings()
	a.golf.strike(a.golf.aim_direction()*15,a.golf.aim_direction())
	check(a.golf.ball.moving and a.service.view.flight,"Solo server authorizes physical shot")
	a.golf.ball.moving=false;a.golf.was_moving=false;a.golf._complete_shot();await process_frame
	g.bbq.visit();await create_timer(.7).timeout;a.update_player(.016)
	check(g.bbq.visiting and g.current_location=="golf_spyglass_clubhouse","Existing BBQ menu visits course clubhouse")
	check(a.service.view.deadline==0 and not a.service.view.present,"Solo BBQ break has no timeout")
	var old_hole:int=a.service.view.hole
	a.service.rules.tick(a.service.now+10000);a.service.publish();await process_frame
	check(a.service.view.hole==old_hole,"Long solo break does not forfeit a hole")
	g.bbq.return_to_water();await create_timer(.4).timeout
	check(a.clubhouse_round==null and not g.bbq.visiting,"Existing BBQ return restores round")
	a.leave();await process_frame
	check(not a.active and g.current_location==original,"Waters transition restores fishing")
	await a.resume_course();await process_frame
	check(a.active and a.clubhouse_round==null and g.current_location.begins_with("golf_spyglass_"),"Return to course works while in fishing")
	a.retire();await process_frame
	check(not a.active and a.service.view.retired,"Retire withdraws from round")
	check(not a.cached_rounds.has("spyglass") and preload("res://addons/golfminus/scripts/golf/round.gd").new().read_progress()==null,"Accepted server retirement clears cached and disk progress")
	g.network.leave()
	await a.join_course("pebble");a.start_play("solo");await process_frame
	a.leave();await process_frame;await a.resume_course();await process_frame
	check(a.active and a.golf.course_id=="pebble" and a.clubhouse_round==null,"Offline solo round resumes from fishing too")
	# Ordinary leaving preserves progress; retirement explicitly discards it.
	a.golf.round_state.hole=2;a.golf.round_state.scores.assign([5,6]);a.golf.round_state.strokes=2
	a.golf.load_hole(2);a.golf.ball.position+=Vector3(10,0,5);a.golf.ball.moving=false
	var previous:Vector3=a.golf.ball.position
	a.leave();await process_frame;await a.resume_course();await process_frame
	check(a.golf.round_state.hole==2 and a.golf.ball.position.is_equal_approx(previous),"Leaving for fishing retains the current hole and lie")
	a.retire();await process_frame
	check(not a.active and not a.cached_rounds.has("pebble") and preload("res://addons/golfminus/scripts/golf/round.gd").new().read_progress()==null,"Offline retirement clears both restore paths")
	await a.join_course("pebble");await a.resume_course();await process_frame
	check(a.golf.round_state.hole==0 and a.golf.round_state.strokes==0 and a.golf.round_state.scores.is_empty() and a.golf.ball.position.distance_to(a.golf.model.tee(a.golf.tee_kind))<.001,"Rejoining after retirement starts at first-hole tee")
	a.golf.round_state.strokes=3;a.golf.ball.position+=Vector3(12,0,0)
	a.arrive_clubhouse();a.start_play("solo");await process_frame
	check(a.golf.round_state.strokes==0 and a.golf.ball.position.distance_to(a.golf.model.tee(a.golf.tee_kind))<.001,"Explicit new solo round starts fresh from clubhouse")
	var cap:int=load("res://addons/golfminus/scripts/golf/handicap.gd").cap("pebble",a.golf.model.index,a.golf.round_state.handicap)
	a.golf.round_state.strokes=cap-1;a.golf.round_state.last_safe=a.golf.ball.position;a.golf.ball.holed=false
	a.golf.recover_ball()
	check(a.golf.ball.holed and a.golf.round_state.scores.back()==cap,"Offline relief stops at net double bogey")
	a.leave();await process_frame;a.retire()
	check(not a.cached_rounds.has("pebble") and preload("res://addons/golfminus/scripts/golf/round.gd").new().read_progress()==null,"Retiring while back at fishing also discards the suspended round")
	g.ambience.stop();g.queue_free();await process_frame;await create_timer(.3).timeout
	print("HOST SOCIAL %d/%d passed"%[checks-failures,checks]);quit(1 if failures else 0)
