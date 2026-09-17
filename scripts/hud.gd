extends Control
signal bait_selected(index: int)
signal action_pressed
signal avatar_requested
var calibration_message := ""
var game
var location_mood := "Open water · Bright morning"
var vr_mode := false
var tracking_lost := false
var font := SystemFont.new()
var title_font := SystemFont.new()
var ink := Color("f0eee1")
var muted := Color("afc5bd")
var mint := Color("9fdfbd")
var panel := Color(0.035, 0.085, 0.075, 0.94)
var scale_factor := Vector2.ONE

func _ready() -> void:
	font.font_names = PackedStringArray(["DejaVu Sans"])
	title_font.font_names = PackedStringArray(["DejaVu Serif"])
	mouse_filter = Control.MOUSE_FILTER_PASS

func text_at(value: String, pos: Vector2, size_px := 16, color := Color("f0eee1"), serif := false) -> void:
	draw_string(title_font if serif else font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)

func card(rect: Rect2, color: Color = panel) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	draw_style_box(style, rect)

func icon(key:String,rect:Rect2)->void:
	if not preload("res://scripts/ui/pictograms.gd").enabled:return
	draw_texture_rect(preload("res://scripts/ui/pictograms.gd").texture(key),rect,false)
func _draw() -> void:
	if game==null:return
	if vr_mode:
		_draw_vr();return
	scale_factor=size/Vector2(1440,900)
	draw_set_transform(Vector2.ZERO,0,scale_factor)
	icon("menu",Rect2(1320,175,56,56))
	var state:int=game.state
	var symbol:String=["cast","cast","fish","up","reel","fish","lost"][state]
	if state==4 and game.cue>=0:symbol=["left","right","up"][game.cue]
	elif state==4 and game.is_running():symbol="stop"
	icon("tracking" if tracking_lost else symbol,Rect2(682,550,76,76))
	if state==4:
		draw_rect(Rect2(560,637,320,8),Color("243a34"))
		draw_rect(Rect2(608,637,192,8),Color("3d6652"))
		draw_circle(Vector2(560+320*game.tension,641),6,Color("ff916e") if game.tension>.8 else mint)
	if state==5 and not game.journal.is_empty():
		var fish:Dictionary=game.journal.back()
		text_at("%s · %.0f cm · %.2f kg"%[fish.name,fish.length,fish.weight],Vector2(520,668),20)
	for i in game.bait_count():
		var tile:=bait_rect(i)
		card(tile,Color("365747") if game.bait==i else panel)
		text_at(game.bait_name(i),tile.position+Vector2(18,31),16,mint if game.bait==i else ink)
	icon("fish" if state==5 else "cast",Rect2(1070,760,68,68))

static func bait_rect(index: int) -> Rect2:
	return Rect2(56 + (index % 3) * 267, 742 + (index / 3) * 56, 251, 50)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = event.position / scale_factor
		if Rect2(1030, 160, 378, 110).has_point(p):
			avatar_requested.emit()
			accept_event()
		for i in range(game.bait_count()):
			if bait_rect(i).has_point(p):
				bait_selected.emit(i)
				accept_event()
		if Rect2(897, 747, 483, 89).has_point(p):
			action_pressed.emit()
			accept_event()

func _draw_vr() -> void:
	# VR uses the rod-mounted pictogram and catch/bait labels. Never render
	# legacy instructional panels, even if a caller makes this Control visible.
	draw_set_transform(Vector2.ZERO,0,size/Vector2(1000,640))
	if tracking_lost:icon("tracking",Rect2(468,288,64,64))
