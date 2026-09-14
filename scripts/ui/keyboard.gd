extends PanelContainer
## FPSloppa-style deferred key delivery to the focused menu viewport.
var target: LineEdit
var shift := false
func _ready() -> void:
	theme=preload("res://scripts/ui/waterside_theme.gd").theme()
	var column:=VBoxContainer.new();add_child(column)
	var grid:=GridContainer.new();grid.columns=10;column.add_child(grid)
	for character in "1234567890qwertyuiopasdfghjkl-zxcvbnm.:_":
		key(grid,character,func(): send_character(character.to_upper() if shift else character))
	var row:=HBoxContainer.new();column.add_child(row)
	key(row,"Shift",func(): shift=not shift)
	key(row,"Space",func(): send_character(" "))
	key(row,"← Delete",func(): deliver(KEY_BACKSPACE,0))
	key(row,"Done",func(): hide())
	hide()
func key(parent: Node, label: String, action: Callable) -> void:
	var button:=Button.new();button.text=label;button.focus_mode=Control.FOCUS_NONE;button.custom_minimum_size=Vector2(70,42);button.size_flags_horizontal=SIZE_EXPAND_FILL;parent.add_child(button);button.pressed.connect(action)
func open_for(control: LineEdit) -> void:
	target=control;show();size=Vector2(760,270)
	position=Vector2((get_viewport_rect().size.x-size.x)/2,get_viewport_rect().size.y-size.y-14)
func send_character(value: String) -> void:
	deliver(OS.find_keycode_from_string(value.to_upper()),value.unicode_at(0))
func deliver(code: int, unicode: int) -> void:
	if not is_instance_valid(target):return
	var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.unicode=unicode;event.pressed=true
	_deliver.call_deferred(target,event)
func _deliver(control: LineEdit, event: InputEventKey) -> void:
	if not is_instance_valid(control) or not control.has_focus() or not control.is_visible_in_tree():return
	control.get_viewport().push_input(event,true)
	var release: InputEventKey=event.duplicate();release.pressed=false;control.get_viewport().push_input(release,true)
func _process(_delta: float) -> void:
	if visible and (not is_instance_valid(target) or not target.is_visible_in_tree()): hide()
