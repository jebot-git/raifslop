extends Node3D
## World-space pictograms with compact physical-button labels underneath.
const Icons=preload("res://addons/golfminus/scripts/golf/pictograms.gd")
var signature:=""
func show_entries(entries:Array)->void:
	visible=Icons.enabled
	var key:=str(entries)
	if key==signature:return
	signature=key
	for child in get_children():remove_child(child);child.queue_free()
	for i in entries.size():
		var x:float=(i-(entries.size()-1)*.5)*.16
		var symbol:=Sprite3D.new();symbol.texture=Icons.texture(entries[i][0]);symbol.pixel_size=.00085;symbol.position=Vector3(x,0,0);symbol.shaded=false;add_child(symbol)
		var caption:=Label3D.new();caption.text=entries[i][1];caption.font_size=26;caption.pixel_size=.0009;caption.position=Vector3(x,-.079,.001);caption.modulate=Color("f4e6c5");add_child(caption)
