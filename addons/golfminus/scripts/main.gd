extends Node3D
const ICONS=preload("res://addons/golfminus/scripts/golf/pictograms.gd")
const MODEL=preload("res://addons/golfminus/scripts/golf/course_model.gd")
const BALL=preload("res://addons/golfminus/scripts/golf/ball_physics.gd")
const CLUBS=preload("res://addons/golfminus/scripts/golf/clubs.gd")
const ROUND=preload("res://addons/golfminus/scripts/golf/round.gd")
const SWING=preload("res://addons/golfminus/scripts/golf/swing_tracker.gd")
const LOCOMOTION=preload("res://scripts/locomotion.gd")
const CALIBRATION=preload("res://scripts/controller_calibration.gd")
var host_game: Node3D
var host_activity: Node
var model=MODEL.new()
var ball=BALL.new()
var round_state=ROUND.new()
var swing=SWING.new()
var calibration=CALIBRATION.new()
var bridge: Node
var telemetry:Node
var last_swing_us:=0
var last_swing_state:=""
var last_capture_state:Dictionary={}
var world: Node3D
var body: CharacterBody3D
var origin: XROrigin3D
var head: Camera3D
var left: XRController3D
var right: XRController3D
var xr:=false
var focused:=true
var left_handed:=false
var preferred_left_handed:=false
var fit_accept_held:=[false,false]
var support_hand:Node3D
var club_reach:=1.0
var club_offsets:Array[Vector3]=[Vector3.ZERO,Vector3.ZERO]
var club_controller_mount:=[false,false]
var club_rotations:Array[Vector3]=[Vector3.ZERO,Vector3.ZERO]
var club_head_rotations:Array[Vector3]=[Vector3.ZERO,Vector3.ZERO]
var club_head_sources:Array[String]=["default","default"]
var club_fitted:=[false,false]
var address_offset:=Vector3(INF,INF,INF) # Shot-local stance, not a world offset.
var address_facing:=Vector3.ZERO
var controller_fallback_time:=0.0
var fitting_club:=false
var fit_session=preload("res://addons/golfminus/scripts/golf/fit_session.gd").new()
var fit_preview:Node3D
var fit_clearance_elapsed:=0.0
var fit_live_clearance:=0.0
var godview:Node3D
var club_radial:Node3D
var equipment:Node3D
var course_guide:Node3D
var club_index:=0
var club: Node3D
var physical_head:MeshInstance3D
var head_shape:RefCounted
var ball_mesh: MeshInstance3D
var aim_mesh: MeshInstance3D
var trail: MeshInstance3D
var trail_points:=PackedVector3Array()
var hud: Control
var ui_viewport: SubViewport
var ui_plane: MeshInstance3D
var pointer_down:=false
var pointer_coords:=Vector2.ZERO
var pointer_dot: MeshInstance3D
var pointer_laser: MeshInstance3D
var last_origin_basis:=Basis.IDENTITY
var menu_open:=true
var practice:=false
var round_active:=false
var course_id:="spyglass"
var tee_kind:="club"
var aim:=0.0
var status_text:="Choose a landscape to begin."
var was_moving:=false
var rest_delay:=0.0
var contact_effects:Node3D
var sound: AudioStreamPlayer3D
var tick:=0
var xr_interface: XRInterface
var world_environment: Environment
var panorama_material: ShaderMaterial
var location_sun: DirectionalLight3D
func _ready() -> void:
	if not is_instance_valid(host_game) and not preload("res://scripts/xr_startup.gd").require_session(self):return
	support_hand=preload("res://addons/golfminus/scripts/golf/support_hand.gd").new();support_hand.game=self;add_child(support_hand)
	bridge=preload("res://addons/golfminus/scripts/golf/activity_bridge.gd").new();bridge.name="ActivityBridge";add_child(bridge)
	telemetry=preload("res://addons/golfminus/scripts/golf/shot_telemetry.gd").new();add_child(telemetry)
	if OS.has_feature("test_build") or "--vr-test-capture" in OS.get_cmdline_user_args():
		print("Golf Minus test build | ",Engine.get_version_info().string," | ",OS.get_name()," | logs: ",ProjectSettings.globalize_path("user://logs"))
		if telemetry.start_capture():print("Golf analytics capture: ",ProjectSettings.globalize_path(telemetry.path))
		else:push_error("Could not open test-build analytics capture")
	_lighting();_rig();_ball_visual()
	contact_effects=preload("res://addons/golfminus/scripts/golf/contact_effects.gd").new();add_child(contact_effects)
	equipment=preload("res://addons/golfminus/scripts/golf/equipment.gd").new();equipment.game=self;add_child(equipment)
	course_guide=preload("res://addons/golfminus/scripts/golf/course_guide.gd").new();course_guide.game=self;add_child(course_guide)
	godview=preload("res://addons/golfminus/scripts/golf/godview.gd").new();add_child(godview);godview.setup(self)
	club_radial=preload("res://addons/golfminus/scripts/golf/club_radial.gd").new();add_child(club_radial);club_radial.setup(self)
	var cfg:=ConfigFile.new();cfg.load("user://golf_controls.cfg");calibration.load_config(cfg)
	if preload("res://addons/golfminus/scripts/golf/club_fit_profile.gd").migrate(cfg):cfg.save("user://golf_controls.cfg")
	ICONS.enabled=bool(cfg.get_value("interface","pictograms",true))
	if is_instance_valid(host_game):calibration=host_game.controller_calibration
	if not is_instance_valid(host_game):
		body.smooth_turn=bool(cfg.get_value("controls","smooth_turn",false))
		body.smooth_turn_speed=clampf(float(cfg.get_value("controls","smooth_turn_speed",75.0)),30,360)
		body.snap_turn_angle=clampf(float(cfg.get_value("controls","snap_turn_angle",30.0)),15,90)
	club_reach=clampf(float(cfg.get_value("golf","reach",1.0)),.35,1.6);left_handed=bool(cfg.get_value("golf","left_handed",false));preferred_left_handed=left_handed
	for hand in 2:
		var offset=cfg.get_value("golf","club_offset_%d"%hand,Vector3.ZERO)
		if offset is Vector3 and offset.is_finite():club_offsets[hand]=offset.clamp(-Vector3.ONE,Vector3.ONE)
		club_controller_mount[hand]=bool(cfg.get_value("golf","club_controller_mount_%d"%hand,false))
		var value=cfg.get_value("golf","club_rotation_%d"%hand,Vector3.ZERO)
		if value is Vector3 and value.is_finite():club_rotations[hand]=value
		value=cfg.get_value("golf","club_head_rotation_%d"%hand,Vector3.ZERO)
		if value is Vector3 and value.is_finite():club_head_rotations[hand]=value
		club_head_sources[hand]=str(cfg.get_value("golf","club_head_source_%d"%hand,"default"))
		club_fitted[hand]=bool(cfg.get_value("golf","club_fitted_%d"%hand,club_rotations[hand].length_squared()>.001 or club_head_rotations[hand].length_squared()>.001))
	_ui()
	fit_preview=preload("res://addons/golfminus/scripts/golf/fit_preview.gd").new();add_child(fit_preview)
	if not is_instance_valid(host_game):select_course("spyglass")
	hud.length_slider.set_value_no_signal(club_reach);hud.hand_choice.set_pressed_no_signal(preferred_left_handed)
	if xr:call_deferred("_initial_xr_menu")
func _initial_xr_menu() -> void:
	# The first tracked camera pose arrives after nodes enter the scene tree.
	await get_tree().process_frame
	await get_tree().process_frame
	if menu_open:toggle_menu(true)
func _lighting() -> void:
	panorama_material=preload("res://addons/golfminus/scripts/core/panorama_material.gd").new()
	var sky:=Sky.new();sky.sky_material=panorama_material;sky.radiance_size=Sky.RADIANCE_SIZE_128
	world_environment=Environment.new();world_environment.background_mode=Environment.BG_SKY;world_environment.sky=sky
	world_environment.ambient_light_source=Environment.AMBIENT_SOURCE_SKY;world_environment.ambient_light_energy=.42
	world_environment.background_energy_multiplier=.65;world_environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	var we:=WorldEnvironment.new();we.environment=world_environment;add_child(we)
	location_sun=DirectionalLight3D.new();location_sun.rotation_degrees=Vector3(-35,-40,0);location_sun.light_color=Color("ffe2b5");location_sun.light_energy=.55
	location_sun.shadow_enabled=false;location_sun.light_angular_distance=4.0;location_sun.light_specular=.45;add_child(location_sun)
	var shadows=preload("res://addons/golfminus/scripts/core/shadow_policy.gd").new();add_child(shadows);shadows.setup(self)
func _rig() -> void:
	if is_instance_valid(host_game):
		body=host_game.motor;origin=host_game.origin;head=host_game.head;left=host_game.left;right=host_game.right;xr=host_game.xr
		head.far=4000
		body.stick_lock=club_input_active
		left.button_pressed.connect(_left_button);left.button_released.connect(_left_released);right.button_pressed.connect(_right_button);right.button_released.connect(_right_released)
		return
	xr_interface=XRServer.find_interface("OpenXR")
	xr=xr_interface!=null and xr_interface.is_initialized()
	if xr:
		get_viewport().physics_object_picking=false
		get_viewport().use_xr=true
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		if xr_interface.has_signal("session_focussed"):xr_interface.connect("session_focussed",func():focused=true;reset_swing())
		if xr_interface.has_signal("session_visible"):xr_interface.connect("session_visible",func():focused=false;reset_swing())
		if xr_interface.has_signal("session_stopping"):xr_interface.connect("session_stopping",func():focused=false;reset_swing())
	body=LOCOMOTION.new();add_child(body)
	origin=XROrigin3D.new();body.add_child(origin)
	head=XRCamera3D.new();origin.add_child(head);head.far=4000
	left=XRController3D.new();left.tracker=&"left_hand";left.pose=&"grip";origin.add_child(left)
	right=XRController3D.new();right.tracker=&"right_hand";right.pose=&"grip";origin.add_child(right)
	body.origin=origin;body.head=head;body.left=left;body.right=right;body.xr=xr;body.stick_lock=club_input_active
	left.button_pressed.connect(_left_button);left.button_released.connect(_left_released);right.button_pressed.connect(_right_button);right.button_released.connect(_right_released)
func _ball_visual() -> void:
	ball_mesh=MeshInstance3D.new();var sphere:=SphereMesh.new();sphere.radius=BALL.RADIUS;sphere.height=BALL.RADIUS*2;sphere.radial_segments=24;sphere.rings=12
	ball_mesh.mesh=sphere
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color("fffdf1");mat.roughness=.36
	ball_mesh.material_override=mat;add_child(ball_mesh)
	aim_mesh=MeshInstance3D.new();add_child(aim_mesh)
	trail=MeshInstance3D.new();add_child(trail)
	sound=AudioStreamPlayer3D.new();add_child(sound);sound.max_distance=80
func _ui() -> void:
	hud=preload("res://addons/golfminus/scripts/hud.gd").new();hud.game=self;hud.size=Vector2(1440,900)
	ui_viewport=SubViewport.new();ui_viewport.size=Vector2i(1440,900);ui_viewport.transparent_bg=true;ui_viewport.gui_embed_subwindows=true
	ui_viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(ui_viewport);ui_viewport.add_child(hud)
	ui_plane=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2(2.3,1.4375);ui_plane.mesh=quad
	var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.albedo_texture=ui_viewport.get_texture();mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	ui_plane.material_override=mat;add_child(ui_plane)
	pointer_dot=MeshInstance3D.new();var dot:=SphereMesh.new();dot.radius=.009;dot.height=.018;pointer_dot.mesh=dot
	var dot_material:=StandardMaterial3D.new();dot_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;dot_material.albedo_color=Color("f3ca75");pointer_dot.material_override=dot_material;add_child(pointer_dot);pointer_dot.visible=false
	pointer_laser=MeshInstance3D.new();var beam:=CylinderMesh.new();beam.top_radius=.0012;beam.bottom_radius=.0012;beam.height=1.0;beam.radial_segments=6
	pointer_laser.mesh=beam;pointer_laser.material_override=dot_material;add_child(pointer_laser);pointer_laser.visible=false
	if is_instance_valid(host_game):
		for item in [ui_plane,pointer_dot,pointer_laser]:preload("res://scripts/guide_camera.gd").mark_ui(item)
func select_course(id: String) -> void:
	course_id=id;round_state.start();practice=false;round_active=false
	load_hole(0);toggle_menu(true)
func load_hole(index: int) -> void:
	godview.exit_view()
	club_radial.close()
	_complete_shot("course_change")
	model.load_course(course_id,index)
	if model.surface!=null:
		var sky:=Sky.new();var material:=ProceduralSkyMaterial.new()
		material.sky_top_color=Color("5384a1");material.sky_horizon_color=Color("bdced0");material.ground_horizon_color=Color("bdced0");sky.sky_material=material;world_environment.sky=sky
	else:
		var sky:=Sky.new();sky.sky_material=panorama_material;world_environment.sky=sky
		panorama_material.set_shader_parameter("panorama",load("res://addons/golfminus/assets/panoramas/%s_8k.hdr"%model.course.panorama))
	if FileAccess.file_exists("res://addons/golfminus/assets/textures/lighting/profiles.json"):
		var profiles: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://addons/golfminus/assets/textures/lighting/profiles.json"))
		if profiles.has(course_id):
			var lighting: Dictionary=profiles[course_id]
			location_sun.rotation_degrees=Vector3(lighting.sun_rotation[0],lighting.sun_rotation[1],lighting.sun_rotation[2]);location_sun.light_energy=lighting.sun_energy
			location_sun.light_color=Color(lighting.sun_color_linear[0],lighting.sun_color_linear[1],lighting.sun_color_linear[2]).linear_to_srgb()
	if model.connected and is_instance_valid(world) and world.get("course_key")==course_id:
		world.select_hole()
	else:
		if is_instance_valid(world):remove_child(world);world.queue_free()
		world=(preload("res://addons/golfminus/scripts/world/connected_course_world.gd").new() if model.connected else preload("res://addons/golfminus/scripts/world/course_world.gd").new())
		world.name="Course";world.tee_kind=tee_kind;add_child(world);world.build(model)
	ball.model=model;ball.collision_query=world.sweep_ball;ball.place(model.tee(tee_kind));ball_mesh.position=ball.position
	contact_effects.arm_tee(ball.position)
	set_club(0)
	trail_points.clear();trail.mesh=null
	aim=(model.pin()-ball.position).signed_angle_to(Vector3.FORWARD,Vector3.UP)
	address_offset=Vector3(INF,INF,INF);address_facing=Vector3.ZERO
	address_ball()
	hud.refresh()
func start_round() -> void:
	practice=false;round_active=true;round_state.handicap=round_state.local_handicap();round_state.start();load_hole(0);toggle_menu(false)
	status_text="Hold grip or trigger and swing the club."
	bridge.activity_started.emit(course_id);_save_preferences();save_progress()
func save_progress() -> void:
	if round_active and not practice:
		round_state.save_progress(course_id,tee_kind,ball)
		if is_instance_valid(host_activity):host_activity.stamp_server_progress()
func resume_round() -> bool:
	var cfg=round_state.read_progress()
	if cfg==null:status_text="No saved round yet.";return false
	practice=false;round_active=true;course_id=cfg.get_value("round","course");tee_kind=cfg.get_value("round","tee","club")
	load_hole(cfg.get_value("round","hole"));round_state.restore(cfg,ball)
	if round_state.strokes>0 or ball.moving or ball.position.distance_to(model.tee(tee_kind))>.06:contact_effects.clear()
	was_moving=ball.moving;toggle_menu(false);address_ball();status_text="Round resumed."
	return true
func start_practice() -> void:
	if is_instance_valid(host_activity) and host_activity.enrolled():status_text="Retire from the course before starting practice.";return
	practice=true;round_active=false;round_state.start();load_hole(0)
	var p: Vector3=model.pin()+Vector3(0,0,6);p.y=model.height(p.x,p.z)+BALL.RADIUS
	contact_effects.clear()
	ball.place(p);set_club(7);toggle_menu(false);address_ball();status_text="Putting practice  ·  six metres to the cup."
func pointer_controller()->XRController3D:
	var preferred:XRController3D=left if left_handed else right
	return preferred if preferred.get_has_tracking_data() else (right if left_handed else left)
func only_one_controller()->bool:
	return xr and left.get_has_tracking_data()!=right.get_has_tracking_data()
func _update_controller_hand(dt:float)->void:
	if not xr or not focused or ball.moving or fitting_club or menu_open:return
	var striking:=left if left_handed else right
	var other:=right if left_handed else left
	var preferred:XRController3D=left if preferred_left_handed else right
	var restore_preference:bool=left_handed!=preferred_left_handed and preferred.get_has_tracking_data()
	if restore_preference or not striking.get_has_tracking_data() and other.get_has_tracking_data():
		controller_fallback_time+=minf(dt,.05)
		if controller_fallback_time>=1.0:
			set_hand(preferred_left_handed if restore_preference else not left_handed,true);controller_fallback_time=0
	else:controller_fallback_time=0
func _process(_delta:float) -> void:
	_update_controller_hand(_delta)
	godview.update(_delta);club_radial.update();equipment.update();course_guide.update()
	if telemetry.enabled:
		var state:Dictionary={"focused":focused,"left_tracked":left.get_has_tracking_data(),"right_tracked":right.get_has_tracking_data(),"menu_open":menu_open,"fitting":fitting_club,"club":club_index}
		if state!=last_capture_state:telemetry.record("interaction_state",state);last_capture_state=state
	if xr and not menu_open and not fitting_club and not godview.active and not club_radial.opened and not equipment.stowed and not course_guide.held and focused:_swing()
func toggle_menu(show_menu: bool) -> void:
	if is_instance_valid(host_activity) and host_activity.menu_ready and not host_activity.routing_menu:
		if show_menu:host_activity.open_settings("golf");return
		elif host_activity.settings_open:host_activity.close_settings();return
	if show_menu and is_instance_valid(godview):godview.exit_view()
	if show_menu and is_instance_valid(club_radial):club_radial.close()
	if show_menu and is_instance_valid(course_guide):course_guide.dock()
	if show_menu and fitting_club:cancel_club_fit()
	menu_open=show_menu;hud.menu.visible=show_menu;body.blocked=show_menu
	if is_instance_valid(club):club.visible=not show_menu
	reset_swing()
	_release_pointer()
	pointer_dot.visible=false
	ui_plane.visible=show_menu
	if show_menu:
		ui_plane.global_basis=Basis(Vector3.UP,atan2(head.global_basis.z.x,head.global_basis.z.z))
		ui_plane.global_position=head.global_position-ui_plane.global_basis.z*1.9
	if is_instance_valid(host_activity):host_activity.preserve_mirror()
	if not show_menu:_save_preferences()
func set_hand(value: bool, automatic:=false) -> void:
	club_radial.close()
	if fitting_club:cancel_club_fit()
	left_handed=value;support_hand.reset();reset_swing();set_club(club_index)
	if not automatic:
		preferred_left_handed=value;address_offset=Vector3(INF,INF,INF);address_facing=Vector3.ZERO
		hud.hand_choice.set_pressed_no_signal(value);_save_preferences()
func set_club(index: int) -> void:
	if fitting_club:cancel_club_fit()
	club_index=posmod(index,CLUBS.BAG.size())
	if is_instance_valid(club):club.queue_free()
	var asset:="putter" if club_index==7 else "driver" if club_index<2 else "iron"
	club=load("res://addons/golfminus/assets/models/%s.glb"%asset).instantiate()
	(left if left_handed else right).add_child(club)
	head_shape=preload("res://addons/golfminus/scripts/golf/club_head.gd").for_club(club_index)
	physical_head=head_shape.install(club,club_index)
	_sync_physical_head()
	club.visible=not menu_open and not godview.active
	if equipment.stowed:equipment.set_stowed(true)
	reset_swing()
func reset_swing() -> void:
	last_swing_us=0
	if is_instance_valid(contact_effects):contact_effects.valid=false
	if is_instance_valid(telemetry):telemetry.end_swing("reset");telemetry.window.clear()
	swing.reset()
	if is_instance_valid(origin):last_origin_basis=origin.global_basis
func aim_direction() -> Vector3:return Vector3(sin(aim),0,-cos(aim))
func address_basis()->Basis:
	var direction:=aim_direction()
	return Basis(direction.cross(Vector3.UP),Vector3.UP,-direction)
func address_ball() -> void:
	if ball.moving:return
	var direction:Vector3=model.pin()-ball.position;direction.y=0
	if direction.length_squared()>.0001:aim=direction.signed_angle_to(Vector3.FORWARD,Vector3.UP)
	var frame:=address_basis()
	var offset:=frame*address_offset if address_offset.is_finite() else Vector3.ZERO
	if not address_offset.is_finite():
		var spacing:=clampf(.35+float(CLUBS.BAG[club_index].length)*club_reach*.65,.85,1.45)
		offset=frame*Vector3(spacing if left_handed else -spacing,0,.1)
	var p: Vector3=ball.position+offset
	p.y=model.height(p.x,p.z)+.06
	var facing:Vector3=frame*address_facing if address_facing.length_squared()>.01 else -offset.normalized()
	var current:Vector3=-head.global_basis.z;current.y=0
	if current.length_squared()<.0001:current=Vector3.UP.cross(head.global_basis.x)
	if current.length_squared()>.0001:body.turn(current.signed_angle_to(facing,Vector3.UP))
	body.relocate(p)
	reset_swing()
func remember_address(at:Vector3)->void:
	var offset:=Vector3(at.x-ball.position.x,0,at.z-ball.position.z)
	if offset.length()>=.55 and offset.length()<=2.0:
		address_offset=address_basis().inverse()*offset
		# Looking down at the ball must not make yaw indeterminate.
		var facing:Vector3=-head.global_basis.z;facing.y=0
		address_facing=address_basis().inverse()*(facing.normalized() if facing.length_squared()>.01 else -offset.normalized())

func release_borrowed_rig() -> void:
	godview.exit_view()
	club_radial.close()
	if fitting_club:cancel_club_fit()
	_complete_shot("activity_exit")
	reset_swing()
	if left.button_pressed.is_connected(_left_button):left.button_pressed.disconnect(_left_button)
	if left.button_released.is_connected(_left_released):left.button_released.disconnect(_left_released)
	if right.button_pressed.is_connected(_right_button):right.button_pressed.disconnect(_right_button)
	if right.button_released.is_connected(_right_released):right.button_released.disconnect(_right_released)
	if is_instance_valid(club):club.get_parent().remove_child(club);club.queue_free()
func _exit_tree()->void:
	if is_instance_valid(godview):godview.exit_view()
func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST:
		if is_instance_valid(godview):godview.exit_view()
		_complete_shot("application_exit");save_progress()
		if is_instance_valid(telemetry):telemetry.stop_capture("application_exit")
func _save_preferences() -> void:
	var cfg:=ConfigFile.new();cfg.load("user://golf_controls.cfg")
	if not is_instance_valid(host_game):
		calibration.save_config(cfg)
		for key in ["smooth_turn","smooth_turn_speed","snap_turn_angle"]:cfg.set_value("controls",key,body.get(key))
	for hand in 2:
		cfg.set_value("golf","club_offset_%d"%hand,club_offsets[hand])
		cfg.set_value("golf","club_controller_mount_%d"%hand,club_controller_mount[hand])
		cfg.set_value("golf","club_rotation_%d"%hand,club_rotations[hand])
		cfg.set_value("golf","club_head_rotation_%d"%hand,club_head_rotations[hand])
		cfg.set_value("golf","club_fitted_%d"%hand,club_fitted[hand])
		cfg.set_value("golf","club_head_source_%d"%hand,club_head_sources[hand])
	cfg.set_value("golf","fit_version",2)
	cfg.set_value("interface","pictograms",ICONS.enabled)
	cfg.set_value("golf","reach",club_reach);cfg.set_value("golf","left_handed",preferred_left_handed);cfg.save("user://golf_controls.cfg")
func _left_button(action:String)->void:_controller_button(action,0)
func _right_button(action:String)->void:_controller_button(action,1)
func _controller_button(action:String,hand:int)->void:
	if action=="ax_button" and fit_accept_held[hand]:return
	var striking:bool=hand==(0 if left_handed else 1)
	var controller:XRController3D=left if hand==0 else right
	if fitting_club:_fit_button(action,striking);return
	if is_instance_valid(host_activity) and host_activity.settings_open:
		if action=="trigger_click" and pointer_controller()==controller:host_game._menu_click(true)
		elif action in ["menu_button","by_button"]:host_activity.close_settings()
		return
	if course_guide.camera_button(action,hand==0):return
	if is_instance_valid(host_activity) and is_instance_valid(host_game.get("bbq")) and host_game.bbq.holds(hand) and action not in ["menu_button","by_button"]:
		if action=="ax_button":host_game.bbq.use(hand,host_game.bbq.hovered,true)
		return
	var club_controls:bool=striking or only_one_controller()
	if godview.active:
		if action in ["by_button","menu_button"] or action=="primary_click" and not club_controls:godview.exit_view()
		elif action=="ax_button":
			if club_controls:godview.focus_ball()
			else:godview.reset_view()
		return
	if action=="primary_click":
		if club_controls:club_radial.toggle()
		else:godview.toggle()
		return
	if club_radial.opened:
		if action in ["by_button","menu_button"]:club_radial.close()
		return
	if action=="menu_button" or club_controls and action=="by_button":toggle_menu(not menu_open);return
	if menu_open:return
	if club_controls and action=="ax_button":
		if ball.holed:next_hole()
		else:address_ball()
	elif not club_controls and action=="trigger_click":
		if not support_hand.update(0):world.grid.visible=not world.grid.visible
func _left_released(action:String)->void:_controller_released(action,0)
func _right_released(action:String)->void:_controller_released(action,1)
func _controller_released(action:String,hand:int)->void:
	if action=="ax_button":fit_accept_held[hand]=false
	if is_instance_valid(host_activity) and host_activity.settings_open:
		var controller:XRController3D=left if hand==0 else right
		if action=="trigger_click" and pointer_controller()==controller:host_game._menu_click(false)

func toggle_analytics()->void:
	if telemetry.enabled:
		telemetry.stop_capture();status_text="Local swing capture saved."
	elif telemetry.start_capture():
		telemetry.record("context",{"course":course_id,"hole":round_state.hole+1,"practice":practice,"club":club_index,"reach":club_reach,"rotations":club_rotations,"world_scale":XRServer.world_scale,"origin_height":origin.position.y})
		status_text="Recording local swing and shot analytics."
	else:status_text="Could not open local analytics file."
func strike(v: Vector3,face: Vector3,contact:Dictionary={}) -> bool:
	var rejection:=""
	if menu_open:rejection="menu_open"
	elif fitting_club:rejection="fitting"
	elif godview.active:rejection="godview"
	elif club_radial.opened:rejection="club_selection"
	elif equipment.stowed:rejection="club_stowed"
	elif course_guide.held:rejection="guide_held"
	elif ball.moving:rejection="ball_moving"
	elif ball.holed:rejection="ball_holed"
	var impact:Dictionary={}
	var lie:String=model.lie(ball.position.x,ball.position.z)
	if rejection.is_empty():
		impact=CLUBS.impact(club_index,v,face,lie,contact)
		if impact.is_empty():rejection="invalid_or_away_from_face"
	var diagnostic:Dictionary=contact.duplicate(true)
	diagnostic.merge({"club":club_index,"club_name":CLUBS.BAG[club_index].name,"lie":lie,"filtered_velocity":v,"face":face,"impact":impact,"source":"vr_render_sweep"},true)
	if not rejection.is_empty():
		diagnostic.rejection=rejection;diagnostic.accepted=false;telemetry.contact(diagnostic);return false
	if is_instance_valid(host_activity) and host_activity.intercept_shot(v,face,contact):return false
	if ball.launch(impact.velocity,impact.spin):
		contact_effects.launch_tee(ball.position,impact.velocity)
		if xr:remember_address(head.global_position)
		round_active=not practice;round_state.shot(ball.position);trail_points.clear();trail_points.append(ball.position);was_moving=true;rest_delay=0
		status_text="Ball in flight";_impact_audio(float(impact.normal_speed_m_s))
		if xr:(left if left_handed else right).trigger_haptic_pulse("haptic",0,clampf(float(impact.normal_speed_m_s)/45,.12,.8),.045,0)
		var payload:Dictionary={"course":course_id,"hole":round_state.hole,"hole_number":round_state.hole+1,"club":club_index,"club_name":CLUBS.BAG[club_index].name,"practice":practice,"lie":lie,"velocity":ball.velocity,"spin":ball.spin,"ball_launch_speed_m_s":ball.velocity.length(),"spin_rpm":ball.spin.length()*60.0/TAU,"launch_angle_degrees":rad_to_deg(atan2(ball.velocity.y,Vector2(ball.velocity.x,ball.velocity.z).length())),"origin":ball.position,"target":model.pin(),"target_distance_m":Vector2(model.pin().x-ball.position.x,model.pin().z-ball.position.z).length(),"club_velocity":v,"raw_velocity":contact.get("raw_velocity",v),"face":face,"impact":impact,"source":diagnostic.source}
		var shot_id:String=telemetry.begin_shot(payload)
		payload.shot_id=shot_id;diagnostic.shot_id=shot_id;diagnostic.accepted=true
		telemetry.contact(diagnostic);bridge.record_shot(payload);save_progress();return true
	diagnostic.rejection="ball_launch_rejected";diagnostic.accepted=false;telemetry.contact(diagnostic)
	return false
func _complete_shot(reason:="")->void:
	if not is_instance_valid(telemetry) or telemetry.pending.is_empty():return
	if trail_points.size()>0 and trail_points[-1].distance_to(ball.position)>.001:trail_points.append(ball.position);_draw_trail()
	var target:Vector3=telemetry.pending.target
	var actual_reason:String=ball.stop_reason if reason.is_empty() else reason
	var result:Dictionary=telemetry.finish_shot({"stop_reason":actual_reason,"completed":reason.is_empty(),"final_position":ball.position,"carry_m":ball.carry,"roll_path_m":ball.roll_distance,"total_path_m":ball.travel_distance,"total_displacement_m":Vector2(ball.position.x-ball.origin.x,ball.position.z-ball.origin.z).length(),"distance_to_pin_m":Vector2(ball.position.x-target.x,ball.position.z-target.z).length(),"apex_m":ball.peak,"holed":ball.holed,"hazard":ball.hazard})
	bridge.record_shot_outcome(result)
func recover_ball() -> void:
	if ball.moving:return
	if practice:start_practice();return
	if is_instance_valid(host_activity) and host_activity.enrolled():
		if not host_activity.service.can_shoot():return
		host_activity.request_relief();return
	if round_state.strokes==0:return
	ball.place(round_state.penalty())
	var maximum:int=preload("res://addons/golfminus/scripts/golf/handicap.gd").cap(course_id,model.index,round_state.handicap)
	if round_state.strokes>=maximum:
		round_state.strokes=maximum;ball.holed=true;round_state.complete_hole();round_state.save_result(course_id)
		status_text="Net double bogey · hole complete"
	else:address_ball();status_text="Stroke-and-distance relief · +1 penalty"
	save_progress()
func next_hole() -> void:
	if is_instance_valid(host_activity) and host_activity.enrolled():host_activity.sync_session();return
	if not ball.holed:return
	if practice:start_practice();return
	if round_state.advance():load_hole(round_state.hole);save_progress();status_text="New hole. Choose your club."
	elif round_state.finished:toggle_menu(true);status_text="Round complete  ·  %d strokes"%round_state.total()
func _physics_process(dt: float) -> void:
	if model.hole.is_empty():return
	if not is_instance_valid(host_game):body.tracking_focused=focused
	if menu_open:
		if xr and not (is_instance_valid(host_activity) and host_activity.settings_open):_pointer()
		if not ball.moving:return
	if club_radial.opened:return
	if fitting_club:
		_update_fit_preview(dt);return
	if xr and not focused:reset_swing();return
	ball.step(dt);ball_mesh.position=ball.position
	if ball.moving:
		tick+=1
		if tick%3==0:trail_points.append(ball.position);_draw_trail()
		status_text="CARRY %.0f m   ·   APEX %.1f m"%[ball.carry,ball.peak]
	elif was_moving:
		if not practice and not (is_instance_valid(host_activity) and host_activity.enrolled()):
			var maximum:int=preload("res://addons/golfminus/scripts/golf/handicap.gd").cap(course_id,model.index,round_state.handicap)
			if round_state.strokes+(1 if ball.hazard else 0)>=maximum:
				round_state.strokes=maximum;ball.hazard=false;ball.holed=true
		_complete_shot()
		was_moving=false
		if ball.hazard:
			ball.place(round_state.penalty());status_text="Water / out of bounds  ·  +1 stroke  ·  Club A/X to address"
		elif ball.holed:
			if not practice:
				round_state.complete_hole();round_state.save_result(course_id)
				bridge.hole_completed.emit({"course":course_id,"hole":round_state.hole,"strokes":round_state.strokes})
				if round_state.finished:bridge.activity_finished.emit({"course":course_id,"scores":round_state.scores})
			status_text="Holed in %d!   N / A: %s"%[round_state.strokes,"putt again" if practice else "next hole"]
		else:
			status_text="CARRY %.0f m   ·   TOTAL %.0f m   ·   T / A to address"%[ball.carry,Vector2(ball.position.x-ball.origin.x,ball.position.z-ball.origin.z).length()]
			aim=(model.pin()-ball.position).signed_angle_to(Vector3.FORWARD,Vector3.UP)
			if model.lie(ball.position.x,ball.position.z)=="green":set_club(7)
		save_progress()
	_draw_aim();hud.refresh()
func club_input_active()->bool:
	if not xr or not focused or menu_open or fitting_club or godview.active or club_radial.opened or equipment.stowed or course_guide.held:return false
	var controller:XRController3D=left if left_handed else right
	return controller.get_has_tracking_data() and (maxf(controller.get_float("grip"),controller.get_float("trigger"))>.55 or controller.is_button_pressed("trigger_click") or controller.is_button_pressed("grip_click"))
func club_collision_enabled()->bool:
	return club_input_active() and not ball.moving

func _swing() -> void:
	var now:=Time.get_ticks_usec()
	var dt:float=(now-last_swing_us)/1000000.0 if last_swing_us>0 else 0.0
	last_swing_us=now
	if origin.global_basis.z.angle_to(last_origin_basis.z)>.01:reset_swing();return
	last_origin_basis=origin.global_basis
	var controller:=left if left_handed else right
	var tip:=_update_club_pose()
	if dt<=0:return
	var active: bool=club_collision_enabled() and body.last_motion.length()<.2
	if not controller.get_has_tracking_data():swing.reset();contact_effects.valid=false;return
	var ground_event:Dictionary=contact_effects.sample_ground(physical_head.global_transform,head_shape,model,dt,club_input_active() and body.last_motion.length()<.2)
	if not ground_event.is_empty():controller.trigger_haptic_pulse("haptic",0,ground_event.strength,.055 if ground_event.hard else .025,0)
	var sample: Dictionary=swing.sample_pose(physical_head.global_transform,head_shape,ball.position,dt,active,ball.velocity,model)
	var observation:Dictionary=swing.last_sample.duplicate(true)
	observation.merge({"monotonic_us":now,"club":club_index,"face":-physical_head.global_basis.z.normalized(),"grip":controller.get_float("grip"),"trigger":controller.get_float("trigger"),"tracked":controller.get_has_tracking_data(),"focused":focused,"body_speed_m_s":body.last_motion.length(),"menu_open":menu_open,"fitting":fitting_club},true)
	if not active:observation.inactive_reason="tracking_lost" if not controller.get_has_tracking_data() else "grip_and_trigger_released" if not club_input_active() else "ball_moving" if ball.moving else "locomotion"
	telemetry.sample_swing(observation)
	# Walking or an in-flight ball is not an unarmed address pose to retain.
	if not active and (body.last_motion.length()>=.2 or ball.moving):swing.reset()
	var state:String=observation.get("status","")
	if active and state=="invalid_interval":status_text="Swing paused: tracking update gap. Wait for smooth tracking; no need to refit."
	if state!=last_swing_state and state in ["discontinuity","invalid_interval","inactive","priming"]:
		telemetry.record("swing_state",observation)
	last_swing_state=state
	if not sample.is_empty():
		sample.ball_spin=ball.spin
		strike(sample.velocity,sample.normal,sample)
func _release_pointer(hide_laser:=true) -> void:
	if is_instance_valid(pointer_laser) and hide_laser:pointer_laser.visible=false
	if pointer_down:
		var click:=InputEventMouseButton.new();click.position=pointer_coords;click.button_index=MOUSE_BUTTON_LEFT;click.pressed=false
		ui_viewport.push_input(click,true)
	pointer_down=false
func _pointer() -> void:
	var scroll_axis:=right.get_vector2("primary").y
	if absf(scroll_axis)>.2:hud.menu_scroll.scroll_vertical-=int(scroll_axis*650*get_physics_process_delta_time())
	pointer_dot.visible=false
	var ray:Dictionary=preload("res://addons/golfminus/scripts/core/menu_ray.gd").sample(self)
	if ray.is_empty():_release_pointer();return
	_pointer_beam(ray.origin,ray.origin+ray.direction*2.5)
	var inv:=ui_plane.global_transform.affine_inverse()
	var p:Vector3=inv*ray.aim_origin
	var d:Vector3=inv.basis*ray.direction
	if absf(d.z)<.001:_release_pointer(false);return
	var t: float=-p.z/d.z
	var hit:=p+d*t
	var coords:=Vector2((hit.x/2.3+.5)*1440,(.5-hit.y/1.4375)*900)
	var down: bool=right.get_float("trigger")>.6
	if t<=0 or coords.x<0 or coords.x>1440 or coords.y<0 or coords.y>900:_release_pointer(false);return
	pointer_dot.visible=true;pointer_dot.global_position=ui_plane.to_global(hit+Vector3(0,0,.015))
	_pointer_beam(ray.origin,pointer_dot.global_position)
	var motion:=InputEventMouseMotion.new();motion.position=coords;motion.global_position=coords;motion.relative=coords-pointer_coords
	motion.button_mask=MOUSE_BUTTON_MASK_LEFT if pointer_down else 0
	pointer_coords=coords;ui_viewport.push_input(motion,true)
	if down!=pointer_down:
		var click:=InputEventMouseButton.new();click.position=coords;click.button_index=MOUSE_BUTTON_LEFT;click.pressed=down
		pointer_down=down;ui_viewport.push_input(click,true)
func _pointer_beam(start:Vector3,end:Vector3) -> void:
	var segment:=end-start
	var up:=segment.normalized()
	var axis:=Vector3.RIGHT if absf(up.dot(Vector3.UP))>.99 else up.cross(Vector3.UP).normalized()
	pointer_laser.visible=true;pointer_laser.global_transform=Transform3D(Basis(axis,segment,axis.cross(up)),start+segment*.5)
func club_grip_pose(hand:int)->Transform3D:
	return calibration.pose(hand)*Transform3D(Basis.IDENTITY,club_offsets[hand])
func set_club_attachment(hand:int,field:String,axis:int,value:float)->void:
	if hand not in [0,1] or axis<0 or axis>2 or not is_finite(value):return
	if fitting_club:cancel_club_fit()
	match field:
		"offset":club_offsets[hand][axis]=clampf(value,-1,1)
		"rotation":club_rotations[hand][axis]=clampf(value,-180,180)
		"head":
			club_head_rotations[hand]=head_correction(hand)
			club_head_rotations[hand][axis]=clampf(value,-180,180);club_fitted[hand]=true;club_head_sources[hand]="explicit"
		"mounted":club_controller_mount[hand]=value!=0
		_:return
	_attachment_changed()
func reset_club_attachment(hand:int)->void:
	if hand not in [0,1]:return
	if fitting_club:cancel_club_fit()
	club_offsets[hand]=Vector3.ZERO;club_rotations[hand]=Vector3.ZERO;club_head_rotations[hand]=Vector3.ZERO
	club_fitted[hand]=false;club_controller_mount[hand]=false;club_head_sources[hand]="default"
	_attachment_changed()
func set_club_reach(value:float)->void:
	if not is_finite(value):return
	club_reach=clampf(value,.35,1.6);_attachment_changed()
func _attachment_changed()->void:
	reset_swing();swing.cooldown=.8
	if xr and is_instance_valid(club) and not equipment.stowed:_update_club_pose()
	hud.length_slider.set_value_no_signal(club_reach)
	_save_preferences()
	if is_instance_valid(hud.attachment_controls):hud.attachment_controls.refresh()
func _update_club_pose()->Vector3:
	var hand:=0 if left_handed else 1
	var rotation:Vector3=club_rotations[hand]
	var reach:float=club_reach
	if fitting_club and not fit_session.candidate.is_empty():
		rotation=fit_session.candidate.rotation;reach=fit_session.candidate.reach
	club.transform=club_grip_pose(hand)*Transform3D(Basis.from_euler(rotation*PI/180.0),Vector3.ZERO)
	var length:float=1.13 if club_index<2 else .86 if club_index==7 else .93
	club.scale=Vector3(reach,reach*float(CLUBS.BAG[club_index].length)/length,reach)
	apply_club_palm()
	_sync_physical_head()
	return physical_head.global_position
func apply_club_palm()->void:
	if equipment.stowed:return
	club.global_position=club_world_grip_pose().origin
func club_world_grip_pose()->Transform3D:
	var hand:=0 if left_handed else 1
	var controller:XRController3D=left if left_handed else right
	var pose:Transform3D=controller.global_transform*club_grip_pose(hand)
	if club_controller_mount[hand] or not is_instance_valid(host_game):return pose
	var grip=host_game.avatar.hand_grip_pose(left_handed)
	if grip is Transform3D:pose.origin=grip.origin+(controller.global_basis*calibration.pose(hand).basis)*club_offsets[hand]
	return pose
func head_correction(hand:int)->Vector3:
	if club_fitted[hand]:return club_head_rotations[hand]
	# Default grip-relative head orientation before an address fit.
	# Shaft corrections are independent; explicit face controls may override it.
	var lean:float=[32.0,31.0,29.0,27.0,26.0,26.0,26.0,20.0][club_index]
	return Vector3(0,0,lean if hand==0 else -lean)
func _sync_physical_head()->void:
	if not is_instance_valid(physical_head):return
	var length:float=1.13 if club_index<2 else .86 if club_index==7 else .93
	# Reach changes the shaft, not head size, loft, mass or contact geometry.
	var correction:Vector3=head_correction(0 if left_handed else 1)
	if fitting_club and not fit_session.candidate.is_empty():correction=fit_session.candidate.get("head_rotation",Vector3.ZERO)
	var grip_basis:Basis=club_world_grip_pose().basis.orthonormalized()
	if equipment!=null and equipment.stowed:grip_basis=club.global_basis.orthonormalized()
	var head_basis:=grip_basis*Basis.from_euler(correction*PI/180.0)*Basis(Vector3.RIGHT,head_shape.loft)
	physical_head.global_transform=Transform3D(head_basis,club.to_global(Vector3(0,-length,0))+head_basis.x*.055)
func begin_club_fit() -> void:
	godview.exit_view()
	club_radial.close()
	if not xr:status_text="Club fitting requires tracked VR controllers.";return
	if ball.moving:status_text="Wait for the ball to stop before fitting.";return
	if only_one_controller():set_hand(left.get_has_tracking_data(),true)
	toggle_menu(false)
	course_guide.dock();equipment.set_stowed(false)
	fit_session.begin(club_reach,club_rotations,0 if left_handed else 1,club_head_rotations,club_fitted)
	fit_session.baseline.head_sources=club_head_sources.duplicate()
	fitting_club=true;body.blocked=true;reset_swing();fit_clearance_elapsed=1.0
	status_text="Hold your natural address pose. Press trigger once, then hold steady."
func _fit_button(action:String,striking_hand:bool)->void:
	if action=="primary_click":fit_session.axis=posmod(fit_session.axis+1,3);return
	if action=="grip_click":fit_session.adjust_head=not fit_session.adjust_head;return
	if striking_hand:
		match action:
			"trigger_click":finish_club_fit()
			"ax_button":
				fit_accept_held[0 if left_handed else 1]=true
				accept_club_fit()
			"by_button":cancel_club_fit()
	else:
		match action:
			"ax_button":fit_session.axis=posmod(fit_session.axis+1,3)

func _update_fit_preview(dt:float)->void:
	var controller:=left if left_handed else right
	var other:=right if left_handed else left
	var tracked:=focused and controller.get_has_tracking_data()
	fit_session.sample_pose(club_world_grip_pose(),dt,tracked)
	if fit_session.capture_requested and not fit_session.stable_pose().is_empty():_capture_stable_club_fit()
	if tracked:
		var stick:=controller.get_vector2("primary")
		if other.get_has_tracking_data() and other.get_vector2("primary").length()>stick.length():stick=other.get_vector2("primary")
		if absf(stick.x)>.3 or absf(stick.y)>.3:
			if fit_session.candidate.is_empty():
				var hand:=0 if left_handed else 1
				fit_session.stage({"reach":club_reach,"rotation":club_rotations[hand],"head_rotation":head_correction(hand),"target":ball.position-aim_direction()*.075})
			fit_session.adjust(stick.x*35.0*dt if absf(stick.x)>.3 else 0.0,stick.y*.15*dt if absf(stick.y)>.3 else 0.0)
	var tip:=_update_club_pose()
	var target:Vector3=ball.position-aim_direction()*.075 if fit_session.candidate.is_empty() else fit_session.candidate.target
	var text:="Hold natural address pose\nPress trigger once, then hold steady"
	if fit_session.capture_requested:text="Capturing when steady · %.0f%%\nKeep your address pose; no need to press again"%minf(100,fit_session.stable_seconds/.4*100)
	if not fit_session.candidate.is_empty():
		text="PREVIEW · not saved\nHead to marker: %.1f cm · reach %.2f m\nTrigger: recapture · %s: accept · %s: cancel\nEither stick: %s %s / reach · click: axis · grip: head/handle"%[tip.distance_to(target)*100,float(CLUBS.BAG[club_index].length)*float(fit_session.candidate.reach),"X" if left_handed else "A","Y" if left_handed else "B","head" if fit_session.adjust_head else "handle",["yaw","pitch","roll"][fit_session.axis]]
	if ICONS.enabled:
		text="PREVIEW · not saved\nHead offset %.1f cm · reach %.2f m"%[tip.distance_to(target)*100,float(CLUBS.BAG[club_index].length)*float(fit_session.candidate.reach)] if not fit_session.candidate.is_empty() else "HOLD ADDRESS POSE"
	if ICONS.enabled and not fit_session.candidate.is_empty():text+="\n%s %s / reach · stick click: axis · grip: head/handle"%["Head" if fit_session.adjust_head else "Handle",["yaw","pitch","roll"][fit_session.axis]]
	fit_preview.prompts.show_entries([["capture","L trigger" if left_handed else "R trigger"],["accept","X" if left_handed else "A"],["cancel","Y" if left_handed else "B"],["fit","Stick: adjust"],["orbit","Grip: head/handle"]])
	if not fit_session.candidate.is_empty():
		fit_clearance_elapsed+=dt
		if fit_clearance_elapsed>=.1:
			fit_live_clearance=preload("res://addons/golfminus/scripts/golf/club_fit.gd").clearance(physical_head.global_transform,head_shape,world.surface_height)
			fit_clearance_elapsed=0.0
		var gap:=fit_live_clearance
		var ground_up:Vector3=preload("res://addons/golfminus/scripts/golf/club_fit.gd").ground_normal(physical_head.global_position,world.surface_height)
		text+="\nSole clearance: %.1f cm · loft to ground %.1f° (club %.0f°)"%[gap*100,rad_to_deg(asin(clampf((-physical_head.global_basis.z).dot(ground_up),-1,1))),rad_to_deg(head_shape.loft)]
		if gap<0:text+=" · head below turf; return to address pose"
	if fit_session.capture_requested:text="Waiting for steady address · %.0f%%\n"%minf(100,fit_session.stable_seconds/.4*100)+text
	if not tracked:text="Tracking unavailable · fit paused\n"+text
	if not ICONS.enabled or not (status_text.begins_with("Sole fitted above turf") or status_text.begins_with("Hold your natural address pose") or status_text.begins_with("Hold steady briefly")):
		text+="\n"+status_text
	fit_preview.update_guide(tip,-physical_head.global_basis.z,target,head.global_position,text,tracked)
func finish_club_fit() -> void:
	var controller:=left if left_handed else right
	if not fitting_club or not focused or not controller.get_has_tracking_data():return
	fit_session.capture_requested=true
	# Start after trigger curl, rather than fitting a one-frame button-press pose.
	fit_session.samples.clear();fit_session.stable_seconds=0
	status_text="Hold steady briefly. The preview will capture automatically."
func _capture_stable_club_fit()->void:
	var stable:Dictionary=fit_session.stable_pose()
	if stable.is_empty():return
	fit_session.capture_requested=false
	var hand:=0 if left_handed else 1
	var correction:Vector3=fit_session.candidate.get("head_rotation",head_correction(hand))
	var source:String=fit_session.candidate.get("head_source",club_head_sources[hand])
	var face:Vector3=-(stable.pose.basis.orthonormalized()*Basis.from_euler(correction*PI/180.0)*Basis(Vector3.RIGHT,head_shape.loft)).z
	var fit_direction:=Vector3(face.x,0,face.z).normalized()
	if fit_direction.length_squared()<.01:fit_direction=aim_direction()
	var fit:Dictionary=preload("res://addons/golfminus/scripts/golf/club_fit.gd").solve_grounded(stable.pose,ball.position,fit_direction,float(CLUBS.BAG[club_index].length),head_shape,world.surface_height,correction)
	if not fit_session.stage(fit):status_text="Address is out of reach. Move closer to the ball, then press trigger.";return
	fit_session.candidate.head_source="explicit" if source=="explicit" else "fit"
	fit_session.candidate.address_position=head.global_position
	telemetry.record("fit_preview",{"candidate":fit,"hand":hand})
	status_text="Sole fitted above turf. Check the preview, then accept to save."

func _apply_fit(values:Dictionary)->void:
	club_reach=values.reach;club_rotations.assign(values.rotations)
	club_head_rotations.assign(values.get("head_rotations",[Vector3.ZERO,Vector3.ZERO]))
	club_fitted.assign(values.get("fitted",[true,true]))
	club_head_sources.assign(values.get("head_sources",club_head_sources))
	hud.length_slider.set_value_no_signal(club_reach)
	hud.attachment_controls.refresh()
	reset_swing();swing.cooldown=.8
func accept_club_fit()->void:
	var controller:=left if left_handed else right
	if not fitting_club or not focused or not controller.get_has_tracking_data():return
	if fit_session.capture_requested:status_text="Still capturing. Hold your address pose briefly.";return
	if fit_session.candidate.has("capture_grip"):
		var solver=preload("res://addons/golfminus/scripts/golf/club_fit.gd")
		var pose:Transform3D=solver.head_pose(fit_session.candidate.capture_grip,fit_session.candidate,float(CLUBS.BAG[club_index].length),head_shape)
		var gap:float=solver.clearance(pose,head_shape,world.surface_height)
		# Validate mesh clearance, not a world-space face pitch: fitting must
		# preserve the independent head address frame selected by the player.
		if gap<-.001 or gap>.04:
			status_text="Adjusted sole is %.1f cm from turf. Adjust reach or recapture before saving."%(gap*100);return
	if fit_session.candidate.has("address_position"):remember_address(fit_session.candidate.address_position)
	var values:Dictionary=fit_session.accept()
	if values.is_empty():return
	telemetry.record("fit_accepted",values)
	_apply_fit(values);fitting_club=false;fit_preview.visible=false;body.blocked=menu_open
	_save_preferences()
	controller.trigger_haptic_pulse("haptic",0,.3,.07,0)
	status_text="Fit saved. Undo last fit is available in the clubhouse."
func cancel_club_fit()->void:
	telemetry.record("fit_cancelled",{})
	fit_session.cancel();fitting_club=false
	if is_instance_valid(fit_preview):fit_preview.visible=false
	body.blocked=menu_open;reset_swing()
	if xr and is_instance_valid(club):_update_club_pose()
	status_text="Preview cancelled. Previous club fit retained."
func undo_club_fit()->void:
	if fitting_club:cancel_club_fit()
	var values:Dictionary=fit_session.undo()
	if values.is_empty():status_text="No accepted fit to undo in this session.";return
	telemetry.record("fit_undone",values)
	_apply_fit(values);_save_preferences();status_text="Previous club fit restored."
func flip_club_face() -> void:
	var hand:=0 if left_handed else 1
	fit_session.undo_state={"reach":club_reach,"rotations":club_rotations.duplicate(),"head_rotations":club_head_rotations.duplicate(),"fitted":club_fitted.duplicate(),"head_sources":club_head_sources.duplicate()}
	club_head_rotations[hand]=(Basis.from_euler(head_correction(hand)*PI/180)*Basis(Vector3.UP,PI)).get_euler()*180/PI
	club_fitted[hand]=true;club_head_sources[hand]="explicit"
	toggle_menu(false);reset_swing();swing.cooldown=.8;_save_preferences()
	hud.attachment_controls.refresh()
	status_text="Club face reversed; handle attachment retained."
func _draw_aim() -> void:
	aim_mesh.visible=not godview.active and not ball.moving and not ball.holed
	if not aim_mesh.visible:return
	var mesh:=ImmediateMesh.new();mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var p: Vector3=ball.position
	for i in range(1,14):
		for t in [float(i)*.4,float(i)*.4+.20]:
			var pt: Vector3=p+aim_direction()*t;pt.y=model.height(pt.x,pt.z)+.035;mesh.surface_add_vertex(pt)
	mesh.surface_end();aim_mesh.mesh=mesh
	if not aim_mesh.material_override:
		var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_color=Color("ebd9a1");aim_mesh.material_override=mat
func _draw_trail() -> void:
	if trail_points.size()<2:return
	var mesh:=ImmediateMesh.new();mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for p in trail_points:mesh.surface_add_vertex(p)
	mesh.surface_end();trail.mesh=mesh
	if not trail.material_override:
		var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_color=Color("eec77d");trail.material_override=mat
func _impact_audio(speed: float) -> void:
	var bytes:=PackedByteArray();var rng:=RandomNumberGenerator.new();rng.seed=123
	for i in 3500:
		var t:=i/22050.0
		var value: float=(sin(t*TAU*(320 if club_index==7 else 1800))*.4+rng.randf_range(-.35,.35))*exp(-t*75)*clampf(speed/25,.1,.8)
		var n:=int(clampf(value,-1,1)*32767);bytes.append(n&255);bytes.append((n>>8)&255)
	var audio:=AudioStreamWAV.new();audio.format=AudioStreamWAV.FORMAT_16_BITS;audio.mix_rate=22050;audio.data=bytes
	sound.position=ball.position;sound.stream=audio;sound.play()
