extends SceneTree
## Reproducible 2D branding using the unchanged game icon and CC0 fonts.
var folder := "res://docs/quest-store/media"
var canvas: Control
var title_font := FontFile.new()
var small_font := FontFile.new()
var icon: ImageTexture

func _initialize() -> void:
	call_deferred("run")

func background(color: Color) -> void:
	var rect := ColorRect.new()
	rect.color = color
	rect.size = Vector2(root.content_scale_size)
	canvas.add_child(rect)

func mark(at: Vector2, size: float) -> void:
	var rect := TextureRect.new()
	rect.texture = icon
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.position = at
	rect.size = Vector2.ONE * size
	canvas.add_child(rect)

func lettering(value: String, at: Vector2, size: int, color: Color, font: FontFile = title_font) -> void:
	var label := Label.new()
	label.text = value
	label.position = at
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	canvas.add_child(label)

func begin(size: Vector2i, transparent: bool) -> void:
	if is_instance_valid(canvas):
		root.remove_child(canvas)
		canvas.queue_free()
	root.size = Vector2i(960,540)
	root.content_scale_size = size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	root.transparent_bg = transparent
	canvas = Control.new()
	root.add_child(canvas)

func save(name: String, transparent := false) -> void:
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8 if transparent else Image.FORMAT_RGB8)
	var err := image.save_png(folder.path_join(name+".png"))
	print("BRANDING ",name," ",image.get_size()," ",err)
	if err != OK:quit(1)

# Consistent full-title composition, centered with generous bleed margins.
func full_title(size: Vector2i, transparent := false) -> void:
	begin(size,transparent)
	if not transparent: background(Color("112d2f"))
	var group := Control.new()
	canvas.add_child(group)
	var outer := canvas
	canvas = group
	var portrait := float(size.x)/size.y < 1.4
	var design := Vector2(800,1050) if portrait else Vector2(1500,560)
	var scale_factor := minf(size.x * 0.74 / design.x, size.y * 0.74 / design.y)
	group.scale = Vector2.ONE * scale_factor
	group.position = (Vector2(size) - design * scale_factor) / 2.0
	var text_at := Vector2(0,540) if portrait else Vector2(580,0)
	mark(Vector2(190,0) if portrait else Vector2(0,60),420)
	for row in [["ULTIMATE",105,0],["BOOMER",195,123],["SIMULATOR",105,350]]:
		var text_size := title_font.get_string_size(row[0],HORIZONTAL_ALIGNMENT_LEFT,-1,row[1])
		var x := (800-text_size.x)/2.0 if portrait else text_at.x
		lettering(row[0],Vector2(x,text_at.y+row[2]),row[1],Color("f2ead3"))
		var label := canvas.get_child(canvas.get_child_count()-1) as Label
		label.add_theme_color_override("font_outline_color",Color("112d2f"))
		label.add_theme_constant_override("outline_size",8)
	canvas = outer

func run() -> void:
	title_font.load_dynamic_font(folder.path_join("fonts/Almonte.otf"))
	small_font.load_dynamic_font(folder.path_join("fonts/Blue-Highway-Regular.otf"))
	icon = ImageTexture.create_from_image(Image.load_from_file("res://assets/icon.svg"))
	var cream := Color("f2ead3")
	var gold := Color("d4ccab")
	begin(Vector2i(512,512),false)
	background(Color("193c3e"))
	mark(Vector2.ZERO,512)
	await save("icon")
	begin(Vector2i(512,512),true)
	mark(Vector2.ZERO,512)
	await save("logo-mark",true)
	begin(Vector2i(1800,700),true)
	mark(Vector2(80,130),440)
	lettering("ULTIMATE",Vector2(590,65),120,gold)
	lettering("BOOMER",Vector2(570,205),215,cream)
	lettering("SIM",Vector2(590,440),120,gold)
	await save("logo-lockup",true)
	begin(Vector2i(1200,600),true)
	mark(Vector2(60,90),420)
	lettering("UBS",Vector2(550,110),290,cream)
	await save("logo-ubs",true)
	begin(Vector2i(1920,1080),false)
	background(Color("112d2f"))
	mark(Vector2(315,310),360)
	lettering("ULTIMATE",Vector2(775,247),100,gold)
	lettering("BOOMER",Vector2(755,362),190,cream)
	lettering("SIMULATOR",Vector2(775,580),100,gold)
	await save("trailer-title")
	begin(Vector2i(1600,1000),false)
	background(Color("112d2f"))
	mark(Vector2(85,75),190)
	lettering("ULTIMATE BOOMER SIM",Vector2(330,90),88,cream)
	lettering("UBS",Vector2(95,320),250,gold)
	lettering("Almonte",Vector2(640,350),105,cream)
	lettering("ABCDEFGHIJKLMNOPQRSTUVWXYZ",Vector2(95,650),55,cream)
	lettering("0123456789",Vector2(95,735),64,gold)
	lettering("CC0 1.0  /  RAYMOND LARABIE  /  TYPODERMIC",Vector2(95,890),28,cream,small_font)
	await save("lettering-specimen")
	for cover in [["hero",3000,900],["cover-landscape",2560,1440],["cover-square",1440,1440],["cover-portrait",1008,1440],["mini-landscape",1080,360]]:
		full_title(Vector2i(cover[1],cover[2]))
		await save(cover[0])
	full_title(Vector2i(1800,700),true)
	await save("logo",true)
	quit()
