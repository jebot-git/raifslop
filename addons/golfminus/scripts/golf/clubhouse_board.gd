extends Node3D
## Fixed clubhouse wall panel. Desktop centre-ray and VR trigger share one viewport.
var activity:Node
var viewport:=SubViewport.new()
var panel:=MeshInstance3D.new()
var label:=Label.new()
var start_button:Button
var down:=false
func setup(a:Node)->void:
	activity=a;name="ClubhouseCompetitionBoard"
	var pose:Transform3D=preload("res://addons/golfminus/scripts/golf/host_locations.gd").pose("golf_%s_clubhouse"%a.golf.course_id)
	global_position=pose.origin+Vector3(0,1.9,-4.3)
	viewport.size=Vector2i(960,640);viewport.transparent_bg=false;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(viewport)
	var background:=ColorRect.new();background.color=Color("112b28");background.size=Vector2(960,640);viewport.add_child(background)
	var box:=VBoxContainer.new();box.position=Vector2(36,24);box.size=Vector2(888,592);box.add_theme_constant_override("separation",18);viewport.add_child(box)
	var roster:=ScrollContainer.new();roster.custom_minimum_size.y=225;box.add_child(roster)
	label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.add_theme_font_size_override("font_size",26);roster.add_child(label)
	for entry in [["Play solo",a.start_play.bind("solo")],["Join competition",a.start_play.bind("competition")],["Start competition",a.start_competition],["Return to round",a.resume_course]]:
		var b:=Button.new();b.text=entry[0];b.custom_minimum_size.y=65;b.add_theme_font_size_override("font_size",26);box.add_child(b);b.pressed.connect(entry[1])
		if entry[0]=="Start competition":start_button=b
	var mesh:=QuadMesh.new();mesh.size=Vector2(3.0,2.0);panel.mesh=mesh;add_child(panel)
	var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_texture=viewport.get_texture();panel.material_override=mat
	var backing:=MeshInstance3D.new();var frame:=BoxMesh.new();frame.size=Vector3(3.08,2.08,.055);backing.mesh=frame;backing.position.z=-.035;add_child(backing)
	var wood:=StandardMaterial3D.new();wood.albedo_color=Color("473728");wood.roughness=.8;backing.material_override=wood
	refresh()
func refresh()->void:
	if not is_instance_valid(activity) or not activity.active or not is_instance_valid(activity.golf):return
	var a=activity
	label.text=a.golf.model.course.name+"\nCLUBHOUSE · Solo / group competition"
	start_button.disabled=true
	if a.enrolled():
		var v:Dictionary=a.service.view
		label.text+="\n"+v.mode.capitalize()+" · HCP %d (estimate)"%v.handicap
		for player in v.roster:label.text+="\n%s · HCP %d · net %d"%[player.name,player.handicap,player.net]
		start_button.disabled=v.started or not v.owner or v.roster.size()<2
	else:label.text+="\nGather here, join competition, then the organiser starts."
func _process(_dt:float)->void:
	if not is_instance_valid(activity) or not activity.active:return
	var g=activity.host
	if g.menu_open or activity.golf.godview.active:return
	var ray:Transform3D=g.right.global_transform if g.xr else g.head.global_transform
	var origin:=to_local(ray.origin);var direction:=global_basis.inverse()*(-ray.basis.z)
	var pressed:bool=g.right.get_float("trigger")>.6 if g.xr else Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var hit:=Vector2(-100,-100)
	if absf(direction.z)>.00001:
		var t:float=-origin.z/direction.z
		var p:=origin+direction*t
		if t>0 and t<6 and absf(p.x)<=1.5 and absf(p.y)<=1.0:hit=Vector2((p.x/3.0+.5)*960,(.5-p.y/2.0)*640)
	var motion:=InputEventMouseMotion.new();motion.position=hit;motion.global_position=hit;motion.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0;viewport.push_input(motion,true)
	if pressed!=down:
		var click:=InputEventMouseButton.new();click.position=hit;click.global_position=hit;click.button_index=MOUSE_BUTTON_LEFT;click.pressed=pressed;viewport.push_input(click,true);down=pressed
