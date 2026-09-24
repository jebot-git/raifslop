extends RefCounted
## One owner per scroll gesture: open selector, pointed list, then active page.
static func indicator(bar:ScrollBar)->void:
	bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
	bar.focus_mode=Control.FOCUS_NONE
	bar.modulate.a=1.0
static func move(target:Control,pixels:float)->bool:
	if target is ItemList:
		target.get_v_scroll_bar().value+=pixels;return true
	if target is ScrollContainer:
		if target.has_method("scroll_pixels"):target.scroll_pixels(pixels)
		else:target.scroll_vertical+=roundi(pixels)
		return true
	return false
static func scroll(view:Viewport,pixels:float,fallback:Control=null)->void:
	if not is_finite(pixels):return
	for selector in view.get_tree().get_nodes_in_group("fishing_selectors"):
		if selector.get_viewport()==view and selector.is_visible_in_tree() and selector.popup.visible:
			move(selector.scroll,pixels);return
	var hovered:=view.gui_get_hovered_control()
	while hovered!=null:
		if move(hovered,pixels):return
		hovered=hovered.get_parent_control()
	if is_instance_valid(fallback) and fallback.is_visible_in_tree():move(fallback,pixels)
static func device_axis(device:int)->float:
	var value:=0.0
	for axis in [JOY_AXIS_LEFT_Y,JOY_AXIS_RIGHT_Y]:
		var candidate:=Input.get_joy_axis(device,axis)
		if absf(candidate)>absf(value):value=candidate
	return value if absf(value)>.2 else 0.0
static func joystick_axis()->float:
	var value:=0.0
	for device in Input.get_connected_joypads():
		var candidate:=device_axis(device)
		if absf(candidate)>absf(value):value=candidate
	return value
