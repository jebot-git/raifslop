extends Control
signal bait_selected(index: int)
signal action_pressed
signal avatar_requested
var game
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
	text_at("FIELD SESSION  01     /     LAKESIDE", Vector2(173, 110), 12, muted)
	draw_circle(Vector2(1045, 65), 4, mint)
	text_at("OPENXR ACTIVE" if vr_mode else "DESKTOP PRACTICE", Vector2(1061, 70), 13, mint)
	text_at("%02d  catches recorded" % game.catches, Vector2(1060, 105), 14, muted)
	if not vr_mode:
		card(Rect2(1030, 160, 378, 110))
		text_at("AVATAR & MOVEMENT   [ V ]", Vector2(1052, 194), 15, mint)
		text_at("WASD walk · Q/E turn · Middle-drag look", Vector2(1052, 225), 12, ink)
		text_at("Choose a VRM · Up to 25 MB", Vector2(1052, 252), 12, muted)
		card(Rect2(32, 160, 295, 143))
		text_at("THE WATER IS YOURS", Vector2(54, 190), 11, mint)
		text_at("A moment by the lake", Vector2(54, 224), 20, ink, true)
		text_at("360° photographed surroundings", Vector2(54, 256), 13, muted)
		text_at("Morning light · Freshwater", Vector2(54, 280), 13, muted)
	var state: int = game.state
	var state_name: String = ["READY TO CAST", "CASTING", "WAIT FOR A BITE", "SET THE HOOK", "FISH ON", "CATCH LANDED", "FISH LOST"][state]
	card(Rect2(435, 560, 570, 112))
	text_at(state_name, Vector2(459, 588), 12, mint)
	var lines: PackedStringArray = game.message.split("\n")
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
		text_at("STAMINA", Vector2(1064, 512), 11, muted)
		draw_rect(Rect2(1064, 526, 320 * game.stamina, 5), muted)
		text_at("FISH RUNNING · STOP REELING" if game.is_running() else "REEL STEADILY", Vector2(1064, 571), 13, Color("ffba80") if game.is_running() else mint)
		text_at("Keep the marker in the green band", Vector2(1064, 607), 12, muted)
		if game.cue >= 0:
			card(Rect2(485, 360, 470, 147), Color(0.07, 0.21, 0.16, 0.96))
			text_at(["←  SWEEP LEFT", "SWEEP RIGHT  →", "↑  LIFT THE ROD"][game.cue], Vector2(515, 414), 25, mint)
			text_at("Counter the fish's pull", Vector2(515, 446), 16, ink)
			draw_rect(Rect2(515, 470, 410 * maxf(0, game.cue_time / 2.2), 4), mint)
	if state == 3:
		card(Rect2(520, 350, 400, 130), Color("a55232"))
		text_at("BITE!", Vector2(641, 402), 34, ink, true)
		text_at("Lift now" if vr_mode else "Press SPACE to strike", Vector2(579, 443), 20)
	card(Rect2(32, 698, 1376, 170))
	text_at("YOUR TACKLE", Vector2(56, 728), 11, muted)
	for i in range(3):
		var x := 56.0 + i * 267
		var selected: bool = game.bait == i
		card(Rect2(x, 747, 251, 89), Color("365747") if selected else Color("142b25"))
		draw_circle(Vector2(x + 24, 774), 7, mint if selected else muted)
		text_at("%d  %s" % [i + 1, game.BAITS[i]], Vector2(x + 43, 779), 16, mint if selected else ink)
		text_at(["European perch", "Common carp", "Northern pike"][i], Vector2(x + 18, 815), 12, muted)
	var action: String = "CAST LINE" if state == 0 else ("RELEASE & CONTINUE" if state == 5 else ("TRY AGAIN" if state == 6 else "SPACE / STRIKE"))
	card(Rect2(897, 747, 483, 89), Color("a5dcb9") if state in [0, 5, 6] else Color("254537"))
	text_at(action, Vector2(937, 799), 20, Color("102e24") if state in [0, 5, 6] else ink)
	if not vr_mode:
		text_at("SPACE  cast / strike / release     •     Hold R or left mouse  reel     •     Arrow keys  counter     •     Right-drag  aim rod", Vector2(265, 889), 12, ink)
	else:
		text_at("Left X: bait   •   Right trigger: hold, swing, release   •   Left grip + circle: reel   •   Right A: release", Vector2(75, 889), 17, ink)
	if tracking_lost:
		card(Rect2(400, 330, 640, 170))
		text_at("Tracking paused", Vector2(450, 395), 30, ink, true)
		text_at("Bring both controllers into view to resume.", Vector2(450, 444), 18, muted)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = event.position / scale_factor
		if Rect2(1030, 160, 378, 110).has_point(p):
			avatar_requested.emit()
			accept_event()
		for i in range(3):
			if Rect2(56 + i * 267, 747, 251, 89).has_point(p):
				bait_selected.emit(i)
				accept_event()
		if Rect2(897, 747, 483, 89).has_point(p):
			action_pressed.emit()
			accept_event()

func _draw_vr() -> void:
	draw_set_transform(Vector2.ZERO, 0, size / Vector2(1000, 640))
	card(Rect2(0, 0, 1000, 640))
	text_at("Real AI Fishing", Vector2(40, 64), 42, ink, true)
	text_at("LAKESIDE   /   %d CATCHES" % game.catches, Vector2(42, 109), 24, mint)
	draw_line(Vector2(40, 137), Vector2(960, 137), muted, 1)
	if tracking_lost:
		text_at("Tracking paused", Vector2(40, 225), 36, ink)
		text_at("Bring both controllers into view.", Vector2(40, 280), 28, muted)
		return
	text_at("BAIT   " + game.BAITS[game.bait], Vector2(40, 184), 30, mint)
	var lines: PackedStringArray = game.message.split("\n")
	for i in range(lines.size()):
		text_at(lines[i], Vector2(40, 239 + i * 39), 24, ink)
	if game.state == 4:
		text_at("%.1f m   /   %d%% stamina" % [game.distance, game.stamina * 100], Vector2(40, 329), 30, ink)
		draw_rect(Rect2(40, 365, 920, 20), Color("233b31"))
		draw_rect(Rect2(178, 365, 552, 20), Color("3d7253"))
		draw_circle(Vector2(40 + game.tension * 920, 375), 15, Color("ff916e") if game.tension > 0.8 else mint)
		text_at("FISH RUNNING — EASE OFF" if game.is_running() else "REEL STEADILY", Vector2(40, 437), 30, mint)
		if game.cue >= 0:
			text_at(["← SWEEP LEFT", "SWEEP RIGHT →", "↑ LIFT THE ROD"][game.cue], Vector2(40, 490), 36, ink)
			draw_rect(Rect2(40, 510, 920 * maxf(0, game.cue_time / 2.2), 6), mint)
	else:
		text_at("Hold right trigger, swing forward, release to cast.", Vector2(40, 366), 27, ink)
		text_at("Bite: lift rod. Fight: follow the direction cue.", Vector2(40, 416), 27, ink)
		text_at("Reel: hold left grip beside the crank and circle.", Vector2(40, 466), 27, ink)
	text_at("LEFT STICK: walk   RIGHT STICK: turn   B: avatar", Vector2(40, 554), 24, muted)
	text_at("LEFT X: change bait     RIGHT A: release / retry", Vector2(40, 603), 24, muted)
