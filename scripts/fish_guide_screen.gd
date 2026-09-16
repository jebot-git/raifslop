extends Control
const Icons = preload("res://scripts/fish_guide_icons.gd")
var guide
var font := ThemeDB.fallback_font
func label(text: String, at: Vector2, size_: int, color := Color("dcecd7")) -> void:
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_, color)
func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 840), Color("112b28"))
	if is_instance_valid(guide.photo_camera) and guide.photo_camera.active:
		_draw_camera()
		return
	if guide.selected < 0:
		_draw_status()
		return
	label("FIELD GUIDE", Vector2(34, 65), 42, Color("a9dfb2"))
	label("LAKE · SEA · RIVER", Vector2(36, 102), 23)
	draw_line(Vector2(34, 127), Vector2(606, 127), Color("49715d"), 2)
	var rows: Array = guide.ordered_entries()
	label("%02d / %02d SPECIES FOUND" % [guide.entries.size(), rows.size()], Vector2(36, 174), 28)
	guide.selected = clampi(guide.selected, 0, rows.size() - 1)
	var entry: Dictionary = rows[guide.selected]
	label(entry.name, Vector2(36, 235), 39)
	label(entry.latin if entry.discovered else "UNDISCOVERED", Vector2(36, 274), 26, Color("a9dfb2"))
	var center := Vector2(320, 343)
	if entry.discovered:
		var silhouette := Icons.contour(entry.latin, center, 110.0)
		draw_colored_polygon(silhouette, Color("a9dfb2"))
		var edge := silhouette.duplicate(); edge.append(edge[0])
		draw_polyline(edge, Color("d5f5ce"), 2.0, true)
		draw_circle(center + Vector2(0.65, -0.04) * 110.0, 4, Color("112b28"))
	else:
		label("?", Vector2(287, 382), 108, Color("a9dfb2"))
	label("HABITAT · " + entry.habitat, Vector2(36, 435), 25, Color("a9dfb2"))
	label("PREFERRED BAIT · " + entry.bait, Vector2(36, 474), 23, Color("a9dfb2"))
	var line := ""
	var y := 518.0
	for word in str(entry.description).split(" "):
		var next := word if line.is_empty() else line + " " + word
		if font.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, 23).x > 565:
			label(line, Vector2(36, y), 23); y += 29; line = word
		else: line = next
	label(line, Vector2(36, y), 23)
	draw_rect(Rect2(28, 633, 584, 77), Color("234a3d"))
	label("PERSONAL BEST" if entry.discovered else "NOT CAUGHT YET", Vector2(46, 663), 24)
	label("%.1f cm" % entry.length if entry.discovered else "—", Vector2(370, 692), 37, Color("b9f0c0"))
	label("ENTRY %02d / %02d" % [guide.selected + 1, rows.size()], Vector2(36, 747), 25)
	label("FINGER: ‹ › PAGES · LEFT TRIGGER: CAMERA" if guide.game_root.xr else "C: CAMERA · ← →: BROWSE", Vector2(36, 782), 22)
	label("RELEASE GRIP: RETURN TO BELT" if guide.game_root.xr else "G: CLOSE GUIDE", Vector2(36, 819), 21)

func _draw_camera() -> void:
	var photo = guide.photo_camera
	label("FIELD CAMERA", Vector2(34, 65), 42, Color("a9dfb2"))
	label("SELFIE STICK" if photo.selfie else "LOOK THROUGH THE LENS", Vector2(36, 112), 26)
	draw_texture_rect(photo.view.get_texture(), Rect2(20, 170, 600, 337.5), false)
	label("1920 × 1080 · UI-free photo", Vector2(36, 555), 27)
	var words: PackedStringArray = photo.status.split(" ")
	var line := ""
	var y := 605.0
	for word in words:
		if font.get_string_size(line + word, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x > 560:
			label(line, Vector2(36, y), 20); y += 26; line = ""
		line += word + " "
	label(line, Vector2(36, y), 20)
	label("PRESS › / RIGHT TRIGGER: PHOTO" if guide.game_root.xr else "SPACE: TAKE PHOTO", Vector2(36, 735), 25)
	label("PRESS ‹ / RIGHT A: SELFIE ON/OFF" if guide.game_root.xr else "F: SELFIE ON/OFF · MIDDLE-DRAG: AIM", Vector2(36, 777), 23)
	label("LEFT TRIGGER: GUIDE" if guide.game_root.xr else "C: GUIDE · G: CLOSE", Vector2(36, 819), 23)

func status_rows() -> Array:
	var session = guide.game_root.game
	var earned: int = session.last_reward
	if earned == 0 and not session.journal.is_empty(): earned = int(session.journal.back().get("shekels", 0))
	return [
		["LOCATION", session.location_name],
		["SHEKELS AVAILABLE", str(session.tackle.shekels)],
		["LAST CATCH EARNED", "+%d shekels" % earned],
		["BAIT EQUIPPED", session.bait_name(session.bait)],
		["ROD EQUIPPED", session.tackle.rod().name + (" · stashed" if guide.game_root.rod_holster.stowed else "")],
	]

func _draw_status() -> void:
	label("FIELD GUIDE", Vector2(34, 65), 42, Color("a9dfb2"))
	label("YOUR FISHING SESSION", Vector2(36, 112), 26)
	draw_line(Vector2(34, 135), Vector2(606, 135), Color("49715d"), 2)
	var rows := status_rows()
	for i in rows.size():
		var y := 178 + i * 103
		label(rows[i][0], Vector2(36, y), 23)
		var value := str(rows[i][1])
		var text_size := 38
		while text_size > 24 and font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x > 568:
			text_size -= 1
		label(value, Vector2(36, y + 44), text_size, Color("a9dfb2"))
	label("%02d / %02d SPECIES FOUND" % [guide.entries.size(), guide.Session.SPECIES.size()], Vector2(36, 730), 27)
	label("FINGER: ‹ › COLLECTION" if guide.game_root.xr else "← →: COLLECTION", Vector2(36, 782), 25)
	label("LEFT TRIGGER: CAMERA" if guide.game_root.xr else "C: CAMERA · G: CLOSE", Vector2(36, 819), 23)
