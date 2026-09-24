extends Node3D
## Fixed clubhouse wall panel. Tracked aim and fingertip touch share one viewport.
var activity:Node
var viewport:=SubViewport.new()
var panel:=MeshInstance3D.new()
var label:=Label.new()
var start_button:Button
var solo_button:Button
var down:=false
var pointer:=MeshInstance3D.new()
var laser:=MeshInstance3D.new()
var last_hit:=Vector2(-100,-100)
var trigger_was_down:=false
var touching:=false
var roster:ScrollContainer
func setup(a:Node)->void:
	activity=a;name="ClubhouseCompetitionBoard"
	var pose:Transform3D=preload("res://addons/golfminus/scripts/golf/host_locations.gd").pose("golf_%s_clubhouse"%a.golf.course_id)
	global_position=pose.origin+Vector3(0,1.9,-4.3)
	viewport.size=Vector2i(960,640);viewport.transparent_bg=false;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(viewport)
	var background:=ColorRect.new();background.color=Color("112b28");background.size=Vector2(960,640);viewport.add_child(background)
	var box:=VBoxContainer.new();box.position=Vector2(36,24);box.size=Vector2(888,592);box.add_theme_constant_override("separation",18);viewport.add_child(box)
	roster=preload("res://scripts/ui/drag_scroll.gd").new();roster.custom_minimum_size.y=225;box.add_child(roster)
	label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.add_theme_font_size_override("font_size",26);roster.add_child(label)
	for entry in [["Start new solo round",a.start_play.bind("solo")],["Join competition",a.start_play.bind("competition")],["Start competition",a.start_competition],["Return to round",a.resume_course]]:
		var b:=Button.new();b.text=entry[0];b.custom_minimum_size.y=65;b.add_theme_font_size_override("font_size",26);box.add_child(b);b.pressed.connect(entry[1])
		if entry[0]=="Start competition":start_button=b
		if entry[0]=="Start new solo round":solo_button=b
	var mesh:=QuadMesh.new();mesh.size=Vector2(3.0,2.0);panel.mesh=mesh;add_child(panel)
	var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_texture=viewport.get_texture();panel.material_override=mat
	var backing:=MeshInstance3D.new();var frame:=BoxMesh.new();frame.size=Vector3(3.08,2.08,.055);backing.mesh=frame;backing.position.z=-.035;add_child(backing)
	var wood:=StandardMaterial3D.new();wood.albedo_color=Color("473728");wood.roughness=.8;backing.material_override=wood
	var dot:=SphereMesh.new();dot.radius=.009;dot.height=.018;pointer.mesh=dot;add_child(pointer)
	var beam:=CylinderMesh.new();beam.top_radius=.001;beam.bottom_radius=.001;beam.height=1;laser.mesh=beam;add_child(laser)
	var ink:=StandardMaterial3D.new();ink.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;ink.albedo_color=Color("b7ffd7");ink.no_depth_test=true
	pointer.material_override=ink;laser.material_override=ink;pointer.hide();laser.hide()
	refresh()
func refresh()->void:
	if not is_instance_valid(activity) or not activity.active or not is_instance_valid(activity.golf):return
	var a=activity
	label.text=a.golf.model.course.name+"\nCLUBHOUSE · Solo / group competition"
	start_button.disabled=true
	solo_button.text="Return to solo round" if a.enrolled() and a.service.view.mode=="solo" else "Start new solo round"
	if a.enrolled():
		var v:Dictionary=a.service.view
		label.text+="\n"+v.mode.capitalize()+" · HCP %d (estimate)"%v.handicap
		for player in v.roster:label.text+="\n%s · HCP %d · net %d"%[player.name,player.handicap,player.net]
		start_button.disabled=v.started or not v.owner or v.roster.size()<2
	else:label.text+="\nGather here, join competition, then the organiser starts."
func _process(_dt:float)->void:
	pointer.hide();laser.hide()
	if not is_instance_valid(activity) or not activity.active:return
	var g=activity.host
	var controller:XRController3D=activity.golf.pointer_controller()
	var pressed:bool=controller.get_has_tracking_data() and (controller.get_float("trigger")>.6 or controller.is_button_pressed("trigger_click"))
	if g.menu_open or activity.golf.godview.active:
		cancel_input();trigger_was_down=pressed;return
	var ray:Dictionary=preload("res://scripts/menu_ray.gd").sample(g)
	if ray.is_empty():cancel_input();trigger_was_down=pressed;return
	var origin:=to_local(ray.aim_origin);var direction:Vector3=global_basis.inverse()*ray.direction
	var hit:=Vector2(-100,-100)
	if absf(direction.z)>.00001:
		var t:float=-origin.z/direction.z
		var p:=origin+direction*t
		if t>0 and t<6 and absf(p.x)<=1.5 and absf(p.y)<=1.0:hit=Vector2((p.x/3.0+.5)*960,(.5-p.y/2.0)*640)
	var finger:=to_local(ray.origin)
	var touch:bool=g.xr and absf(finger.x)<1.5 and absf(finger.y)<1 and absf(finger.z)<(.055 if touching else .025)
	if touch:hit=Vector2((finger.x/3.0+.5)*960,(.5-finger.y/2.0)*640)
	if hit.x<0:
		cancel_input();trigger_was_down=pressed;return
	pointer.position=Vector3((hit.x/960-.5)*3,(.5-hit.y/640)*2,.012);pointer.show()
	var segment:Vector3=pointer.global_position-ray.origin
	if g.xr and segment.length()>.02:
		var up:=segment.normalized();var axis:=Vector3.RIGHT if absf(up.dot(Vector3.UP))>.99 else up.cross(Vector3.UP).normalized()
		laser.global_transform=Transform3D(Basis(axis,segment,axis.cross(up)),ray.origin+segment*.5);laser.show()
	# A trigger edge is routed once; entering the panel with a held trigger
	# cannot accidentally start a competition or a round.
	var next_down:=down
	if touch and not touching or pressed and not trigger_was_down:next_down=true
	if not touch and not pressed:next_down=false
	var motion:=InputEventMouseMotion.new();motion.position=hit;motion.global_position=hit;motion.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0;viewport.push_input(motion,true)
	var scroll_axis:float=preload("res://scripts/ui/scroll_router.gd").joystick_axis()
	if g.xr:
		for hand in [g.left,g.right]:
			var axis:float=-hand.get_vector2("primary").y
			if hand.get_has_tracking_data() and absf(axis)>absf(scroll_axis):scroll_axis=axis
	if absf(scroll_axis)>.2:preload("res://scripts/ui/scroll_router.gd").scroll(viewport,scroll_axis*650*_dt,roster)
	if next_down!=down:send_click(next_down,hit)
	last_hit=hit;trigger_was_down=pressed;touching=touch

func send_click(pressed:bool,hit:Vector2)->void:
	down=pressed
	var click:=InputEventMouseButton.new();click.position=hit;click.global_position=hit;click.button_index=MOUSE_BUTTON_LEFT;click.pressed=pressed;click.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0;viewport.push_input(click,true)

func cancel_input()->void:
	if down:send_click(false,Vector2(-100,-100))
	touching=false;last_hit=Vector2(-100,-100)
