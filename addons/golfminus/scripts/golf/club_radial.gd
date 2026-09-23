extends Node3D
## Tap to open/cancel; point to highlight and return to centre to equip.
const Icons=preload("res://addons/golfminus/scripts/golf/pictograms.gd")
var game:Node3D
var opened:=false
var choice:=-1
var armed:=false
var view:=SubViewport.new()
var canvas:Control
class Dial extends Control:
	var menu:Node
	func _draw()->void:
		var center:=Vector2(320,320)
		for index in 8:
			var angle:float=-PI/2+index*TAU/8
			var start:float=angle-PI/8+.025
			var points:=PackedVector2Array()
			for i in 17:points.append(center+Vector2.from_angle(start+i*(PI/4-.05)/16)*292)
			for i in range(16,-1,-1):points.append(center+Vector2.from_angle(start+i*(PI/4-.05)/16)*108)
			draw_colored_polygon(points,Color("355f50") if menu.choice==index else Color("122d29"))
			draw_arc(center,292,start,start+PI/4-.05,24,Color("edd6a0") if menu.choice==index else Color("648779"),3,true)
			var position:=center+Vector2.from_angle(angle)*202
			var title:String=menu.game.CLUBS.BAG[index].short
			if Icons.enabled:draw_texture_rect(Icons.texture(Icons.club(index)),Rect2(position-Vector2(38,55),Vector2(76,76)),false)
			draw_string(ThemeDB.fallback_font,position+Vector2(-67,47 if Icons.enabled else 8),title,HORIZONTAL_ALIGNMENT_CENTER,134,24,Color("edd6a0") if menu.game.club_index==index else Color("e5e4d0"))
		if Icons.enabled:
			draw_texture_rect(Icons.texture("accept" if menu.choice>=0 else "cancel"),Rect2(center-Vector2(32,45),Vector2(64,64)),false)
		else:draw_string(ThemeDB.fallback_font,center+Vector2(-100,-8),"CLUB BAG",HORIZONTAL_ALIGNMENT_CENTER,200,24,Color("e7c884"))
		draw_string(ThemeDB.fallback_font,center+Vector2(-100,24),("Centre to equip" if menu.choice>=0 else "Click to close"),HORIZONTAL_ALIGNMENT_CENTER,200,17,Color("e5e4d0"))
func setup(g:Node3D)->void:
	game=g;add_child(view);view.size=Vector2i(640,640);view.transparent_bg=true;view.render_target_update_mode=SubViewport.UPDATE_DISABLED
	canvas=Dial.new();canvas.menu=self;canvas.size=Vector2(640,640);view.add_child(canvas)
	var quad:=QuadMesh.new();quad.size=Vector2(.55,.55)
	var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.albedo_texture=view.get_texture()
	var panel:=MeshInstance3D.new();panel.mesh=quad;panel.material_override=material;panel.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(panel);hide()
func allowed()->bool:
	if game.godview.active or game.menu_open or game.fitting_club or game.course_guide.held or game.ball.moving or not game.focused:return false
	if is_instance_valid(game.host_activity) and game.host_activity.settings_open:return false
	if is_instance_valid(game.host_game) and is_instance_valid(game.host_game.shoulder_radio) and game.host_game.shoulder_radio.held:return false
	return not game.xr or game.pointer_controller().get_has_tracking_data()
func axis()->Vector2:
	return game.pointer_controller().get_vector2("primary") if game.xr else Vector2(float(Input.is_key_pressed(KEY_RIGHT))-float(Input.is_key_pressed(KEY_LEFT)),float(Input.is_key_pressed(KEY_UP))-float(Input.is_key_pressed(KEY_DOWN)))
func open()->bool:
	if opened or not allowed():return false
	opened=true;choice=-1;armed=axis().length()<.2
	global_transform=game.head.global_transform*Transform3D(Basis.IDENTITY,Vector3(0,-.1,-.8));show()
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;canvas.queue_redraw()
	game.body.radial_open=true;game.body.turn_reserved=true;game.body.catch_controls=true
	game.charging=false;game.power=0;game.reset_swing()
	return true
func point(input:Vector2)->void:
	if input.length()<.2:armed=true
	if armed and input.length()>.45:
		choice=posmod(roundi(atan2(input.x,input.y)/(TAU/8)),8)
	canvas.queue_redraw()
func close(confirm:=false)->void:
	if not opened:return
	var selected:=choice
	var valid:=allowed()
	opened=false;choice=-1;hide();view.render_target_update_mode=SubViewport.UPDATE_DISABLED
	game.body.radial_open=false;game.body.catch_controls=game.course_guide.held
	# Leave turn reservation until the right stick returns to centre.
	game.reset_swing()
	if confirm and valid and selected>=0 and selected!=game.club_index:game.set_club(selected)
func toggle()->void:
	if opened:close()
	else:open()
func release()->void:
	# Releasing the opening click never selects or dismisses the menu.
	pass
func update()->void:
	if not opened:return
	if not allowed():close();return
	var input:=axis()
	if not armed:
		if input.length()<.2:armed=true
		return
	if input.length()<.2 and choice>=0:close(true)
	elif input.length()>.45:point(input)
