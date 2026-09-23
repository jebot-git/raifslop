extends Control
## Fishing field-guide screen dimensions, palette and hierarchy, with live golf data.
const Icons=preload("res://addons/golfminus/scripts/golf/pictograms.gd")
const COLORS={"fairway":Color("557b53"),"green":Color("91b77b"),"fringe":Color("759362"),"rough":Color("344f38"),"sand":Color("d2bd8e"),"water":Color("347580"),"out":Color("223d35")}
var guide:Node3D
var font:=ThemeDB.fallback_font
var summary:=""
var map_texture:ImageTexture
var map_key:=""
var world_bounds:=Rect2()
var map_rect:=Rect2()
func label(value:String,at:Vector2,pixels:int,color:=Color("dcecd7"))->void:
	var fitted:=pixels
	while fitted>18 and font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,fitted).x>568:fitted-=1
	draw_string(font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,fitted,color)
func ball_lie_name()->String:
	var g=guide.game
	var lie:String=g.model.lie(g.ball.position.x,g.ball.position.z)
	return "Out of bounds" if lie=="out" else lie.capitalize()
func refresh()->void:
	var g=guide.game
	if g.model.hole.is_empty():return
	var m=g.model
	summary="HOLE %02d · PAR %d · %.0f m to pin"%[g.round_state.hole+1,m.hole.par,Vector2(g.ball.position.x-m.pin().x,g.ball.position.z-m.pin().z).length()] if guide.page_index==0 else "COURSE TRACKER · %s · %d / 18 · %d strokes"%[m.course.name,g.round_state.scores.size(),g.round_state.total()]
	if guide.page_index==0:summary+=" · %s · %s · %d strokes"%[ball_lie_name(),g.CLUBS.BAG[g.club_index].name,g.round_state.strokes]
	var key:String=str(m.course.id)+":"+(str(m.course.layout.get("revision",0)) if m.connected else str(m.index))
	if key!=map_key:_build_map(key)
	queue_redraw()
func _build_map(key:String)->void:
	var m=guide.game.model
	world_bounds=m.course_bounds() if m.connected else m.map_bounds()
	var scale:float=minf(572/world_bounds.size.x,430/world_bounds.size.y)
	var dimensions:=world_bounds.size*scale
	map_rect=Rect2(Vector2(320,403)-dimensions*.5,dimensions)
	var height:=512
	var width:=maxi(96,roundi(height*world_bounds.size.x/world_bounds.size.y))
	var image:=Image.create(width,height,false,Image.FORMAT_RGBA8)
	for y in height:
		for x in width:
			var point:Vector2=world_bounds.position+Vector2((x+.5)/width,(y+.5)/height)*world_bounds.size
			image.set_pixel(x,y,COLORS[m.lie(point.x,point.y)])
	map_texture=ImageTexture.create_from_image(image);map_key=key
func project(point:Vector3)->Vector2:
	var uv:=(Vector2(point.x,point.z)-world_bounds.position)/world_bounds.size
	return map_rect.position+uv.clamp(Vector2.ZERO,Vector2.ONE)*map_rect.size
func _draw()->void:
	draw_rect(Rect2(0,0,640,840),Color("112b28"))
	if not is_instance_valid(guide) or guide.game.model.hole.is_empty():return
	if is_instance_valid(guide.photo_camera) and guide.photo_camera.active:
		preload("res://scripts/guide_camera_panel.gd").draw(self,guide);return
	var g=guide.game
	label("FIELD GUIDE",Vector2(34,65),42,Color("a9dfb2"))
	label(g.model.course.name,Vector2(36,108),27)
	draw_line(Vector2(34,127),Vector2(606,127),Color("49715d"),2)
	if guide.page_index==0:_draw_map()
	else:_draw_progress()
	draw_line(Vector2(34,738),Vector2(606,738),Color("49715d"),2)
	label("%02d / 02"%[guide.page_index+1],Vector2(277,774),23)
	label("Guide-hand trigger: camera" if g.xr else "C: camera · J: close",Vector2(155,835),20)
	if Icons.enabled:
		for entry in [["left",Vector2(38,750)],["grip",Vector2(291,788)],["right",Vector2(552,750)]]:draw_texture_rect(Icons.texture(entry[0]),Rect2(entry[1],Vector2(42,42)),false)
		label(("B" if g.left_handed else "Y") if g.xr else "Left",Vector2(94,780),24)
		label(("A" if g.left_handed else "X") if g.xr else "Right",Vector2(513,780),24)
	else:
		label("‹  MAP / COURSE  ›",Vector2(175,808),23)
func _draw_map()->void:
	var g=guide.game
	var m=g.model
	label("HOLE %02d  ·  PAR %d"%[g.round_state.hole+1,m.hole.par],Vector2(36,165),27,Color("a9dfb2"))
	var distance:float=Vector2(g.ball.position.x-m.pin().x,g.ball.position.z-m.pin().z).length()
	label("%.0f m"%distance,Vector2(469,165),30,Color("f2d695"))
	if map_texture==null:return
	draw_texture_rect(map_texture,map_rect,false)
	draw_rect(map_rect,Color("49715d"),false,2)
	if m.connected:
		for i in m.course.holes.size():
			var end:=project(m.pin_for(i));var start:=project(m.tee_for(i))
			if m.course.holes[i].get("routing",{}).has("path"):
				var path:=PackedVector2Array()
				var routing:Dictionary=m.course.holes[i].routing
				for p in routing.get("play_path",routing.path):path.append(project(Vector3(p[0],0,p[1])))
				draw_polyline(path,Color("7aa489"),1,true)
				for branch in routing.get("tee_paths",{}).values():
					var connector:=PackedVector2Array()
					for p in branch:connector.append(project(Vector3(p[0],0,p[1])))
					if connector.size()>1:draw_polyline(connector,Color("7aa489"),1,true)
			else:draw_line(start,end,Color("7aa489"),1,true)
			draw_string(font,end+Vector2(3,-3),str(i+1),HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("f6d888") if i==m.index else Color("dcecd7"))
	var ball:=project(g.ball.position);var pin:=project(m.pin())
	# Dotted target bearing is distinct from the short solid aiming arrow.
	for i in 16:
		draw_line(ball.lerp(pin,i/16.0),ball.lerp(pin,(i+.45)/16.0),Color("ebd39b"),2,true)
	var trace:=PackedVector2Array()
	for point in g.trail_points:trace.append(project(point))
	if trace.size()>1:draw_polyline(trace,Color("f7b15d"),3,true)
	var aim:Vector2=project(g.ball.position+g.aim_direction()*minf(50,distance))-ball
	if aim.length()>3:
		draw_line(ball,ball+aim,Color("edf7ce"),3,true)
		var side:=aim.normalized().orthogonal()*5
		draw_colored_polygon(PackedVector2Array([ball+aim,ball+aim-aim.normalized()*12+side,ball+aim-aim.normalized()*12-side]),Color("edf7ce"))
	var tee:=project(m.tee(g.tee_kind));draw_rect(Rect2(tee-Vector2(5,3),Vector2(10,6)),Color("d9e4c6"))
	var player:=project(g.head.global_position)
	var facing:Vector3=-g.head.global_basis.z
	var forward:=Vector2(facing.x,facing.z).normalized()
	if forward.length()<.1:forward=Vector2.UP
	var right:=forward.orthogonal()
	draw_colored_polygon(PackedVector2Array([player+forward*12,player-forward*8+right*7,player-forward*8-right*7]),Color("7de1da"))
	draw_circle(ball,7,Color("112b28"));draw_circle(ball,5,Color("fff4cc"))
	draw_line(pin,pin+Vector2(0,-25),Color("f6d888"),3,true)
	draw_colored_polygon(PackedVector2Array([pin+Vector2(0,-25),pin+Vector2(18,-19),pin+Vector2(0,-13)]),Color("f6d888"))
	# Brief shape/colour legend keeps the map usable without text-heavy directions.
	draw_colored_polygon(PackedVector2Array([Vector2(48,637),Vector2(40,652),Vector2(56,652)]),Color("7de1da"));label("You",Vector2(67,652),23)
	draw_circle(Vector2(232,645),5,Color("fff4cc"));label("Ball",Vector2(248,652),23)
	draw_line(Vector2(427,653),Vector2(427,636),Color("f6d888"),2,true)
	draw_colored_polygon(PackedVector2Array([Vector2(427,636),Vector2(440,640),Vector2(427,644)]),Color("f6d888"))
	label("Pin",Vector2(452,652),23,Color("f6d888"))
	label("%s  ·  %s  ·  %d strokes"%[g.CLUBS.BAG[g.club_index].name,ball_lie_name(),g.round_state.strokes],Vector2(36,694),28)
	if m.surface!=null:label("© OpenStreetMap · Copernicus / Open-Meteo",Vector2(38,621),18)
	label("Wind %.1f m/s  ·  solid: aim  /  dots: pin"%m.wind().length() if world_bounds.has_point(Vector2(g.ball.position.x,g.ball.position.z)) else "Ball beyond map edge",Vector2(36,726),21)
func _draw_progress()->void:
	var g=guide.game
	label("COURSE TRACKER",Vector2(36,176),30,Color("a9dfb2"))
	label("%02d / 18 completed"%g.round_state.scores.size(),Vector2(36,222),29)
	var handicap:int=g.host_activity.service.view.handicap if is_instance_valid(g.host_activity) and g.host_activity.enrolled() else g.round_state.handicap
	label("%d strokes · HCP %d*"%[g.round_state.total(),handicap],Vector2(36,267),32,Color("a9dfb2"))
	for i in 18:
		var x:=36+(i%3)*193;var y:=324+(i/3)*62
		var value:String=("F" if g.round_state.scores[i]<0 else str(g.round_state.scores[i])) if i<g.round_state.scores.size() else "—"
		label("%02d   %s"%[i+1,value],Vector2(x,y),28,Color("f2d695") if i==g.round_state.hole else Color("dcecd7"))
	label(g.model.hole.name,Vector2(36,718),24)
