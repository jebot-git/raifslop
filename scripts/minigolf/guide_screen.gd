extends Control
const Catalog=preload("res://scripts/minigolf/catalog.gd")
var guide:Node3D
var font:Font=ThemeDB.fallback_font
func label(text:String,at:Vector2,size:=26,color:=Color("dcecd7"))->void:
	while size>16 and font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>568:size-=1
	draw_string(font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)
func project(point:Vector2)->Vector2:
	var h:Dictionary=guide.activity.ball.layout
	var scale:float=minf(470/float(h.length),480/float(h.width))
	return Vector2(320,650)+point*scale
func _draw()->void:
	draw_rect(Rect2(0,0,640,840),Color("112b28"))
	var a=guide.activity
	if not a.active or a.ball.layout.is_empty():return
	if is_instance_valid(guide.photo_camera) and guide.photo_camera.active:
		preload("res://scripts/guide_camera_panel.gd").draw(self,guide);return
	label("FIELD GUIDE · MINIGOLF",Vector2(34,65),36,Color("a9dfb2"));label(Catalog.NAMES[a.course_id],Vector2(34,110),30)
	draw_line(Vector2(34,127),Vector2(606,127),Color("49715d"),2)
	match guide.page_index:
		0:draw_map()
		1:draw_card()
		2:draw_players()
	draw_line(Vector2(34,755),Vector2(606,755),Color("49715d"),2)
	label("‹  HOLE / SCORECARD / PLAYERS  ›",Vector2(56,804),25)
func draw_map()->void:
	var a=guide.activity;var h:Dictionary=a.ball.layout
	label("HOLE %02d · PAR %d · %d strokes"%[a.hole+1,h.par,a.strokes],Vector2(34,164),28)
	var corner:=project(Vector2(-h.width/2,-h.length));var end:=project(Vector2(h.width/2,0))
	draw_rect(Rect2(corner,end-corner),Color(Catalog.course(a.course_id).turf));draw_rect(Rect2(corner,end-corner),Color(Catalog.course(a.course_id).trim),false,5)
	var scale:float=(end.x-corner.x)/float(h.width)
	for hazard in h.hazards:
		var at:=Catalog.point(hazard.center);var size:=Catalog.point(hazard.size);draw_rect(Rect2(project(at-size/2),size*scale),Color("3989b1"))
	for bump in h.bumps:
		var axes:=Catalog.point(bump.get("axes",[bump.radius,bump.radius]))
		draw_set_transform(project(Catalog.point(bump.center)),0,axes)
		draw_circle(Vector2.ZERO,scale,Color(1,1,1,.16))
		draw_set_transform(Vector2.ZERO)
	for ramp in h.get("ramps",[]):
		var start:=project(Vector2(0,-float(ramp.start)));var finish:=project(Vector2(0,-float(ramp.end)))
		draw_rect(Rect2(Vector2(corner.x,finish.y),Vector2(end.x-corner.x,start.y-finish.y)),Color(1,1,1,.14) if ramp.height>0 else Color(0,0,0,.2))
		var arrow:=(start+finish)/2;var sign:=1 if ramp.height>0 else -1
		draw_line(arrow+Vector2(0,10*sign),arrow-Vector2(0,10*sign),Color.WHITE,2)
		draw_line(arrow-Vector2(0,10*sign),arrow+Vector2(-5,-3*sign),Color.WHITE,2)
		draw_line(arrow-Vector2(0,10*sign),arrow+Vector2(5,-3*sign),Color.WHITE,2)
	for rail in h.get("rails",[]):draw_line(project(Catalog.point(rail.a)),project(Catalog.point(rail.b)),Color(Catalog.course(a.course_id).trim),float(rail.radius)*2*scale)
	for obstacle in h.obstacles:draw_circle(project(Catalog.point(obstacle.center)),float(obstacle.radius)*scale,Color(Catalog.course(a.course_id).trim))
	draw_circle(project(Catalog.point(h.cup)),7,Color("101515"));draw_circle(project(a.ball.position),5,Color("fff4cc"))
	label(h.name,Vector2(34,705),27);label(h.hint,Vector2(34,738),20)
func draw_card()->void:
	var a=guide.activity
	label("HOLE    PAR    STROKES",Vector2(34,174),28)
	for i in 18:
		var col:=i/9;var row:=i%9
		var result:=str(a.scores[i]) if i<a.scores.size() else str(a.strokes)+"*" if i==a.hole and not a.finished else "—"
		label("%02d      %d      %s"%[i+1,Catalog.course(a.course_id).holes[i].par,result],Vector2(34+col*295,220+row*49),26,Color("f2d695") if i==a.hole else Color("dcecd7"))
	label("TOTAL %d · COURSE PAR %d"%[a.total_score(),preload("res://scripts/minigolf/handicap.gd").total_par(a.course_id)],Vector2(34,715),30)
func draw_players()->void:
	var a=guide.activity
	label("PARTICIPATING PLAYERS",Vector2(34,174),30)
	var roster:Array=a.service.view.get("roster",[]) if a.host.network.active else [{"name":"You","scores":a.scores,"present":true,"retired":false}]
	var row:=0
	for player in roster:
		if player.retired:continue
		var total:=0
		for score in player.scores:total+=maxi(0,int(score))
		label(player.name+ (" · away" if not player.present else ""),Vector2(34,225+row*61),27)
		label("%d strokes · %d / 18 holes"%[total,player.scores.size()],Vector2(34,251+row*61),22,Color("a9dfb2"));row+=1
	label("Fishing and BBQ players keep their own activity.",Vector2(34,737),21)
