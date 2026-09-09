extends PanelContainer
signal selected(path: String)
signal import_requested(path: String)
signal closed
signal turn_mode_changed(smooth: bool)
var library
var list: ItemList
var status: Label
var picker: FileDialog
var preview_camera: Camera3D
var preview: SubViewport

func _ready() -> void:
	custom_minimum_size = Vector2(850, 580)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("102b25")
	style.set_corner_radius_all(18)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	add_child(column)
	var title := Label.new()
	title.text = "YOUR AVATAR"
	title.add_theme_font_size_override("font_size", 28)
	column.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	column.add_child(row)
	list = ItemList.new()
	list.custom_minimum_size = Vector2(480, 305)
	list.add_theme_font_size_override("font_size", 23)
	row.add_child(list)
	list.item_selected.connect(func(index: int): selected.emit(library.entries[index].path))
	var view := SubViewportContainer.new()
	view.custom_minimum_size = Vector2(270, 305)
	view.stretch = true
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(view)
	preview = SubViewport.new()
	preview.size = Vector2i(270, 305)
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
	column.add_child(buttons)
	var import_button := Button.new()
	import_button.text = "Import .vrm"
	import_button.custom_minimum_size = Vector2(230, 52)
	buttons.add_child(import_button)
	import_button.pressed.connect(func(): picker.popup_centered_ratio(0.75))
	var turn_mode := CheckButton.new()
	turn_mode.text = "Smooth turn"
	buttons.add_child(turn_mode)
	turn_mode.toggled.connect(func(on: bool): turn_mode_changed.emit(on))
	var close_button := Button.new()
	close_button.text = "Back to lake"
	close_button.custom_minimum_size = Vector2(190, 52)
	buttons.add_child(close_button)
	close_button.pressed.connect(func(): closed.emit())
	picker = FileDialog.new()
	picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	picker.access = FileDialog.ACCESS_FILESYSTEM
	picker.filters = PackedStringArray(["*.vrm ; VRM avatar (maximum 25 MB)"])
	picker.use_native_dialog = true
	add_child(picker)
	picker.file_selected.connect(func(path: String): import_requested.emit(path))
	refresh()

func refresh() -> void:
	if not is_instance_valid(list): return
	list.clear()
	for entry in library.entries:
		list.add_item("%s   ·   %.1f MB" % [entry.title, entry.size / 1_000_000.0])
		if entry.path == library.selected_path: list.select(list.item_count - 1)

func update_preview(avatar: Node3D) -> void:
	if not is_visible_in_tree() or not is_instance_valid(avatar): return
	preview.world_3d = avatar.get_world_3d()
	var center := avatar.global_position + Vector3.UP * 0.95
	preview_camera.global_position = avatar.global_position + avatar.global_basis * Vector3(0, 1.1, -2.7)
	preview_camera.look_at(center)
