extends Control
var game: Node
func _draw() -> void:
	if not is_instance_valid(game) or game.model.hole.is_empty():return
	var m=game.model
	var h: float=m.hole.length
	var k: float=(size.y-42)/h
	var center:=size.x*.5
	var path:=PackedVector2Array()
	for i in 51:
		var t:=i/50.0
		path.append(Vector2(center+m.center_x(t)*k, size.y-22-t*(size.y-42)))
	draw_polyline(path,Color("39523d"),float(m.hole.width)*2*k,true)
	draw_polyline(path,Color("617452"),float(m.hole.width)*1.35*k,true)
	var pin:=Vector2(center+m.center_x(1)*k,22)
	draw_circle(pin,float(m.hole.green_radius)*k,Color("8b9e6e"))
	for b in m.hole.bunkers:
		var p: Vector2=m.bunker_center(b)
		draw_circle(Vector2(center+p.x*k,size.y-22+p.y*k),float(b.radius)*k,Color("d2bd8e"))
	draw_line(pin,pin+Vector2(0,-12),Color("edcb89"),2,true)
	draw_colored_polygon(PackedVector2Array([pin+Vector2(0,-12),pin+Vector2(9,-9),pin+Vector2(0,-6)]),Color("edcb89"))
	var bp: Vector3=m.to_hole(game.ball.position)
	draw_circle(Vector2(center+bp.x*k,size.y-22+bp.z*k),4,Color("fff6df"))
	var dir: Vector3=m.to_hole(game.ball.position+game.aim_direction())-bp
	var p:=Vector2(center+bp.x*k,size.y-22+bp.z*k)
	draw_line(p,p+Vector2(dir.x,dir.z)*26,Color("e6c88a"),1,true)
