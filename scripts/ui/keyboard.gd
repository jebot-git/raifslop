extends PanelContainer
## FPSloppa-style deferred key delivery to the focused menu viewport.
var target: LineEdit
var shift := false
var preview: Label
var character_buttons: Array[Button] = []
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme=preload("res://scripts/ui/waterside_theme.gd").theme()
	var column:=VBoxContainer.new();add_child(column)
	preview = Label.new(); preview.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS; preview.custom_minimum_size.y = 28; column.add_child(preview)
	var grid:=GridContainer.new();grid.columns=10;column.add_child(grid)
	for character in "1234567890qwertyuiopasdfghjkl-zxcvbnm.:/":
		var button := key(grid,character,func(): send_character(character.to_upper() if shift else character))
		character_buttons.append(button)
	var row:=HBoxContainer.new();column.add_child(row)
	key(row,"Shift",func():
		shift=not shift
		for button in character_buttons: button.text = button.text.to_upper() if shift else button.text.to_lower())
	key(row,"Space",func(): send_character(" "))
	key(row,"_",func(): send_character("_"))
	key(row,"←",func(): deliver(KEY_LEFT,0))
	key(row,"→",func(): deliver(KEY_RIGHT,0))
	key(row,"← Delete",func(): deliver(KEY_BACKSPACE,0))
	key(row,"Done",func(): hide())
	hide()
func key(parent: Node, label: String, action: Callable) -> Button:
	var button:=Button.new();button.text=label;button.focus_mode=Control.FOCUS_NONE;button.custom_minimum_size=Vector2(70,42);button.size_flags_horizontal=SIZE_EXPAND_FILL;parent.add_child(button);button.pressed.connect(action)
	return button
func open_for(control: LineEdit) -> void:
	target=control;show();size=Vector2(900,300)
	position=Vector2((get_viewport_rect().size.x-size.x)/2,get_viewport_rect().size.y-size.y-14)
func send_character(value: String) -> void:
	deliver(OS.find_keycode_from_string(value.to_upper()),value.unicode_at(0))
func deliver(code: int, unicode: int) -> void:
	if not is_instance_valid(target):return
	var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.unicode=unicode;event.pressed=true
	_deliver.call_deferred(target,event)
func _deliver(control: LineEdit, event: InputEventKey) -> void:
	if not visible or target != control or not is_instance_valid(control) or not control.is_visible_in_tree():return
	control.grab_focus()
	control.get_viewport().push_input(event,true)
	var release: InputEventKey=event.duplicate();release.pressed=false;control.get_viewport().push_input(release,true)
func _process(_delta: float) -> void:
	if visible and (not is_instance_valid(target) or not target.is_visible_in_tree()): hide()
	if visible:
		# Font/container minimum sizes settle after open_for; anchor the final size.
		position = Vector2((get_viewport_rect().size.x-size.x)/2,get_viewport_rect().size.y-size.y-14)
		preview.text = target.text.insert(target.caret_column,"│")
