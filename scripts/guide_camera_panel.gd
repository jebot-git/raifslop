extends RefCounted
## One camera screen for both activity guides.
static func draw(screen:Control,guide)->void:
	var photo = guide.photo_camera
	var controls:Dictionary=guide.camera_controls() if guide.has_method("camera_controls") else {}
	screen.label("FIELD CAMERA", Vector2(34, 65), 42, Color("a9dfb2"))
	screen.label("SELFIE STICK" if photo.selfie else "LOOK THROUGH THE LENS", Vector2(36, 112), 26)
	screen.draw_texture_rect(photo.view.get_texture(), Rect2(20, 170, 600, 337.5), false)
	var extension_hint:String="RIGHT STICK ↑/↓: EXTEND / RETRACT"
	screen.label(controls.get("extend",extension_hint) if photo.selfie else "1920 × 1080 · UI-free photo", Vector2(36, 555), 23 if photo.selfie else 27)
	var words: PackedStringArray = photo.status.split(" ")
	var line := ""
	var y := 605.0
	for word in words:
		if screen.font.get_string_size(line + word, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x > 560:
			screen.label(line, Vector2(36, y), 20); y += 26; line = ""
		line += word + " "
	screen.label(line, Vector2(36, y), 20)
	screen.label(controls.get("capture","PRESS › / RIGHT TRIGGER: PHOTO"), Vector2(36, 735), 25)
	screen.label(controls.get("selfie","PRESS ‹ / RIGHT A: SELFIE ON/OFF"), Vector2(36, 777), 23)
	screen.label(controls.get("toggle","LEFT TRIGGER: GUIDE"), Vector2(36, 819), 23)

