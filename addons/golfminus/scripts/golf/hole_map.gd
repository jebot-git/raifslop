extends Control
## North-up whole-course projection shared with the field guide's surface data.
var game:Node
var bounds:=Rect2()
var rect:=Rect2()
var texture:ImageTexture
var key:=""
func project(p:Vector3)->Vector2:
	return rect.position+(Vector2(p.x,p.z)-bounds.position)/bounds.size*rect.size
func prepare()->void:
	if not is_instance_valid(game) or game.model.hole.is_empty():return
	var m=game.model
	var next_key:String=m.course.id+str(size)
	if key!=next_key:
		bounds=m.course_bounds() if m.connected else m.map_bounds()
		var scale:float=minf((size.x-8)/bounds.size.x,(size.y-8)/bounds.size.y)
		rect=Rect2((size-bounds.size*scale)*.5,bounds.size*scale)
		var image:=Image.create(192,192,false,Image.FORMAT_RGBA8)
		for y in 192:
			for x in 192:
				var p:Vector2=bounds.position+Vector2((x+.5)/192,(y+.5)/192)*bounds.size
				image.set_pixel(x,y,preload("res://addons/golfminus/scripts/golf/course_guide_screen.gd").COLORS[m.lie(p.x,p.y)])
		texture=ImageTexture.create_from_image(image);key=next_key

func _draw()->void:
	prepare()
	if texture==null:return
	var m=game.model
	draw_texture_rect(texture,rect,false)
	if m.connected:
		for i in 18:
			var path:=PackedVector2Array()
			for p in m.course.holes[i].get("routing",{}).get("path",[]):path.append(project(Vector3(p[0],0,p[1])))
			if path.size()>1:draw_polyline(path,Color("f6d888") if i==m.index else Color("8aab83"),2 if i==m.index else 1,true)
			draw_string(ThemeDB.fallback_font,project(m.pin_for(i)),str(i+1),HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color.WHITE)
	var pin:=project(m.pin());var ball:=project(game.ball.position)
	draw_line(ball,pin,Color("f6d888"),1,true);draw_circle(pin,3,Color("f6d888"));draw_circle(ball,3,Color.WHITE)
	draw_circle(project(game.head.global_position),3,Color("7de1da"))
