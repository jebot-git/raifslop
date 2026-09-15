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

func _draw() -> void:
	if game == null: return
	if vr_mode:
		_draw_vr()
		return
	var design := Vector2(1440, 900)
	scale_factor = size / design
	draw_set_transform(Vector2.ZERO, 0, scale_factor)
	card(Rect2(32, 28, 1376, 106))
	text_at("R / F", Vector2(58, 75), 24, mint, true)
	draw_line(Vector2(145, 50), Vector2(145, 112), Color("52645a"), 1)
	text_at("Real AI Fishing", Vector2(171, 77), 32, ink, true)
	text_at("G: field guide · Location, earnings and equipment", Vector2(173, 110), 12, muted)
	draw_circle(Vector2(1045, 65), 4, mint)
	text_at("OPENXR ACTIVE" if vr_mode else "DESKTOP PRACTICE", Vector2(1061, 70), 13, mint)

	if not vr_mode:
		card(Rect2(1030, 160, 378, 110))
		text_at("AVATAR & LOCATIONS   [ V ]", Vector2(1052, 194), 15, mint)
		text_at("WASD walk · Q/E turn · Middle-drag look", Vector2(1052, 225), 12, ink)
		text_at("Avatar, location · G: field guide", Vector2(1052, 252), 12, muted)
	var state: int = game.state
	var state_name: String = ["READY TO CAST", "CASTING", "WAIT FOR A BITE", "SET THE HOOK", "FISH ON", "CATCH LANDED", "FISH LOST"][state]
	card(Rect2(435, 560, 570, 112))
	text_at(state_name, Vector2(459, 588), 12, mint)
	var lines: PackedStringArray = game.message.split(" · +")[0].split("\n")
	for i in range(lines.size()):
		text_at(lines[i], Vector2(459, 619 + i * 25), 14, ink)
	if state == 4:
		card(Rect2(1040, 350, 368, 280))
		text_at("THE FIGHT", Vector2(1064, 382), 12, mint)
		text_at("%.1f m" % game.distance, Vector2(1064, 421), 30, ink, true)
		text_at("LINE TENSION", Vector2(1064, 454), 11, muted)
		draw_rect(Rect2(1064, 468, 320, 10), Color("243a34"))
		draw_rect(Rect2(1064 + 320 * 0.15, 468, 320 * 0.60, 10), Color("3d6652"))
		draw_circle(Vector2(1064 + 320 * game.tension, 473), 7, Color("ff916e") if game.tension > 0.8 else mint)
		text_at(game.reel_instruction(), Vector2(1064, 571), 13, Color("ffba80") if game.is_running() else mint)
		text_at("Keep the marker in the green band", Vector2(1064, 607), 12, muted)
		if game.cue >= 0:
			card(Rect2(485, 360, 470, 147), Color(0.07, 0.21, 0.16, 0.96))
			text_at((["← QUICK TUG LEFT", "QUICK TUG RIGHT →"][game.cue] if game.jump_time>0 else ["←  PULL LEFT · HOLD", "PULL RIGHT · HOLD  →", "↑  LIFT ROD · HOLD"][game.cue]), Vector2(515, 414), 25, mint)
			text_at(("JUMP · STOP REELING · QUICK SIDEWAYS TUG" if game.jump_time>0 else "Keep holding" if game.counter_active else "Pull farther, then hold"), Vector2(515, 457), 20, ink)
	if state == 3:
		card(Rect2(520, 350, 400, 130), Color("a55232"))
		text_at("BITE!", Vector2(641, 402), 34, ink, true)
		text_at("Lift now" if vr_mode else "Press SPACE to strike", Vector2(579, 443), 20)
	if game.is_fly_fishing():
		text_at("HOLD SPACE / RELEASE: fly cast · R: strip · ←: mend upstream" if not vr_mode else "BACK / FORWARD: cast · LEFT GRIP + PULL: strip · SWEEP LEFT: mend",Vector2(40,670),18,mint)
		if game.state==2:text_at("DRIFT QUALITY  %d%%" % int(game.fly.quality*100),Vector2(560,410),24,mint)
	card(Rect2(32, 698, 1376, 170))
	text_at("YOUR TACKLE", Vector2(56, 728), 11, muted)
	for i in range(game.bait_count()):
		var tile := bait_rect(i)
		var x := tile.position.x
		var y := tile.position.y
		var selected: bool = game.bait == i
		card(tile, Color("365747") if selected else Color("142b25"))
		draw_circle(Vector2(x + 16, y + 15), 4, mint if selected else muted)
		text_at("%d  %s" % [i + 1, game.bait_name(i)], Vector2(x + 28, y + 20), 14, mint if selected else ink)
		text_at(game.bait_hint(i), Vector2(x + 14, y + 39), 11, muted)
	var action: String = ("QUICK FLY CAST" if game.is_fly_fishing() else "CAST LINE") if state == 0 else ("RELEASE & CONTINUE" if state == 5 else ("TRY AGAIN" if state == 6 else "SPACE / STRIKE"))
	card(Rect2(897, 747, 483, 89), Color("a5dcb9") if state in [0, 5, 6] else Color("254537"))
	text_at(action, Vector2(937, 799), 20, Color("102e24") if state in [0, 5, 6] else ink)
	if not vr_mode:
		text_at("HOLD / RELEASE SPACE: fly cast · R: strip · LEFT: upstream mend · SPACE on take: strike" if game.is_fly_fishing() else "SPACE  cast / strike / release     •     R / left mouse reel · Shift faster     •     Arrow keys  counter     •     Right-drag  aim rod", Vector2(265, 889), 12, ink)
	else:
		text_at("TRIGGER: back / forward cast · LEFT GRIP + PULL: strip · SWEEP UPSTREAM: mend" if game.is_fly_fishing() else "Left X: bait   •   Right trigger: hold, swing, release   •   Left grip + circle: reel   •   Right A: release", Vector2(75, 889), 17, ink)
	if tracking_lost:
		card(Rect2(400, 330, 640, 170))
		text_at("Tracking paused", Vector2(450, 395), 30, ink, true)
		text_at("Bring both controllers into view to resume.", Vector2(450, 444), 18, muted)

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
	draw_set_transform(Vector2.ZERO, 0, size / Vector2(1000, 640))
	card(Rect2(0, 0, 1000, 640), Color(panel.r, panel.g, panel.b, 1.0))
	text_at("Real AI Fishing", Vector2(40, 64), 42, ink, true)
	text_at("ON THE LINE", Vector2(42, 109), 24, mint)
	draw_line(Vector2(40, 137), Vector2(960, 137), muted, 1)
	if not calibration_message.is_empty():
		text_at("BODY CALIBRATION", Vector2(40, 225), 36, mint)
		text_at(calibration_message, Vector2(40, 300), 25, ink)
		return
	if tracking_lost:
		text_at("Tracking paused", Vector2(40, 225), 36, ink)
		text_at("Bring both controllers into view.", Vector2(40, 280), 28, muted)
		return

	var lines: PackedStringArray = game.message.split(" · +")[0].split("\n")
	for i in range(lines.size()):
		text_at(lines[i], Vector2(40, 239 + i * 39), 24, ink)
	if game.state == 4:
		text_at("%.1f m   /   LINE TENSION" % game.distance, Vector2(40, 329), 30, ink)
		draw_rect(Rect2(40, 365, 920, 20), Color("233b31"))
		draw_rect(Rect2(178, 365, 552, 20), Color("3d7253"))
		draw_circle(Vector2(40 + game.tension * 920, 375), 15, Color("ff916e") if game.tension > 0.8 else mint)
		text_at(game.reel_instruction(), Vector2(40, 437), 30, mint)
		if game.cue >= 0:
			text_at((["← QUICK TUG LEFT", "QUICK TUG RIGHT →"][game.cue] if game.jump_time>0 else ["← PULL LEFT · HOLD", "PULL RIGHT · HOLD →", "↑ LIFT ROD · HOLD"][game.cue]), Vector2(40, 490), 32, ink)
			text_at(("JUMP · STOP REELING · QUICK SIDEWAYS TUG" if game.jump_time>0 else "Keep holding" if game.counter_active else "Pull farther, then hold"),Vector2(40,557),27,ink)
	elif game.state == 5:
		text_at("Hold LEFT GRIP: inspect fish in your hand.", Vector2(40, 366), 27, ink)
		text_at("Release grip: hang fish from the rod.", Vector2(40, 416), 27, ink)
		text_at("Either stick: rotate fish. RIGHT A: release.", Vector2(40, 466), 27, ink)
	if game.is_fly_fishing() and game.state==2:text_at("MEND LEFT · Natural drift %d%%" % int(game.fly.quality*100),Vector2(40,490),27,mint)
	if game.state != 4: text_at("STICKS: rotate catch   B: menu" if game.state == 5 else "LEFT STICK: walk   RIGHT STICK: turn   B: menu", Vector2(40, 554), 24, muted)
	text_at("LEFT X: bait   RIGHT A: release   LEFT HIP + GRIP: guide", Vector2(40, 603), 22, muted)
