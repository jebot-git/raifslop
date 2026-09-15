extends PanelContainer
signal selected(path: String)
signal import_requested(path: String)
signal closed
signal quit_requested
var quit_button: Button
var tutorial_button: Button
var turn_mode: CheckButton
signal turn_mode_changed(smooth: bool)
signal location_selected(id: String)
const Locations = preload("res://scripts/locations.gd")
var keyboard: PanelContainer
var shell: VBoxContainer
var tabs: HBoxContainer
var content: Control
var pages: Dictionary={}
var active_page := "avatar"
var avatar_page: VBoxContainer
var locations_page: VBoxContainer
var location_list: ItemList
var location_preview: TextureRect
var location_description: Label
var location_status: Label
var visit_button: Button
var location_actions: HBoxContainer
var active_location := Locations.DEFAULT_ID
var can_travel := true
var library
var list: ItemList
var status: Label
var picker: FileDialog
var vrm_browser: PanelContainer
var import_button: Button
var avatar_actions: HBoxContainer
var preview_camera: Camera3D
var preview: SubViewport

func _ready() -> void:
	custom_minimum_size = Vector2(880, 650)
	theme=preload("res://scripts/ui/waterside_theme.gd").theme()
	var style=preload("res://scripts/ui/waterside_theme.gd").panel(18)
	style.set_content_margin_all(18)
	add_theme_stylebox_override("panel",style)
	_build_shell()
	var keyboard_layer:=CanvasLayer.new();keyboard_layer.layer=60;add_child(keyboard_layer)
	keyboard=preload("res://scripts/ui/keyboard.gd").new();keyboard_layer.add_child(keyboard)
	var column := VBoxContainer.new()
	avatar_page = column
	column.add_theme_constant_override("separation", 14)
	_register_page("avatar","Avatar",column)
	var heading := HBoxContainer.new()
	column.add_child(heading)
	var title := Label.new()
	title.text = "Your angler"
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	column.add_child(row)
	list = ItemList.new()
	list.custom_minimum_size = Vector2(480, 260)
	list.add_theme_font_size_override("font_size", 23)
	row.add_child(list)
	list.item_selected.connect(func(index: int): selected.emit(library.entries[index].path))
	var view := SubViewportContainer.new()
	view.custom_minimum_size = Vector2(270, 260)
	view.stretch = true
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(view)
	preview = SubViewport.new()
	preview.size = Vector2i(270, 260)
	preview.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	view.add_child(preview)
	preview_camera = Camera3D.new()
	preview_camera.cull_mask = 4
	preview_camera.fov = 42
	preview.add_child(preview_camera)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("263f36")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.8
	preview_camera.environment = env
	status = Label.new()
	status.text = "VRM 0.x / 1.0 · Maximum 25 MB per file"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.y = 52
	status.add_theme_font_size_override("font_size", 20)
	column.add_child(status)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 18)
	avatar_actions = buttons
	shell.add_child(buttons)
	shell.move_child(buttons, 3)
	import_button = Button.new()
	import_button.text = "Import .vrm"
	import_button.custom_minimum_size = Vector2(230, 52)
	buttons.add_child(import_button)
	import_button.pressed.connect(_open_import)
	turn_mode = CheckButton.new()
	turn_mode.text = "Smooth turn"
	buttons.add_child(turn_mode)
	turn_mode.toggled.connect(func(on: bool): turn_mode_changed.emit(on))
	picker = FileDialog.new()
	picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	picker.access = FileDialog.ACCESS_FILESYSTEM
	picker.filters = PackedStringArray(["*.vrm ; VRM avatar (maximum 25 MB)"])
	picker.use_native_dialog = true
	add_child(picker)
	picker.file_selected.connect(func(path: String): import_requested.emit(path))
	var browser_layer := CanvasLayer.new(); browser_layer.layer = 50; add_child(browser_layer)
	var browser_shade := ColorRect.new(); browser_shade.color = Color(0,0,0,.4); browser_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	browser_layer.add_child(browser_shade); browser_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); browser_shade.hide()
	vrm_browser = preload("res://scripts/ui/vrm_browser.gd").new(); browser_layer.add_child(vrm_browser)
	vrm_browser.visibility_changed.connect(func(): browser_shade.visible = vrm_browser.visible)
	vrm_browser.file_selected.connect(func(path: String): import_requested.emit(path))
	vrm_browser.closed.connect(func(): keyboard.hide())
	_bind_keyboard(vrm_browser)
	refresh()
	_build_locations()

func _build_locations() -> void:
	locations_page = VBoxContainer.new()
	locations_page.add_theme_constant_override("separation", 18)
	_register_page("waters","Waters",locations_page)
	var header := HBoxContainer.new()
	locations_page.add_child(header)
	var title := Label.new()
	title.text = "Find your water"
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	locations_page.add_child(row)
	location_list = ItemList.new()
	location_list.custom_minimum_size = Vector2(310, 305)
	location_list.add_theme_font_size_override("font_size", 23)
	location_list.add_theme_constant_override("v_separation", 20)
	row.add_child(location_list)
	location_list.item_selected.connect(_preview_location)
	var details := VBoxContainer.new()
	details.custom_minimum_size = Vector2(450, 305)
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 12)
	row.add_child(details)
	location_preview = TextureRect.new()
	location_preview.custom_minimum_size = Vector2(440, 220)
	location_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	location_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	details.add_child(location_preview)
	location_description = Label.new()
	location_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	location_description.add_theme_font_size_override("font_size", 18)
	details.add_child(location_description)
	location_status = Label.new()
	location_status.custom_minimum_size.y = 52
	location_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	location_status.add_theme_font_size_override("font_size", 20)
	location_actions = HBoxContainer.new()
	shell.add_child(location_actions)
	shell.move_child(location_actions, 3) # Between scrolling content and the common footer.
	location_status.size_flags_horizontal = SIZE_EXPAND_FILL
	location_actions.add_child(location_status)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 20)
	location_actions.add_child(buttons)
	visit_button = Button.new()
	visit_button.text = "Fish here"
	visit_button.custom_minimum_size = Vector2(260, 52)
	buttons.add_child(visit_button)
	visit_button.pressed.connect(func():
		var indices := location_list.get_selected_items()
		if not indices.is_empty(): location_selected.emit(Locations.CATALOG[indices[0]].id))
	locations_page.hide()
	location_actions.hide()
	refresh_locations(active_location, true)

func show_locations() -> void:
	show_page("waters")

func refresh_locations(current: String, allowed: bool) -> void:
	active_location = current
	can_travel = allowed
	if not is_instance_valid(location_list): return
	location_list.clear()
	var selected_index := 0
	for index in range(Locations.CATALOG.size()):
		var entry: Dictionary = Locations.CATALOG[index]
		location_list.add_item(entry.name + ("  •" if entry.id == current else ""))
		if entry.id == current: selected_index = index
	location_list.select(selected_index)
	_preview_location(selected_index)
	location_status.text = "Choose a spot, then select Fish here." if allowed else "Finish this cast and release your catch before travelling."

func _preview_location(index: int) -> void:
	var entry: Dictionary = Locations.CATALOG[index]
	# Only small JPG previews are loaded while browsing; never the HDR skies.
	location_preview.texture = load(entry.preview) if not entry.preview.is_empty() else null
	location_description.text = entry.mood + "\n" + entry.description
	visit_button.disabled = not can_travel or entry.id == active_location

func refresh() -> void:
	if not is_instance_valid(list): return
	list.clear()
	for entry in library.entries:
		list.add_item(entry.title + ("  ·  default" if entry.path == library.DEFAULTS[0] else ""))
		if entry.path == library.selected_path: list.select(list.item_count - 1)

func update_preview(avatar: Node3D) -> void:
	if not is_visible_in_tree() or not is_instance_valid(avatar): return
	preview.world_3d = avatar.get_world_3d()
	# Leave room above the humanoid head bone for tall heads, hats and fins.
	var center := avatar.global_position + Vector3.UP * 1.15
	preview_camera.global_position = avatar.global_position + avatar.global_basis * Vector3(0, 1.15, -3.6)
	preview_camera.look_at(center)

var multiplayer_page: VBoxContainer
func attach_multiplayer(session: Node) -> void:
	multiplayer_page=preload("res://scripts/network/menu.gd").new()
	_register_page("together","Together",multiplayer_page)
	multiplayer_page.setup(session,func(): show_page("avatar"))
	multiplayer_page.hide()
	_bind_keyboard(multiplayer_page)

var tracking_page: VBoxContainer
func attach_tracking(manager: Node) -> void:
	tracking_page=VBoxContainer.new(); tracking_page.add_theme_constant_override("separation",14); _register_page("tracking","Tracking",tracking_page)
	var heading:=Label.new(); heading.text="AVATAR TRACKING & CALIBRATION"; heading.add_theme_font_size_override("font_size",26); tracking_page.add_child(heading)
	for row in [["Tracked body",manager.tracking.enabled],["Animate planted tracked legs when walking",manager.tracked_leg_animation],["Eye and face expressions",manager.expressions_enabled],["Seated height calibration",manager.seated]]:
		var toggle:=CheckButton.new(); toggle.text=row[0]; toggle.button_pressed=row[1]; tracking_page.add_child(toggle)
		toggle.toggled.connect(func(value: bool):
			match row[0]:
				"Tracked body": manager.tracking.enabled=value
				"Animate planted tracked legs when walking": manager.tracked_leg_animation=value
				"Eye and face expressions": manager.expressions_enabled=value
				"Seated height calibration": manager.seated=value
			manager.save())
	for row in [["Recenter viewpoint",manager.recenter],["Calibrate body — stand straight",manager.calibrate],["Toggle SlimeVR OSC (localhost:9000)",manager.tracking.toggle_osc],["Request tracking permissions",func(): manager.game.permissions.request_tracking(true)]]:
		var action:=Button.new(); action.text=row[0]; action.custom_minimum_size.y=44; tracking_page.add_child(action); action.pressed.connect(row[1])
	var info:=Label.new(); info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; info.custom_minimum_size=Vector2(700,110); tracking_page.add_child(info)
	var timer:=Timer.new(); timer.wait_time=.5; timer.autostart=true; tracking_page.add_child(timer)
	timer.timeout.connect(func(): info.text=manager.message+"\n"+manager.tracking.status+"\nHold a T-pose for 1.1 s to calibrate body trackers.\nEye tracking animates your avatar; cast aim stays centered in your view.")
	tracking_page.hide()

func _build_shell() -> void:
	shell=VBoxContainer.new();shell.add_theme_constant_override("separation",12);add_child(shell)
	var top:=HBoxContainer.new();shell.add_child(top)
	var title:=Label.new();title.text="Field station";var serif:=SystemFont.new();serif.font_names=PackedStringArray(["DejaVu Serif"]);title.add_theme_font_override("font",serif);title.add_theme_font_size_override("font_size",28);title.add_theme_color_override("font_color",Color("d5b777"));top.add_child(title)
	var subtitle:=Label.new();subtitle.text="Make yourself at home by the water";subtitle.size_flags_horizontal=SIZE_EXPAND_FILL;subtitle.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;subtitle.add_theme_font_size_override("font_size",16);top.add_child(subtitle)
	tabs=HBoxContainer.new();tabs.add_theme_constant_override("separation",8);shell.add_child(tabs)
	content=Control.new();content.clip_contents=true;content.size_flags_vertical=SIZE_EXPAND_FILL;shell.add_child(content)
	var bottom:=HBoxContainer.new();shell.add_child(bottom)
	var hint:=Label.new();hint.text="Progress saved.";hint.add_theme_font_size_override("font_size",16);hint.size_flags_horizontal=SIZE_EXPAND_FILL;bottom.add_child(hint)
	for step in [-1, 1]:
		var scroll_button := Button.new()
		scroll_button.text = "↑" if step < 0 else "↓"
		scroll_button.tooltip_text = "Scroll page (or use the right stick)"
		scroll_button.custom_minimum_size = Vector2(52, 44)
		bottom.add_child(scroll_button)
		scroll_button.pressed.connect(func(): scroll_page(step * 180.0))
	quit_button=Button.new();quit_button.text="Quit game";quit_button.custom_minimum_size=Vector2(150,44);bottom.add_child(quit_button);quit_button.pressed.connect(func(): quit_requested.emit())
	var resume:=Button.new();resume.text="Return to the water";resume.custom_minimum_size=Vector2(250,44);bottom.add_child(resume);resume.pressed.connect(func(): closed.emit())

func scroll_page(pixels: float) -> void:
	if is_instance_valid(vrm_browser) and vrm_browser.visible:
		vrm_browser.files.get_v_scroll_bar().value += pixels
		return
	if is_instance_valid(keyboard) and keyboard.visible: return
	if pages.has(active_page): pages[active_page].view.scroll_vertical += roundi(pixels)

func attach_help() -> void:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 6)
	_register_page("help", "Tutorial", page)
	tutorial_button = pages.help.button
	# Keep help in the fixed header without crowding the six section tabs.
	tutorial_button.reparent(shell.get_child(0))
	tutorial_button.size_flags_horizontal = SIZE_SHRINK_END
	tutorial_button.custom_minimum_size = Vector2(130, 44)
	for instruction in [
		"FISHING · VR controls",
		"Cast: face open water. Hold right trigger, swing, then release.
When the float dips, lift the rod quickly to set the hook.",
		"Reel: hold left grip beside the crank and circle your hand.
Ease off during runs; keep line tension in the green band.",
		"Fight: pull in the indicated direction and HOLD.
Strong rod pulses mean your counter is working.
Diving: stop reeling. Rushing inward: wind faster.
Three missed counters, sustained slack or strain lose the fish.",
		"Guide: left grip at your left hip. Press its buttons with your
right index finger. Right grip at your right hip folds/stashes the rod.",
		"Catch: left grip to hold; sticks to rotate; right A to release.
Move with the left stick, turn with the right stick. Right B: menu.",
		"Radio: grab at left shoulder, hold left trigger to talk to all waters.
Release grip to dock. Desktop radio: hold B. Nearby voice: T / left stick click.",
		"Desktop: SPACE cast/strike/release; hold R to reel (Shift: faster); arrows to
counter; G guide; J stash rod; V menu; WASD move; Q/E turn."
	]:
		var label := Label.new()
		label.text = instruction
		label.add_theme_font_size_override("font_size", 20)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		page.add_child(label)
	show_page(active_page)

func _register_page(id: String, title: String, page: VBoxContainer) -> void:
	var scroll=preload("res://scripts/ui/drag_scroll.gd").new();content.add_child(scroll);scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.size_flags_horizontal=SIZE_EXPAND_FILL;page.size_flags_horizontal=SIZE_EXPAND_FILL;scroll.add_child(page)
	var button:=Button.new();button.text=title;button.toggle_mode=true;button.size_flags_horizontal=SIZE_EXPAND_FILL;button.custom_minimum_size.y=46;tabs.add_child(button)
	pages[id]={"view":scroll,"page":page,"button":button}
	button.pressed.connect(func(): show_page(id))
	show_page(active_page)

func show_page(id: String) -> void:
	if id == "tackle": refresh_tackle()
	if not pages.has(id):return
	if is_instance_valid(keyboard): keyboard.hide()
	if is_instance_valid(vrm_browser): vrm_browser.hide()
	active_page=id
	if is_instance_valid(avatar_actions): avatar_actions.visible = id == "avatar"
	if is_instance_valid(location_actions): location_actions.visible = id == "waters"
	for key in pages:
		pages[key].view.visible=key==id
		pages[key].page.visible=key==id
		pages[key].button.set_pressed_no_signal(key==id)
	for selector in get_tree().get_nodes_in_group("fishing_selectors"):
		if selector.get_viewport()==get_viewport():selector.popup.hide()

var sound_page: VBoxContainer
func attach_sound(ambience: Node) -> void:
	sound_page=VBoxContainer.new();sound_page.add_theme_constant_override("separation",20);_register_page("sound","Sound",sound_page)
	var heading:=Label.new();heading.text="Listen to the lake";heading.add_theme_font_size_override("font_size",28);sound_page.add_child(heading)
	var description:=Label.new();description.text="Water at the shore, distant birds, a little breeze.
Each location has its own soundscape.";description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;sound_page.add_child(description)
	var row:=HBoxContainer.new();sound_page.add_child(row)
	var label:=Label.new();label.text="Nature & surroundings";label.size_flags_horizontal=SIZE_EXPAND_FILL;row.add_child(label)
	var level:=Label.new();level.text="%d%%" % roundi(ambience.volume*100);row.add_child(level)
	for amount in [-.1,.1]:
		var b:=Button.new();b.text="−" if amount<0 else "+";b.custom_minimum_size=Vector2(64,48);row.add_child(b)
		b.pressed.connect(func(): ambience.set_volume(ambience.volume+amount);level.text="%d%%" % roundi(ambience.volume*100))
	var mute:=CheckButton.new();mute.text="Quiet surroundings";mute.button_pressed=ambience.muted;mute.toggled.connect(ambience.set_muted);sound_page.add_child(mute)
	var voice:=Button.new();voice.text="Voice chat & microphone →";voice.pressed.connect(func(): show_page("together"));sound_page.add_child(voice)
	show_page(active_page)

func _bind_keyboard(node: Node) -> void:
	if node is LineEdit:
		node.focus_entered.connect(func():
			if get_viewport() is SubViewport and XRServer.primary_interface!=null: keyboard.open_for(node))
	for child in node.get_children():_bind_keyboard(child)

func _open_import() -> void:
	if get_viewport() is SubViewport:
		keyboard.hide()
		vrm_browser.open()
	else:
		picker.popup_centered_ratio(0.75)

func close_overlays() -> void:
	keyboard.hide()
	vrm_browser.hide()
	picker.hide()

func attach_shadow_controls(policy: Node) -> void:
	var choice=preload("res://scripts/ui/choice.gd").new()
	avatar_page.add_child(choice)
	choice.configure([{"id":"blob","title":"Moving shadows · Soft contact"},{"id":"dynamic","title":"Moving shadows · Dynamic"}],"Moving shadows")
	choice.value=policy.mode;choice.update_label()
	choice.selected.connect(func(value):policy.set_mode(str(value)))

var tackle_game
var tackle_balance: Label
var tackle_status: Label
var tackle_buttons: Array[Button] = []
func attach_tackle(session) -> void:
	tackle_game = session
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	_register_page("tackle", "Tackle", page)
	tackle_balance = Label.new()
	tackle_balance.add_theme_font_size_override("font_size", 26)
	page.add_child(tackle_balance)
	var hint := Label.new()
	hint.text = "Earn shekels for each catch. Rarer and larger fish pay more.\nBetter rods withstand strain and tire fish faster."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(hint)
	for index in range(session.Tackle.RODS.size()):
		var rod: Dictionary = session.Tackle.RODS[index]
		var row := HBoxContainer.new()
		page.add_child(row)
		var details := Label.new()
		details.text = "%s\nLine durability ×%.2f · Fatigue ×%.2f" % [rod.name, rod.durability, rod.fatigue]
		details.add_theme_font_size_override("font_size", 20)
		details.size_flags_horizontal = SIZE_EXPAND_FILL
		row.add_child(details)
		var button := Button.new()
		button.custom_minimum_size = Vector2(250, 58)
		row.add_child(button)
		tackle_buttons.append(button)
		button.pressed.connect(func():
			session.tackle.purchase_or_equip(index, session.state == session.State.READY)
			refresh_tackle())
	tackle_status = Label.new()
	tackle_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(tackle_status)
	refresh_tackle()

func refresh_tackle() -> void:
	if tackle_game == null: return
	var profile = tackle_game.tackle
	tackle_balance.text = "%d shekels · %s equipped" % [profile.shekels, profile.rod().name]
	var allowed: bool = tackle_game.state == tackle_game.State.READY
	tackle_status.text = profile.status if allowed else "Finish this cast and release your catch to change rods."
	for index in range(tackle_buttons.size()):
		var button := tackle_buttons[index]
		var owned: bool = index in profile.owned
		var equipped: bool = index == profile.equipped
		var price: int = profile.RODS[index].price
		button.text = "Equipped" if equipped else ("Equip" if owned else "Buy · %d shekels" % price)
		button.disabled = not allowed or equipped or (not owned and profile.shekels < price)
