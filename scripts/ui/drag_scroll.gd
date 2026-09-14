## FPSloppa-derived background dragging, with GUI ownership preserved.
extends ScrollContainer
var pressed := false
var dragging := false
var start := Vector2.ZERO
var initial := 0
var vr_mode_override := false
func _ready() -> void:
	scroll_deadzone = 100000
	horizontal_scroll_mode = SCROLL_MODE_DISABLED
	vertical_scroll_mode = SCROLL_MODE_AUTO
func _gui_input(event: InputEvent) -> void:
	var vr := vr_mode_override or XRServer.primary_interface != null and XRServer.primary_interface.is_initialized()
	if not vr: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Only background events bubble here. Controls and overlays own their presses.
		var hovered := get_viewport().gui_get_hovered_control()
		while hovered != null and hovered != self:
			if hovered is BaseButton or hovered is LineEdit or hovered is TextEdit or hovered is Range or hovered is ItemList: return
			hovered = hovered.get_parent_control()
		if hovered != self: return
		pressed = true
		dragging = false
		start = get_global_mouse_position()
		initial = scroll_vertical
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree(): pressed = false; dragging = false; return
	if not pressed: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		pressed = false
		if dragging: get_viewport().set_input_as_handled()
		dragging = false
	elif event is InputEventMouseMotion:
		var distance: float = (event.position.y-start.y)/maxf(.01,get_global_transform_with_canvas().get_scale().y)
		if absf(distance) > 16: dragging = true
		if dragging:
			scroll_vertical = initial-roundi(distance)
			get_viewport().set_input_as_handled()
