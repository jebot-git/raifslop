extends ScrollContainer
## Drag anywhere on content/buttons; sliders and text fields retain ownership.
const Router=preload("res://scripts/ui/scroll_router.gd")
var pressed:=false
var dragging:=false
var start:=Vector2.ZERO
var initial:=0
var pressed_button:BaseButton
var remainder:=0.0
var original_toggle:=false
func _ready()->void:
	scroll_deadzone=100000
	horizontal_scroll_mode=SCROLL_MODE_DISABLED
	vertical_scroll_mode=SCROLL_MODE_AUTO
	Router.indicator(get_v_scroll_bar());Router.indicator(get_h_scroll_bar())
func scroll_pixels(pixels:float)->void:
	remainder+=pixels
	var step:=int(remainder);remainder-=step
	scroll_vertical+=step
func cancel_drag()->void:
	if dragging and is_instance_valid(pressed_button):pressed_button.set_pressed_no_signal(original_toggle if pressed_button.toggle_mode else false)
	pressed=false;dragging=false;pressed_button=null
func _process(_dt:float)->void:
	if not is_visible_in_tree():cancel_drag()
func _input(event:InputEvent)->void:
	if not is_visible_in_tree():cancel_drag();return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed:
			var hovered:=get_viewport().gui_get_hovered_control()
			var candidate:BaseButton
			while hovered!=null and hovered!=self:
				if hovered is ScrollContainer or hovered is ItemList or hovered is Range or hovered is LineEdit or hovered is TextEdit:return
				if hovered is BaseButton:candidate=hovered
				hovered=hovered.get_parent_control()
			if hovered!=self:return
			pressed=true;dragging=false;pressed_button=candidate
			original_toggle=candidate.button_pressed if is_instance_valid(candidate) else false
			start=event.position;initial=scroll_vertical
		elif pressed:
			if dragging:get_viewport().set_input_as_handled()
			cancel_drag()
	elif event is InputEventMouseMotion and pressed:
		var distance:float=(event.position.y-start.y)/maxf(.01,get_global_transform_with_canvas().get_scale().y)
		if absf(distance)>16:dragging=true
		if dragging:
			if is_instance_valid(pressed_button):pressed_button.set_pressed_no_signal(original_toggle if pressed_button.toggle_mode else false)
			scroll_vertical=initial-roundi(distance)
			get_viewport().set_input_as_handled()
