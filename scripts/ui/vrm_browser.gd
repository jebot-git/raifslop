extends PanelContainer
signal file_selected(path: String)
signal closed
var path_field: LineEdit
var files: ItemList
var message: Label
var open_button: Button
var directory := ""
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = preload("res://scripts/ui/waterside_theme.gd").theme()
	var column := VBoxContainer.new(); add_child(column)
	var title := Label.new(); title.text = "Import VRM avatar · maximum 25 MB"; column.add_child(title)
	var row := HBoxContainer.new(); column.add_child(row)
	for entry in [["VRM folder",func(): browse(preload("res://scripts/data_paths.gd").folder("vrm"))],["Up",func(): browse(directory.get_base_dir())],["Home",func(): browse(OS.get_environment("HOME"))],["Downloads",func(): browse(OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS))]]:
		var button := Button.new(); button.text = entry[0]; row.add_child(button); button.pressed.connect(entry[1])
	path_field = LineEdit.new(); path_field.placeholder_text = "Folder or .vrm path"; path_field.size_flags_horizontal = SIZE_EXPAND_FILL; row.add_child(path_field)
	path_field.text_submitted.connect(_open_path)
	var go := Button.new(); go.text = "Go"; row.add_child(go); go.pressed.connect(func(): _open_path(path_field.text))
	files = ItemList.new(); files.custom_minimum_size.y = 156; files.size_flags_vertical = SIZE_EXPAND_FILL; column.add_child(files)
	files.item_selected.connect(func(_i: int): open_button.disabled = false)
	files.item_activated.connect(func(i: int): _open_path(files.get_item_metadata(i)))
	message = Label.new(); message.text = "Choose a folder or VRM file, then Open."; message.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS; column.add_child(message)
	var footer := HBoxContainer.new(); column.add_child(footer)
	open_button = Button.new(); open_button.text = "Open"; open_button.custom_minimum_size = Vector2(180,44); footer.add_child(open_button)
	open_button.pressed.connect(func():
		var selected := files.get_selected_items()
		if not selected.is_empty(): _open_path(files.get_item_metadata(selected[0])))
	var cancel := Button.new(); cancel.text = "Cancel"; cancel.custom_minimum_size = Vector2(180,44); footer.add_child(cancel); cancel.pressed.connect(func(): hide(); closed.emit())
	hide()
func open() -> void:
	show(); size = Vector2(900,350); position = Vector2(50,20)
	if directory.is_empty():
		directory = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
		if not DirAccess.dir_exists_absolute(directory): directory = OS.get_user_data_dir()
	browse(directory)
func browse(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null: message.text = "Cannot open this folder. Choose another path."; return
	directory = dir.get_current_dir(); path_field.text = directory; files.clear(); open_button.disabled = true
	for folder in dir.get_directories():
		if folder.begins_with("."): continue
		var index := files.add_item("[Folder] " + folder); files.set_item_metadata(index,directory.path_join(folder))
	for file in dir.get_files():
		if file.get_extension().to_lower() != "vrm": continue
		var index := files.add_item(file); files.set_item_metadata(index,directory.path_join(file))
	message.text = "Choose a folder or VRM file, then Open."
func _open_path(path: String) -> void:
	path = path.strip_edges()
	if not path.is_absolute_path(): path = directory.path_join(path)
	if DirAccess.dir_exists_absolute(path): browse(path); return
	if path.get_extension().to_lower() != "vrm" or not FileAccess.file_exists(path):
		message.text = "Select an existing .vrm file or folder."; return
	hide(); closed.emit(); file_selected.emit(path)
