extends ItemList
## Trigger-and-drag owns the list in VR; a stationary release selects a row.
var pressed := false
var dragging := false
var drag_start := Vector2.ZERO
var initial_scroll := 0.0
var pressed_row := -1
func _process(_delta:float) -> void:
 var bar:=get_v_scroll_bar()
 preload("res://scripts/ui/scroll_router.gd").indicator(bar)
 if not is_visible_in_tree():pressed=false;dragging=false
func _input(event:InputEvent) -> void:
 if not is_visible_in_tree():return
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
  if event.pressed:
   # Do not steal a press from a popup or another control above this list.
   if get_viewport().gui_get_hovered_control()!=self:return
   drag_start=event.position;initial_scroll=get_v_scroll_bar().value
   pressed_row=get_item_at_position(get_global_transform_with_canvas().affine_inverse()*event.position,true)
   pressed=true;dragging=false;grab_focus()
  elif pressed:
   var local_point:Vector2=get_global_transform_with_canvas().affine_inverse()*event.position
   if not dragging and Rect2(Vector2.ZERO,size).has_point(local_point) and pressed_row>=0 and get_item_at_position(local_point,true)==pressed_row:
    select(pressed_row);item_selected.emit(pressed_row)
   pressed=false;dragging=false
  else:return
  get_viewport().set_input_as_handled()
 elif event is InputEventMouseMotion and pressed:
  var travel:Vector2=(event.position-drag_start)/get_global_transform_with_canvas().get_scale()
  if travel.length()>12:dragging=true
  if dragging:get_v_scroll_bar().value=initial_scroll-travel.y
  get_viewport().set_input_as_handled()
