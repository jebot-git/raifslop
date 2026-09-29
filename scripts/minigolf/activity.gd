extends Node3D
## Putting activity inside the fishing world; shared rig, identity, ambience and EOS.
const Catalog=preload("res://scripts/minigolf/catalog.gd")
const Locations=preload("res://scripts/minigolf/host_locations.gd")
const Ball=preload("res://scripts/minigolf/ball.gd")
const Putter=preload("res://scripts/minigolf/putter.gd")
const World=preload("res://scripts/minigolf/world.gd")
const MAX_STROKES:=12
signal returned_to_fishing
var host:Node3D
var active:=false
var course_id:=""
var hole:=0
var strokes:=0
var scores:Array=[]
var finished:=false
var ball=Ball.new()
var swing=Putter.new()
var world:Node3D
var guide:Node3D
var fitting:RefCounted
var physical_head:Node3D
var shaft_visual:Node3D
var fit_controls:Control
var club:Node3D
var ball_mesh:MeshInstance3D
var ball_label:Label3D
var service:Node
var status:Label
var scorecard:Label
var readout:Label3D
var saved:Dictionary={}
var hidden:Array=[]
var left_handed:=false
var support_hand:Node3D
var club_length:=1.0
var grip_to_putt:=true
var pending:=Vector2.ZERO
var pending_time:=0.0
var shot_epoch:=-1
var advance_wait:=0.0
var aim:=Vector2(0,-1)
var power:=0.0
var charging:=false
var competition:=false
var collected:Dictionary={}
var last_status:=""
var view_epoch:=-1
func setup(game:Node3D)->void:
	host=game;name="Minigolf";add_to_group("activity_services")
	fitting=preload("res://scripts/minigolf/fitting.gd").new();fitting.load_profile();club_length=fitting.reach;left_handed=fitting.left_handed
	support_hand=preload("res://scripts/minigolf/support_hand.gd").new();support_hand.activity=self;add_child(support_hand)
	service=host.network.golf
	service.changed.connect(sync_session,CONNECT_DEFERRED);service.result.connect(command_result)
	host.network.changed.connect(network_changed)
	var prefs:=ConfigFile.new()
	if prefs.load("user://minigolf.cfg")==OK:
		left_handed=prefs.get_value("controls","left",false)==true
		var length=prefs.get_value("controls","length",1.0)
		if (length is float or length is int) and is_finite(length):club_length=clampf(length,.35,1.6)
		var balls=prefs.get_value("collection","balls",{})
		if balls is Dictionary:
			for key in balls:
				if key is String and balls[key]==true:collected[key]=true
	var page:=VBoxContainer.new();page.add_theme_constant_override("separation",14)
	var intro:=Label.new();intro.text="Waterfront Minigolf\n18 holes at every water · one putter · lowest score wins";page.add_child(intro)
	_button(page,"Join minigolf at this water",func():enter(host.current_location))
	status=Label.new();status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;page.add_child(status)
	_button(page,"Teleport to ball",teleport_to_ball)
	_button(page,"Find nearby lost ball",collect_nearby)
	_button(page,"Return to fishing",leave)
	_button(page,"Join shared round at this water",join_competition)
	_button(page,"Open minigolf guide",func():
		if active:toggle_menu(false);guide.toggle())
	_button(page,"Fit controller angle and putter length",begin_club_fit)
	_button(page,"Undo last fitting",undo_club_fit)
	_button(page,"Start shared round (host)",func():
		if active and host.network.active:service.request("start"))
	var hand:=CheckButton.new();hand.text="Left-handed putter";hand.button_pressed=left_handed;page.add_child(hand);hand.toggled.connect(func(value):left_handed=value;swing.reset();save_settings())
	var length_label:=Label.new();length_label.text="Putter length";page.add_child(length_label)
	var length:=HSlider.new();length.min_value=.35;length.max_value=1.6;length.step=.01;length.value=fitting.reach;page.add_child(length);length.value_changed.connect(func(value):club_length=value;fitting.reach=value;fitting.save_profile();swing.reset();save_settings())
	var help:=Label.new();help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;help.text="Hold grip to arm the putter; release to practice. Trigger: teleport to your ball. A/X: collect a nearby lost ball. B/Y: menu and scorecard. Move and turn with the stick.\nDesktop: arrows aim, hold/release Space to putt, T to teleport, C to collect, Esc for menu.";page.add_child(help)
	scorecard=Label.new();scorecard.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;page.add_child(scorecard)
	fit_controls=preload("res://scripts/minigolf/fit_controls.gd").new();fit_controls.activity=self;page.add_child(fit_controls)
	host.avatar_menu._register_page("minigolf","Minigolf",page)
	for controller in [host.left,host.right]:
		controller.button_pressed.connect(controller_pressed.bind(controller))
		controller.button_released.connect(controller_released.bind(controller))
func _button(parent:Node,text:String,callback:Callable)->void:
	var b:=Button.new();b.text=text;b.custom_minimum_size.y=52;parent.add_child(b);b.pressed.connect(callback)
func save_settings()->void:
	var prefs:=ConfigFile.new();prefs.set_value("controls","left",left_handed);prefs.set_value("controls","length",club_length);prefs.set_value("collection","balls",collected);prefs.save("user://minigolf.cfg")
func enter(id:String)->void:
	if id not in Catalog.ALL or host.quitting:return
	if active:
		if course_id==id:toggle_menu(false);return
		leave()
	if host.game.state!=host.Session.State.READY or host.casting:status.text="Finish your cast and release the catch first.";return
	if host.current_location!=id and not host._select_location(id):return
	saved={"location":id,"position":host.motor.global_position,"safe":host.motor.safe_spawn,"single":host.motor.single_controller_controls,"hand":host.motor.single_controller_hand,"stowed":host.rod_holster.stowed,"catch_controls":host.motor.catch_controls,"turn_reserved":host.motor.turn_reserved,"stick_lock":host.motor.stick_lock,"stick_release":host.motor.stick_release_pending}
	if host.bbq.visiting:
		saved.position=host.bbq.return_at;saved.safe=host.bbq.return_safe
		host.bbq.release_all();host.bbq.visiting=false
	host.fish_guide.dock();host.shoulder_radio.reset();host.rod_holster.set_stowed(true)
	hidden.clear()
	for key in ["rod","rod_visual","rod_status","fish_guide","catch_label","bobber","fish_display","line_mesh","hud"]:
		var node=host.get(key)
		if is_instance_valid(node) and (node is Node3D or node is CanvasItem):hidden.append({"node":node,"visible":node.visible});node.hide()
	active=true;course_id=id;hole=0;strokes=0;scores=[];finished=false;competition=host.network.active;view_epoch=-1;pending=Vector2.ZERO;shot_epoch=-1;advance_wait=0
	ensure_world()
	for i in 18:world.lost_balls[i].visible=not collected.has(id+"/%d"%i)
	club=Node3D.new();add_child(club)
	shaft_visual=load("res://assets/minigolf/models/putter.glb").instantiate();club.add_child(shaft_visual)
	for part in shaft_visual.get_children():
		if "finished head" in str(part.name):physical_head=part;part.reparent(club);break
	guide=preload("res://scripts/minigolf/guide.gd").new();guide.activity=self;add_child(guide)
	ball_mesh=MeshInstance3D.new();var sphere:=SphereMesh.new();sphere.radius=Ball.RADIUS;sphere.height=Ball.RADIUS*2;sphere.radial_segments=16;sphere.rings=8;ball_mesh.mesh=sphere;ball_mesh.material_override=World.material(Color("ffedbe"),.25);add_child(ball_mesh)
	ball_label=Label3D.new();ball_label.text="YOUR BALL";ball_label.font_size=28;ball_label.pixel_size=.0018;ball_label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;add_child(ball_label)
	readout=Label3D.new();readout.pixel_size=.0025;readout.font_size=40;readout.billboard=BaseMaterial3D.BILLBOARD_ENABLED;add_child(readout)
	host.motor.single_controller_controls=true;host.motor.single_controller_hand=pointer_controller;host.motor.stick_lock=putt_grip_held
	host.motor.catch_controls=false;host.motor.turn_reserved=false;host.motor.radial_open=false
	load_hole(0);host.motor.relocate(Locations.pose(id).origin);toggle_menu(false)
	if host.network.active:
		# Retire any previous membership before creating a fresh server-owned card.
		if not service.view.is_empty() and not service.view.get("retired",true):service.request("retire")
		service.request("join",{"course":id,"mode":"competition"})
	else:restore_round()
	status.text=Catalog.course(id).holes[hole].hint
	if is_instance_valid(host.progress):host.progress.visit(Locations.location(course_id,hole))
func cancel_loading()->void:
	if active:save_round()
func leave()->void:
	if not active:return
	save_round()
	if host.network.active:service.request("retire")
	active=false;fitting.cancel();swing.reset();pending=Vector2.ZERO;charging=false;power=0
	for node in [club,ball_mesh,ball_label,readout,guide]:
		if is_instance_valid(node):node.queue_free()
	for state in hidden:
		if is_instance_valid(state.node):state.node.visible=state.visible
	hidden.clear();host.current_location=saved.location
	host.motor.single_controller_controls=saved.single;host.motor.single_controller_hand=saved.hand
	host.motor.catch_controls=saved.catch_controls;host.motor.turn_reserved=saved.turn_reserved
	host.motor.stick_lock=saved.stick_lock;host.motor.stick_release_pending=saved.stick_release
	host.motor.relocate(saved.position);host.motor.safe_spawn=saved.safe
	host.rod_holster.set_stowed(saved.stowed)
	if host.menu_open:host._toggle_avatar_menu()
	host.bbq.select_location();returned_to_fishing.emit()
func load_hole(index:int)->void:
	hole=clampi(index,0,17);strokes=0;ball.reset(Catalog.course(course_id).holes[hole]);swing.reset();pending=Vector2.ZERO;charging=false;power=0
	# Keep the actual water identity: anglers, BBQ and golfers share one world.
	aim=(Catalog.point(ball.layout.cup)-ball.position).normalized();update_ball();refresh_scorecard()
func ball_position()->Vector3:
	return Catalog.origin(hole)+Vector3(ball.position.x,ball.height(ball.position)+Ball.RADIUS-(.05 if ball.holed else 0),ball.position.y)
func update_ball()->void:
	ball_mesh.global_position=ball_position();ball_label.global_position=ball_position()+Vector3(0,.25,0);ball_label.visible=not finished and host.head.global_position.distance_to(ball_position())>3
func teleport_to_ball()->void:
	if not active or ball.moving:return
	var target:=ball_position()
	var cup:=Catalog.point(ball.layout.cup)
	var forward:Vector2=(cup-ball.position).normalized()
	if forward.length()<.5:forward=Vector2(0,-1)
	var side:=Vector2(-forward.y,forward.x)*(1 if left_handed else -1)
	var at:Vector2=ball.position+side*.65
	at.x=clampf(at.x,-float(ball.layout.width)/2-.45,float(ball.layout.width)/2+.45)
	at.y=clampf(at.y,-float(ball.layout.length)-.35,.6)
	target=Catalog.origin(hole)+Vector3(at.x,ball.height(at)+.04,at.y)
	host.motor.relocate(target);swing.reset()
func pointer_controller()->XRController3D:
	var preferred:XRController3D=host.left if left_handed else host.right
	var other:XRController3D=host.right if left_handed else host.left
	return preferred if preferred.get_has_tracking_data() or not other.get_has_tracking_data() else other
func allows_calibration()->bool:return not active or not ball.moving
func toggle_menu(value:bool)->void:
	if host.menu_open!=value:host._toggle_avatar_menu()
	if value:host.avatar_menu.show_page("minigolf")
	swing.reset();charging=false;power=0
func controller_pressed(button:String,controller:XRController3D)->void:
	if not active:return
	if guide.held:
		guide.controller_button(button,controller)
		return
	if controller!=pointer_controller():return
	if fitting.active:
		if button=="trigger_click":fitting.session.capture_requested=true
		elif button=="ax_button":fitting.accept();swing.reset()
		elif button in ["by_button","menu_button"]:fitting.cancel();swing.reset()
		return
	if button in ["by_button","menu_button"]:toggle_menu(not host.menu_open);return
	if host.menu_open:
		if button=="trigger_click":host._menu_click(true)
		return
	if button=="trigger_click":teleport_to_ball()
	elif button=="ax_button":collect_nearby()
func controller_released(button:String,controller:XRController3D)->void:
	if active and host.menu_open and controller==pointer_controller() and button=="trigger_click":host._menu_click(false)
func update_player(dt:float)->void:
	if not active:return
	guide.update()
	if is_instance_valid(host.tracking_manager):host.tracking_manager.sample(dt)
	for hand in host.calibrated_hands.size():host.calibrated_hands[hand].transform=host.controller_calibration.pose(hand)
	support_hand.update(dt)
	host._update_avatar(dt)
	if host.menu_open:
		if host.xr:host._update_menu_pointer()
		var scroll:float=preload("res://scripts/ui/scroll_router.gd").joystick_axis()
		if host.xr:scroll=-pointer_controller().get_vector2("primary").y
		if absf(scroll)>.2:host.avatar_menu.scroll_page(scroll*650*dt)
	else:host.shoulder_radio.update()
	var controller:=pointer_controller()
	var armed:bool=not fitting.active and not guide.held and not host.bbq.visiting and not host.menu_open and not finished and pending==Vector2.ZERO and not ball.moving and advance_wait<=0 and (not host.xr or (controller.get_has_tracking_data() and host.tracking_manager.focused and host.motor.tracking_focused))
	if host.network.active:armed=armed and service.can_shoot()
	club.visible=not host.menu_open and not finished and not host.bbq.visiting and not guide.held
	if host.xr:
		var side:=0 if controller==host.left else 1
		var tracked:bool=controller.get_has_tracking_data() and host.tracking_manager.focused
		var controller_pose:Transform3D=host.controller_pose(side)
		if not fitting.mounted[side] and is_instance_valid(host.avatar):
			var palm=host.avatar.hand_grip_pose(side==0)
			if palm is Transform3D:controller_pose.origin=palm.origin
		var grip:Transform3D=fitting.grip_pose(controller_pose,side)
		if fitting.active:fitting.update(controller_pose,side,ball_position(),Vector3(aim.x,0,aim.y),ground_height,dt,tracked)
		var transforms:Dictionary=fitting.transforms(grip,side)
		club.global_transform=grip
		shaft_visual.global_transform=transforms.shaft
		if is_instance_valid(physical_head):physical_head.global_transform=transforms.head
		armed=armed and (controller.get_float("grip")>.55 or controller.is_button_pressed("grip_click"))
		var impulse:Vector2=swing.sample(transforms.head.origin,ball_position(),-transforms.head.basis.z,dt,armed)
		if impulse.length()>.01:request_putt(impulse)
	else:
		if not host.menu_open:
			var direction:=float(Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_LEFT))
			aim=aim.rotated(direction*dt)
			if charging:power=minf(1,power+dt*.45)
		club.global_position=ball_position()+Vector3(-.055,.86*fitting.reach,.08);club.rotation.y=atan2(-aim.x,-aim.y)
		shaft_visual.scale=Vector3(1,fitting.reach,1)
		if is_instance_valid(physical_head):physical_head.position=Vector3(.055,-.86*fitting.reach,0)
	preload("res://scripts/minigolf/club_style.gd").apply(club,host.game.tackle.equipped)
	if pending!=Vector2.ZERO:
		pending_time+=dt
		if pending_time>5:pending=Vector2.ZERO;status.text="Putt request timed out. Rejoin the round to continue."
	if advance_wait>0:
		advance_wait-=dt
		if advance_wait<=0 and not host.network.active:
			if scores.size()==18:finish_round()
			else:load_hole(hole+1);save_round()
	update_ball()
	readout.global_position=Catalog.origin(hole)+Vector3(0,1.4,1.1)
	var turn:String=""
	if host.network.active and not service.view.is_empty():turn="\n"+("Your turn" if service.can_shoot() else "Waiting for "+str(service.view.get("turn_name","players")))
	readout.text="%s\nHole %d / 18 · Par %d · Strokes %d\n%s%s"%[Catalog.NAMES[course_id],hole+1,ball.layout.par,strokes,"Round complete" if finished else "Power %d%%"%roundi(power*100) if charging else "Grip to putt · Trigger to ball",turn]
	if fitting.active:readout.text=fitting.message
func _physics_process(dt:float)->void:
	if not active:return
	# Physics continues through menus and tracking loss; inputs are disarmed separately.
	var outcome:String=ball.tick(dt)
	if not outcome.is_empty():settled(outcome)
func request_putt(impulse:Vector2)->void:
	if not active or finished or host.menu_open or fitting.active or guide.held or host.bbq.visiting or advance_wait>0 or ball.moving or ball.holed or pending!=Vector2.ZERO or not impulse.is_finite() or impulse.length()<.04:return
	if host.network.active:
		if not service.can_shoot():return
		pending=impulse;pending_time=0;shot_epoch=int(service.view.epoch);service.request("shot",{"epoch":shot_epoch})
	else:perform_putt(impulse)
func perform_putt(impulse:Vector2)->void:
	if not ball.strike(impulse):return
	strokes+=1;swing.reset();refresh_scorecard()
	if host.xr:pointer_controller().trigger_haptic_pulse("haptic",0,minf(.6,.1+impulse.length()*.05),.045,0)
	host._tone(440,.025)
func settled(outcome:String)->void:
	if outcome=="hazard":strokes=mini(MAX_STROKES,strokes+1);status.text="Water hazard · one penalty stroke · replay from the last safe lie."
	if host.network.active:
		if shot_epoch>=0:service.request("settled",{"epoch":shot_epoch,"holed":outcome=="holed","hazard":outcome=="hazard"});shot_epoch=-1
	else:
		if outcome=="holed" or strokes>=MAX_STROKES:
			scores.append(mini(strokes,MAX_STROKES));advance_wait=1.0
		else:save_round()
	if outcome=="holed":host._tone(880,.12)
	refresh_scorecard()
func command_result(action:String,accepted:bool)->void:
	if not active:return
	if action=="shot":
		var impulse:=pending;pending=Vector2.ZERO
		if accepted and impulse!=Vector2.ZERO:perform_putt(impulse)
		elif not accepted:status.text="Wait for your turn.";shot_epoch=-1
	elif action=="join":
		if accepted:service.request("presence",{"present":true})
		else:status.text="Could not join this round. Leave and try again."
	elif not accepted:status.text="Round action was declined."
func sync_session()->void:
	if not active or not host.network.active:return
	var view:Dictionary=service.view
	if view.is_empty() or view.get("course","")!=course_id:return
	if view.get("retired",false):return
	scores=view.scores.duplicate()
	if view.finished:finish_round();return
	if view.hole!=hole:load_hole(view.hole)
	if not ball.moving and pending==Vector2.ZERO:strokes=int(view.strokes)
	if view.epoch!=view_epoch:
		view_epoch=view.epoch;swing.reset()
	refresh_scorecard()
func join_competition()->void:
	if not active:enter(host.current_location)
	if not active:return
	if not host.network.active:status.text="Join or host multiplayer first.";return
	if ball.moving:return
	competition=true;service.request("retire");host.motor.relocate(Locations.pose(host.current_location).origin)
	# The server checks lobby presence against its received pose, so wait for that update.
	await get_tree().create_timer(.4).timeout
	if active and competition:service.request("join",{"course":course_id,"mode":"competition"})
func network_changed()->void:
	if not active:return
	if not host.network.active:
		pending=Vector2.ZERO;shot_epoch=-1;status.text="Disconnected · this round continues locally and is not ranked."
	else:status.text="Leave and re-enter minigolf to join the server round."
func finish_round()->void:
	if finished:return
	finished=true;swing.reset();save_round();refresh_scorecard()
	if is_instance_valid(host.progress):host.progress.golf(course_id,scores,true,service.view.get("forfeit_holes",[]) if host.network.active else [])
	status.text="Round complete · %d strokes · par %d"%[total_score(),preload("res://scripts/minigolf/handicap.gd").total_par(course_id)]
func total_score()->int:
	var total:=0
	for value in scores:total+=int(value)
	return total
func refresh_scorecard()->void:
	if not is_instance_valid(scorecard):return
	var text:="Scorecard · %s\n"%Catalog.NAMES.get(course_id,"")
	for i in scores.size():text+="%02d: %d   "%[i+1,scores[i]]+ ("\n" if i%6==5 else "")
	scorecard.text=text+"\nTotal: %d · Lost balls: %d / 216"%[total_score(),collected.size()]
func collect_nearby()->void:
	if not active:return
	for i in 18:
		var node:MeshInstance3D=world.lost_balls[i]
		if node.visible and host.head.global_position.distance_to(node.global_position)<2.1:
			node.hide();collected[course_id+"/%d"%i]=true;save_settings();refresh_scorecard();status.text="Lost ball found at hole %d!"%(i+1);host._tone(660,.12);return
	status.text="Look beside the lanes. Get close to a coloured ball, then collect it."
func save_round()->void:
	if not active or host.network.active or course_id.is_empty():return
	var cfg:=ConfigFile.new();cfg.set_value("round","layout_version",Catalog.course(course_id).version);cfg.set_value("round","course",course_id);cfg.set_value("round","hole",hole);cfg.set_value("round","scores",scores);cfg.set_value("round","strokes",strokes);cfg.set_value("round","position",ball.last_safe if ball.moving else ball.position);cfg.set_value("round","finished",finished)
	# Leaving in motion consumes the putt and returns it to its previous safe lie.
	cfg.save("user://minigolf_%s.cfg"%course_id)
func restore_round()->void:
	var cfg:=ConfigFile.new()
	if cfg.load("user://minigolf_%s.cfg"%course_id)!=OK or cfg.get_value("round","finished",false):return
	if cfg.get_value("round","layout_version",1)!=Catalog.course(course_id).version:return
	var saved_hole=cfg.get_value("round","hole",0);var card=cfg.get_value("round","scores",[]);var count=cfg.get_value("round","strokes",0);var at=cfg.get_value("round","position",Vector2.ZERO)
	if not saved_hole is int or saved_hole<0 or saved_hole>=18 or not card is Array or card.size()!=saved_hole or not count is int or count<0 or count>=MAX_STROKES or not at is Vector2 or not at.is_finite():return
	for value in card:
		if not value is int or value<1 or value>MAX_STROKES:return
	load_hole(saved_hole)
	if absf(at.x)>=float(ball.layout.width)/2 or at.y>0 or at.y< -float(ball.layout.length):return
	scores=card;strokes=count;ball.position=at;ball.last_safe=at;update_ball();refresh_scorecard()
func _unhandled_input(event:InputEvent)->void:
	if not active:return
	if event is InputEventKey and not event.echo:
		if host.xr:return
		if event.keycode==KEY_ESCAPE and event.pressed:toggle_menu(not host.menu_open);get_viewport().set_input_as_handled()
		if host.xr or host.menu_open:return
		if event.keycode==KEY_T and event.pressed:teleport_to_ball()
		if event.keycode==KEY_C and event.pressed:collect_nearby()
		if event.keycode==KEY_G and event.pressed:guide.toggle()
		if event.keycode==KEY_SPACE:
			if event.pressed:charging=true;power=0
			elif charging:charging=false;request_putt(aim*lerpf(.1,6,power));power=0

func ensure_world()->void:
	var id:String=host.current_location
	if id not in Catalog.ALL:return
	if is_instance_valid(world) and world.course.id==id:return
	if is_instance_valid(world):world.queue_free()
	world=World.new();add_child(world);world.setup(id)
	world.blend_environment(host.water_material)
func _process(_dt:float)->void:
	if not active and is_instance_valid(host) and not host.server_only:ensure_world()
func ground_height(x:float,z:float)->float:
	var base:=Catalog.origin(hole)
	return base.y+ball.height(Vector2(x-base.x,z-base.z))
func begin_club_fit()->void:
	if not active or ball.moving:return
	guide.dock();toggle_menu(false);fitting.begin(0 if left_handed else 1);swing.reset()
func undo_club_fit()->void:fitting.undo();swing.reset()
func cancel_club_fit()->void:fitting.cancel();swing.reset()
func reset_swing()->void:swing.reset()

func putt_grip_held()->bool:
	if not active or host.menu_open or host.bbq.visiting or guide.held:return false
	var controller:=pointer_controller()
	return fitting.active or controller.get_float("grip")>.55 or controller.is_button_pressed("grip_click")
