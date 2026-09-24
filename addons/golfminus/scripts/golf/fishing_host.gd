extends Node
## Live activity boundary: retains the host rig, avatar, tracking manager and profile.
signal returned_to_fishing
var host: Node3D
var active:=false
var golf: Node3D
var snapshots: Array[Dictionary]=[]
var player_snapshot: Dictionary={}
var return_button: Button
var settings_open:=false
var hidden_tabs:Dictionary={}
var service:Node
var notice:Node
var status:Label
var menu_ready:=false
var routing_menu:=false
var shot_granted:=false
var pending_shot:Dictionary={}
var pending_relief:=false
var last_turn:=""
var joining:=""
var cached_rounds:Dictionary={}
var bbq_was_visiting:=false
var club_settings:Control
var clubhouse_round:ConfigFile
var clubhouse_round_active:=false
var last_course:=""
var lobby_waiting:=false
var clubhouse_board:Node3D
var course_life:Node3D
var avatar_bound:Node3D
var pending_loader:Node
var loading_course:=""
var load_generation:=0
var cancel_load_button:Button
var last_load_metrics:Dictionary={}
func setup(root: Node3D) -> void:
	host=root
	var saved:=ConfigFile.new()
	if saved.load("user://golf_round.cfg")==OK:last_course=str(saved.get_value("round","course",""))
	var page:=VBoxContainer.new();page.add_theme_constant_override("separation",16)
	var title:=Label.new();title.text="Golf";page.add_child(title)
	var courses:=GridContainer.new();courses.columns=2;page.add_child(courses)
	for id in preload("res://addons/golfminus/scripts/golf/catalog.gd").ACTIVE:
		var b:=Button.new();b.text=preload("res://addons/golfminus/scripts/golf/catalog.gd").NAMES[id];b.custom_minimum_size.y=56;b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;courses.add_child(b);b.pressed.connect(join_course.bind(id))
	status=Label.new();status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;page.add_child(status)
	cancel_load_button=Button.new();cancel_load_button.text="Cancel course loading";cancel_load_button.custom_minimum_size.y=50;cancel_load_button.hide();page.add_child(cancel_load_button);cancel_load_button.pressed.connect(cancel_loading)
	var actions:=GridContainer.new();actions.columns=2;page.add_child(actions)
	for entry in [["Return to course",resume_course],["Visit clubhouse",arrive_clubhouse],["Retire from course",retire]]:
		var button:=Button.new();button.text=entry[0];button.custom_minimum_size.y=50;button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;actions.add_child(button);button.pressed.connect(entry[1])
	if is_instance_valid(host.get("network")):service=host.network.get("golf")
	if is_instance_valid(service):service.changed.connect(sync_session,CONNECT_DEFERRED);service.result.connect(command_result)
	notice=preload("res://addons/golfminus/scripts/golf/turn_notice.gd").new();add_child(notice);notice.setup(host)
	host.avatar_menu._register_page("golf","Golf",page)
func _shared(node: Node) -> bool:
	if node.is_in_group("activity_services"):return true
	for key in ["motor","origin","head","left","right","avatar","tracking_manager","network","shoulder_radio","spectator","xr_view","avatar_menu","avatar_menu_view","avatar_panel","menu_pointer","menu_laser","bbq"]:
		var shared=host.get(key)
		if is_instance_valid(shared) and (node==shared or shared.is_ancestor_of(node) or node.is_ancestor_of(shared)):return true
	if is_instance_valid(host.get("network")):
		for actor in host.network.fighters.values():
			if node==actor or actor.is_ancestor_of(node):return true
	return node==self
func _capture(node: Node) -> void:
	if node==self:return
	var shared:=_shared(node)
	if not shared:
		var state: Dictionary={"node":node,"process_mode":node.process_mode}
		node.process_mode=Node.PROCESS_MODE_DISABLED
		if node is GeometryInstance3D or node is Light3D or node is Control or node is CanvasLayer:
			state.visible=node.visible;node.visible=false
		if node is CollisionObject3D:
			state.layer=node.collision_layer;state.mask=node.collision_mask;node.collision_layer=0;node.collision_mask=0
		if node is WorldEnvironment:state.environment=node.environment;node.environment=null
		snapshots.append(state)
	# Even shared rigs can contain fishing tools. Those are hidden explicitly below.
	for child in node.get_children():_capture(child)
func enter(id: String="spyglass") -> void:
	if active or host.quitting:return
	if id not in preload("res://addons/golfminus/scripts/golf/catalog.gd").ALL:
		status.text="Unknown course.";return
	if loading_course==id and is_instance_valid(pending_loader):
		await pending_loader.finished;return
	cancel_loading()
	if is_instance_valid(host.get("game")) and host.game.state!=0:
		status.text="Finish your cast and release the catch before joining golf.";return
	if id not in preload("res://addons/golfminus/scripts/golf/catalog.gd").ACTIVE:
		_activate_course(id,null);return # Original fictional-course saves remain usable.
	var generation:=load_generation
	var loader=preload("res://addons/golfminus/scripts/golf/course_loader.gd").new();add_child(loader)
	pending_loader=loader;loading_course=id;cancel_load_button.show()
	var title:String=preload("res://addons/golfminus/scripts/golf/catalog.gd").NAMES[id]
	status.text="Loading "+title+"…"
	loader.progress.connect(func(value:float,label:String):
		if generation==load_generation:status.text="%s · %d%% · %s"%[title,roundi(value*100),label])
	var saved:ConfigFile=cached_rounds.get(id)
	if saved==null:saved=preload("res://addons/golfminus/scripts/golf/round.gd").new().read_progress()
	loader.start(id,int(saved.get_value("round","hole",0)) if can_restore(saved,id) else 0)
	var prepared:Node3D=await loader.finished
	if not is_inside_tree() or is_queued_for_deletion() or host.is_queued_for_deletion():return
	if generation!=load_generation:
		loader.queue_free();return
	pending_loader=null;loading_course="";cancel_load_button.hide();last_load_metrics=loader.metrics.duplicate()
	if prepared==null:
		status.text="Course loading cancelled." if loader.error.is_empty() else loader.error
	elif host.game.state!=0 or host.casting:
		status.text="Finish your cast and release the catch before joining golf."
	else:
		var activation_start:=Time.get_ticks_usec()
		_activate_course(id,prepared)
		last_load_metrics.activation_ms=(Time.get_ticks_usec()-activation_start)/1000.0
		preload("res://scripts/client_diagnostics.gd").stage("golf_activate",activation_start,{"course":id})
	loader.queue_free()
func cancel_loading()->void:
	load_generation+=1
	if is_instance_valid(pending_loader):pending_loader.cancel();pending_loader=null;status.text="Course loading cancelled."
	loading_course=""
	if is_instance_valid(cancel_load_button):cancel_load_button.hide()
func _activate_course(id:String,prepared:Node3D)->void:
	if is_instance_valid(host.get("bbq")):host.bbq.release_all()
	if is_instance_valid(host.get("fish_guide")):host.fish_guide.dock()
	if is_instance_valid(host.get("shoulder_radio")):host.shoulder_radio.reset()
	if host.menu_open:host._toggle_avatar_menu()
	player_snapshot={"stick_lock":host.motor.stick_lock,"stick_release_pending":host.motor.stick_release_pending,"single_controller_controls":host.motor.single_controller_controls,"single_controller_hand":host.motor.single_controller_hand,"rod_stowed":host.rod_holster.stowed if is_instance_valid(host.get("rod_holster")) else false,"location":host.current_location,"motor":host.motor.global_transform,"origin":host.origin.transform,"head":host.head.transform,"head_current":host.head.current,"head_far":host.head.far,"safe":host.motor.safe_spawn,"velocity":host.motor.velocity,"blocked":host.motor.blocked,"catch_controls":host.motor.catch_controls,"turn_reserved":host.motor.turn_reserved,"radial_open":host.motor.radial_open,"world_scale":XRServer.world_scale,"window_camera":host.get_viewport().get_camera_3d(),"mirror_far":host.spectator.camera.far if is_instance_valid(host.spectator) else 0.0}
	if is_instance_valid(host.get("bbq")):
		var bbq_state:Dictionary={}
		for key in ["visiting","return_at","return_safe","return_location","return_yaw"]:bbq_state[key]=host.bbq.get(key)
		player_snapshot.bbq=bbq_state
	for child in host.get_children():_capture(child)
	for key in ["rod","rod_visual","fish_guide","rod_status","rig_radial","catch_label","avatar_panel","menu_pointer","menu_laser"]:
		var tool=host.get(key)
		if is_instance_valid(tool) and tool is Node3D:
			snapshots.append({"node":tool,"visible":tool.visible});tool.visible=false
	host.ambience.stop()
	active=true;last_course=id
	host.current_location=preload("res://addons/golfminus/scripts/golf/host_locations.gd").location(id,0)
	host.motor.single_controller_controls=true
	host.motor.catch_controls=false;host.motor.turn_reserved=false;host.motor.radial_open=false
	golf=load("res://addons/golfminus/scripts/main.gd").new();golf.host_game=host;golf.host_activity=self;golf.name="GolfActivity"
	if prepared!=null:golf.model=prepared.model;golf.world=prepared
	host.add_child(golf)
	if prepared!=null:prepared.reparent(golf);prepared.name="Course"
	golf.select_course(id)
	var progress=golf.round_state.read_progress()
	if can_restore(progress,id):golf.resume_round()
	else:golf.start_round()
	golf.bridge.shot_completed.connect(shot_settled)
	if cached_rounds.has(id) and can_restore(cached_rounds[id],id):
		golf.load_hole(cached_rounds[id].get_value("round","hole"));golf.round_state.restore(cached_rounds[id],golf.ball)
	if enrolled():
		golf.tee_kind="club";golf.hud.tee_choice.select(0);golf.hud.tee_choice.trigger.disabled=true
	club_settings=golf.hud.pages.controls.page
	club_settings.reparent(host.avatar_menu.pages.golf.page)
	golf.hud.attachment_controls.reparent(host.avatar_menu.pages.controls.page)
	menu_ready=true
	if is_instance_valid(host.get("bbq")):host.bbq.select_location()
	clubhouse_board=preload("res://addons/golfminus/scripts/golf/clubhouse_board.gd").new();golf.add_child(clubhouse_board);clubhouse_board.setup(self)
	course_life=preload("res://addons/golfminus/scripts/golf/course_life.gd").new();golf.add_child(course_life);course_life.setup(self)
	golf.toggle_menu(false)
	preserve_mirror()
	arrive_clubhouse()
	if prepared!=null:prepared.activate_staged()
func preserve_mirror()->void:
	if not host.xr or not is_instance_valid(host.xr_view) or not is_instance_valid(host.spectator):return
	# The PC window remains mono third person. Never move/reparent the XR camera.
	host.spectator.camera.make_current();host.head.make_current()
	host.spectator.camera.far=host.head.far
func update_player(delta: float) -> void:
	if not active:return
	golf.update_club_style()
	preserve_mirror()
	if is_instance_valid(host.avatar) and avatar_bound!=host.avatar:
		avatar_bound=host.avatar;avatar_bound.hand_attachments_updated.connect(attach_club_to_hand)
	if is_instance_valid(host.get("bbq")):
		var visiting:bool=host.bbq.visiting
		if clubhouse_round!=null:golf.hud.hide()
		if visiting!=bbq_was_visiting:
			bbq_was_visiting=visiting
			golf.equipment.set_stowed(visiting)
			if enrolled():service.request("presence",{"present":not visiting and clubhouse_round==null});sync_session()
	var symbols=host.avatar_menu.get("pictograms_toggle")
	if is_instance_valid(symbols):
		preload("res://addons/golfminus/scripts/golf/pictograms.gd").enabled=symbols.button_pressed
		if golf.hud.icons_were_enabled!=preload("res://addons/golfminus/scripts/golf/pictograms.gd").enabled:golf.hud.refresh_icons()
	if settings_open:
		if not host.menu_open:close_settings()
		else:
			if host.xr and host.has_method("_update_menu_pointer"):host._update_menu_pointer()
			var scroll:float=preload("res://scripts/ui/scroll_router.gd").joystick_axis()
			if host.xr:
				for controller in [host.left,host.right]:
					var axis:float=-controller.get_vector2("primary").y
					if controller.get_has_tracking_data() and absf(axis)>absf(scroll):scroll=axis
			if absf(scroll)>.2:host.avatar_menu.scroll_page(scroll*650*delta)
	# Giant-scale head/controller poses are view-only, not avatar body samples.
	if golf.godview.active:
		if is_instance_valid(host.tracking_manager):golf.focused=host.tracking_manager.focused and host.motor.tracking_focused
		if is_instance_valid(host.shoulder_radio):host.shoulder_radio.reset()
		return
	for hand in host.calibrated_hands.size():
		host.calibrated_hands[hand].transform=host.controller_calibration.pose(hand)
	if is_instance_valid(host.tracking_manager):
		host.tracking_manager.sample(delta)
		golf.focused=host.tracking_manager.focused and host.motor.tracking_focused
	if is_instance_valid(host.avatar):
		var tm=host.tracking_manager
		host.avatar.grounded=host.motor.is_on_floor()
		host.avatar.tracked_leg_animation=tm.tracked_leg_animation if is_instance_valid(tm) else false
		host.avatar.apply_tracking(host.motor.global_transform,tm.body if is_instance_valid(tm) else {},tm.face if is_instance_valid(tm) else {})
		var left_target: Node3D=host.calibrated_hands[0]
		var right_target: Node3D=host.calibrated_hands[1]
		var supported:bool=golf.support_hand.update(delta)
		if supported:
			if golf.left_handed:right_target=golf.support_hand
			else:left_target=golf.support_hand
		host.avatar.update_targets(host.head,left_target,right_target,host.motor.global_position.y,host.motor.last_motion,delta)
		if supported:
			# As with the fishing reel, the attachment owns visual IK only.
			var side:String="right" if golf.left_handed else "left"
			host.avatar.xr_pose.body.erase(side+"_hand")
			host.avatar.xr_pose.body.erase(side+"_elbow")
			host.avatar.xr_pose.body.erase(side+"_finger_rotations")
			host.avatar.xr_pose.body[side+"_curls"]=PackedFloat32Array([.8,.8,.8,.8,.8])
		host.avatar.left_curl=host.left.get_float("grip")*.8
		if host.avatar_menu.has_method("update_preview"):host.avatar_menu.update_preview(host.avatar)
	if is_instance_valid(host.shoulder_radio):
		if golf.godview.active or golf.menu_open or golf.course_guide.held or golf.club_radial.opened or not golf.focused:host.shoulder_radio.reset()
		else:host.shoulder_radio.update()
func leave(discard_round:=false) -> void:
	cancel_loading()
	if not active:
		if discard_round:
			var id:String=service.view.get("course",last_course) if is_instance_valid(service) and host.network.active else last_course
			cached_rounds.erase(id)
			preload("res://addons/golfminus/scripts/golf/round.gd").new().discard_progress(id)
		return
	if enrolled() and (golf.ball.moving or not pending_shot.is_empty()):
		status.text="Let the shot settle, or retire to withdraw immediately.";return
	menu_ready=false
	if settings_open:close_settings()
	if enrolled():service.request("presence",{"present":false})
	if is_instance_valid(host.get("bbq")):host.bbq.release_all();host.bbq.visiting=false
	if discard_round:
		golf.round_active=false
		cached_rounds.erase(golf.course_id)
		golf.round_state.discard_progress(golf.course_id)
	else:
		golf.save_progress()
		var cfg=golf.round_state.read_progress()
		if clubhouse_round!=null:cfg=clubhouse_round
		if cfg!=null:cached_rounds[golf.course_id]=cfg
	pending_shot.clear();pending_relief=false;clubhouse_round=null
	if is_instance_valid(avatar_bound) and avatar_bound.hand_attachments_updated.is_connected(attach_club_to_hand):avatar_bound.hand_attachments_updated.disconnect(attach_club_to_hand)
	avatar_bound=null
	if is_instance_valid(club_settings):
		golf.hud.attachment_controls.reparent(club_settings)
		club_settings.reparent(golf.hud.pages.controls.view);club_settings=null
	golf.release_borrowed_rig()
	host.remove_child(golf);golf.queue_free();golf=null
	for state in snapshots:
		if not is_instance_valid(state.node):continue
		var n: Node=state.node
		if state.has("process_mode"):n.process_mode=state.process_mode
		if state.has("visible"):n.visible=state.visible
		if state.has("layer"):n.collision_layer=state.layer;n.collision_mask=state.mask
		if state.has("environment"):n.environment=state.environment
	snapshots.clear()
	host.motor.global_transform=player_snapshot.motor
	host.origin.transform=player_snapshot.origin
	host.head.transform=player_snapshot.head;host.head.current=player_snapshot.head_current;host.head.far=player_snapshot.head_far
	host.motor.stick_lock=player_snapshot.stick_lock;host.motor.stick_release_pending=player_snapshot.stick_release_pending
	host.motor.single_controller_controls=player_snapshot.single_controller_controls
	host.motor.single_controller_hand=player_snapshot.single_controller_hand
	host.motor.safe_spawn=player_snapshot.safe;host.motor.velocity=player_snapshot.velocity
	host.motor.blocked=player_snapshot.blocked;host.motor.catch_controls=player_snapshot.catch_controls
	host.motor.turn_reserved=player_snapshot.turn_reserved;host.motor.radial_open=player_snapshot.radial_open
	XRServer.world_scale=player_snapshot.world_scale
	if is_instance_valid(player_snapshot.window_camera):player_snapshot.window_camera.make_current()
	if is_instance_valid(host.spectator):host.spectator.camera.far=player_snapshot.mirror_far
	host.current_location=player_snapshot.location
	active=false;bbq_was_visiting=false
	host.ambience.select_location(host.current_location)
	if is_instance_valid(host.get("rod_holster")):host.rod_holster.set_stowed(player_snapshot.rod_stowed)
	if is_instance_valid(host.get("bbq")):
		host.bbq.select_location()
		for key in player_snapshot.get("bbq",{}):host.bbq.set(key,player_snapshot.bbq[key])
		host.bbq.refresh()
	if is_instance_valid(host.avatar_menu.get("resume_button")):host.avatar_menu.resume_button.text="Return to the water"
	returned_to_fishing.emit()

func open_settings(page:="controls") -> void:
	if not active or settings_open:return
	routing_menu=true;golf.toggle_menu(true);routing_menu=false
	settings_open=true
	golf.hud.hide()
	if is_instance_valid(host.avatar_menu.get("resume_button")):host.avatar_menu.resume_button.text="Return to BBQ" if clubhouse_round!=null else "Return to course"
	if is_instance_valid(golf.ui_plane):golf.ui_plane.hide();golf._release_pointer()
	if host.avatar_menu.get("pages") is Dictionary:
		for key in ["tackle"]:
			if host.avatar_menu.pages.has(key):
				var tab:Button=host.avatar_menu.pages[key].button
				hidden_tabs[key]=tab.visible;tab.hide()
		host.avatar_menu.show_page(page)
	host._toggle_avatar_menu()

func close_settings() -> void:
	if not settings_open:return
	settings_open=false
	if host.menu_open:host._toggle_avatar_menu()
	if is_instance_valid(host.get("hud")):host.hud.hide()
	for key in hidden_tabs:host.avatar_menu.pages[key].button.visible=hidden_tabs[key]
	hidden_tabs.clear()
	golf.hud.show()
	routing_menu=true;golf.toggle_menu(false);routing_menu=false

func allows_calibration()->bool:
	return active and not golf.godview.active and not golf.club_radial.opened and not golf.fitting_club and not golf.course_guide.held and not golf.ball.moving

func enrolled()->bool:
	return is_instance_valid(service) and host.network.active and not service.view.is_empty() and not service.view.get("retired",true) and not service.view.get("finished",true)
func join_course(id:String)->void:
	if active:
		if golf.course_id==id:arrive_clubhouse();return
		if enrolled():status.text="Retire from the current round before changing courses.";return
		leave()
		if active:return
	await enter(id)
func start_play(mode:String)->void:
	if not active or clubhouse_round==null:return
	if enrolled():
		if service.view.mode!=mode:status.text="Retire from the current round before changing mode.";return
		if service.view.started:return_from_clubhouse()
		return
	if mode=="competition" and not host.network.active:status.text="Host or join a multiplayer server first.";return
	if host.network.active:
		joining=golf.course_id;lobby_waiting=true
		service.request("join",{"course":golf.course_id,"mode":mode})
	else:
		cached_rounds.erase(golf.course_id)
		clubhouse_round=null;golf.start_round();prepare_clubhouse()
		return_from_clubhouse()
func start_competition()->void:
	if enrolled():service.request("start")
func resume_course()->void:
	if not active:
		var id:String=service.view.course if enrolled() else last_course
		if id.is_empty():return
		await enter(id)
	if not active:return
	if enrolled() and not service.view.started:arrive_clubhouse();return
	if clubhouse_round!=null:
		if host.network.active and not enrolled():start_play("solo")
		else:return_from_clubhouse()
		return
	if is_instance_valid(host.get("bbq")) and host.bbq.visiting:host.bbq.return_to_water()
	if settings_open:close_settings()
	golf.toggle_menu(false)
func arrive_clubhouse()->void:
	if not active or not prepare_clubhouse():return
	var pose:Transform3D=preload("res://addons/golfminus/scripts/golf/host_locations.gd").pose(host.current_location)
	host.motor.global_position=pose.origin+Vector3(0,.02,0);host.motor.safe_spawn=host.motor.global_position
	host.motor.velocity=Vector3.ZERO;golf.equipment.set_stowed(true)
	if is_instance_valid(clubhouse_board):clubhouse_board.refresh()
func attach_club_to_hand()->void:
	if not active or not is_instance_valid(golf) or golf.equipment.stowed or golf.fitting_club:return
	# The armed render-clock sweep already positioned the visible club using
	# the palm. A later skeleton callback must not move it away from that sweep.
	if golf.xr and golf.club_collision_enabled():return
	golf.apply_club_palm()
	golf._sync_physical_head()
func retire()->void:
	cancel_loading()
	if is_instance_valid(service) and enrolled():service.request("retire");return
	leave(true)
func visit_bbq()->void:
	if not is_instance_valid(host.get("bbq")):return
	if active:
		if golf.ball.moving or not pending_shot.is_empty():status.text="Wait for the shot to settle.";return
		if settings_open:close_settings()
		golf.godview.exit_view();golf.course_guide.dock();golf.equipment.set_stowed(true)
		host.rod_holster.set_stowed(true)
	host.bbq.visit()
func sync_session()->void:
	if not is_inside_tree() or is_queued_for_deletion() or not is_instance_valid(service):return
	var v:Dictionary=service.view
	if v.is_empty():
		if not pending_shot.is_empty() and is_instance_valid(golf):golf.reject_contact(pending_shot.contact,"session_disconnected")
		pending_shot.clear()
		if loading_course.is_empty():status.text="Join a course to play with this server."
		return
	if loading_course.is_empty():
		status.text="%s · Hole %02d · %s"%[v.course,mini(18,int(v.hole)+1),"Retired" if v.retired else "Round complete" if v.finished else "Your turn" if v.your_turn else "Waiting for "+v.turn_name]
		if v.mode=="competition" and v.started and v.your_turn and not v.present:status.text+=" · Return within 5 minutes"
	var turn:="%s/%s/%s"%[v.course,v.id,v.epoch]
	if v.mode=="competition" and v.started and v.your_turn and turn!=last_turn:
		last_turn=turn;notice.show_turn(v.hole,not v.present)
	elif v.mode=="competition" and v.started and v.your_turn:notice.set_context(v.hole,not v.present)
	if is_instance_valid(clubhouse_board):clubhouse_board.refresh()
	if active and lobby_waiting and v.started:
		lobby_waiting=false
		golf.round_state.start();golf.round_state.handicap=int(v.handicap);golf.load_hole(int(v.hole))
		golf.round_state.save_progress(golf.course_id,golf.tee_kind,golf.ball)
		clubhouse_round=golf.round_state.read_progress();clubhouse_round_active=true
		return_from_clubhouse()
	if active and golf.course_id==v.course and v.finished and not v.retired and clubhouse_round==null:
		if golf.model.index!=17:golf.load_hole(17)
		host.current_location=preload("res://addons/golfminus/scripts/golf/host_locations.gd").location(v.course,17)
		if is_instance_valid(host.get("bbq")):host.bbq.select_location()
		golf.round_state.hole=17;golf.round_state.scores.assign(v.scores);golf.round_state.finished=true
		golf.round_active=false;golf.ball.moving=false;golf.ball.holed=true;golf.was_moving=false
		golf.round_state.save_result(golf.course_id)
		return
	if active and golf.course_id==v.course and not v.finished and not v.retired:
		if clubhouse_round!=null:return
		if is_instance_valid(host.get("bbq")) and host.bbq.visiting:return
		if not v.present:service.request("presence",{"present":true});return
		if v.your_turn and v.flight and not golf.ball.moving and pending_shot.is_empty():
			# A grant lost during disconnect still costs its stroke, but cannot lock the round.
			service.request("settled",{"epoch":v.epoch,"holed":false,"hazard":false});return
		if golf.ball.moving:return
		if golf.round_state.hole!=v.hole:
			golf.round_state.hole=v.hole;golf.load_hole(v.hole)
		golf.round_state.strokes=v.strokes
		golf.round_state.scores.assign(v.scores)
		host.current_location=preload("res://addons/golfminus/scripts/golf/host_locations.gd").location(v.course,v.hole)
		if is_instance_valid(host.get("bbq")):host.bbq.select_location()
func intercept_shot(v:Vector3,face:Vector3,contact:Dictionary)->bool:
	if clubhouse_round!=null:golf.reject_contact(contact,"clubhouse");return true
	if not enrolled() or shot_granted:return false
	if not pending_shot.is_empty():return true
	if not service.can_shoot():golf.reject_contact(contact,"waiting_for_turn");return true
	pending_shot={"velocity":v,"face":face,"contact":contact.duplicate(true)}
	golf.pending_contact(contact)
	service.request("shot",{"epoch":service.view.epoch});return true
func request_relief()->void:
	if pending_relief or not enrolled() or not service.can_shoot():return
	pending_relief=true;service.request("penalty",{"epoch":service.view.epoch})
func command_result(action:String,accepted:bool)->void:
	if action=="start" and not accepted:
		status.text="Everyone must gather at the clubhouse before the organiser starts."
		if is_instance_valid(clubhouse_board):clubhouse_board.refresh();clubhouse_board.label.text+="\n"+status.text
		return
	if action=="penalty" and pending_relief:
		pending_relief=false
		if accepted and active and service.view.hole==golf.model.index:
			golf.round_state.strokes=int(service.view.strokes)
			if service.view.done:golf.ball.holed=true
			else:golf.ball.place(golf.round_state.last_safe);golf._reset_lane_aim();golf.address_ball()
		if active:sync_session()
		return
	if action=="retire" and accepted:leave(true);return
	if action=="join":
		var id:=joining;joining=""
		if accepted and not id.is_empty():
			if not active:await enter(id)
			sync_session()
		elif not accepted:
			lobby_waiting=false;status.text="Unable to join. Gather at the clubhouse or retire from your current round first."
			if is_instance_valid(clubhouse_board):clubhouse_board.refresh();clubhouse_board.label.text+="\n"+status.text
	if action=="shot" and not pending_shot.is_empty():
		var shot:=pending_shot.duplicate(true);pending_shot.clear()
		if accepted and active:
			# The snapshot has already counted the authorized shot.
			golf.round_state.strokes=maxi(0,int(service.view.strokes)-1)
			shot_granted=true
			var launched:bool=golf.strike(shot.velocity,shot.face,shot.contact)
			shot_granted=false
			if not launched:service.request("settled",{"epoch":service.view.epoch,"holed":false,"hazard":false})
		else:golf.reject_contact(shot.contact,"shot_not_authorized")
func shot_settled(outcome:Dictionary)->void:
	if enrolled():service.request("settled",{"epoch":service.view.epoch,"holed":outcome.get("holed",false),"hazard":outcome.get("hazard",false)})

func prepare_clubhouse()->bool:
	if not active or golf.ball.moving or not pending_shot.is_empty():return false
	if clubhouse_round!=null:return true
	if settings_open:close_settings()
	golf.godview.exit_view();golf.course_guide.dock()
	golf.save_progress();clubhouse_round=golf.round_state.read_progress()
	if clubhouse_round==null:return false
	clubhouse_round_active=golf.round_active;golf.round_active=false
	if enrolled():service.request("presence",{"present":false})
	golf.equipment.set_stowed(true);golf.hud.hide()
	host.current_location=preload("res://addons/golfminus/scripts/golf/host_locations.gd").clubhouse(golf.course_id)
	host.bbq.select_location();bbq_was_visiting=false
	return true
func return_from_clubhouse()->void:
	if not active or clubhouse_round==null:return
	if enrolled() and not service.view.started:return
	if settings_open:close_settings()
	host.bbq.release_all();host.bbq.visiting=false;bbq_was_visiting=false
	var saved:=clubhouse_round;clubhouse_round=null
	golf.load_hole(saved.get_value("round","hole"));golf.round_state.restore(saved,golf.ball)
	golf.round_active=clubhouse_round_active
	host.current_location=preload("res://addons/golfminus/scripts/golf/host_locations.gd").location(golf.course_id,golf.round_state.hole)
	host.bbq.select_location();golf.equipment.set_stowed(false);golf.hud.show();golf.address_ball()
	if enrolled():service.request("presence",{"present":true})
	if is_instance_valid(clubhouse_board):clubhouse_board.refresh()
	sync_session()

func can_restore(cfg:ConfigFile,id:String)->bool:
	if cfg==null or cfg.get_value("round","course","")!=id:return false
	if not enrolled():return true
	return cfg.get_value("server","round_id","")==service.view.id and cfg.get_value("round","hole",-1)==service.view.hole and cfg.get_value("round","strokes",-1)==service.view.strokes
func stamp_server_progress()->void:
	if not enrolled() or clubhouse_round!=null:return
	var cfg:=ConfigFile.new()
	if cfg.load(golf.round_state.progress_path)!=OK:return
	cfg.set_value("server","round_id",service.view.id);cfg.save(golf.round_state.progress_path)
