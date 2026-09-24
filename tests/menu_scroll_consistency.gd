extends SceneTree
const Router=preload("res://scripts/ui/scroll_router.gd")
var failures:Array[String]=[]
var view:SubViewport
var checks:=0
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);push_error(label)
func settle():
 for i in 8:await process_frame
func motion(at:Vector2,held:=false):
 var e:=InputEventMouseMotion.new();e.position=at;e.global_position=at;e.button_mask=MOUSE_BUTTON_MASK_LEFT if held else 0;view.push_input(e,true)
func button(at:Vector2,down:bool):
 var e:=InputEventMouseButton.new();e.position=at;e.global_position=at;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;view.push_input(e,true)
func run():
 view=SubViewport.new();view.size=Vector2i(640,480);root.add_child(view)
 var scroll=preload("res://scripts/ui/drag_scroll.gd").new();scroll.position=Vector2(20,20);scroll.size=Vector2(600,400);view.add_child(scroll)
 var box:=VBoxContainer.new();box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(box)
 var toggle:=CheckButton.new();toggle.text="Keep this setting";toggle.button_pressed=true;toggle.custom_minimum_size.y=60;box.add_child(toggle)
 var choice=preload("res://scripts/ui/vr_option.gd").new();box.add_child(choice)
 for i in 20:choice.add_item("Option %d"%i)
 var clicks:Array[int]=[]
 for i in 20:
  var b:=Button.new();b.text="Action %d"%i;b.custom_minimum_size.y=48;box.add_child(b);b.pressed.connect(func():clicks.append(i))
 await settle()
 var at:Vector2=box.get_child(3).get_global_rect().get_center()
 motion(at);await settle();button(at,true);motion(at-Vector2(0,90),true);button(at-Vector2(0,90),false);await settle()
 check(scroll.scroll_vertical>70 and clicks.is_empty(),"Dragging action buttons scrolls without activation")
 scroll.scroll_vertical=0;await settle();at=toggle.get_global_rect().get_center();motion(at);await settle();button(at,true);motion(at-Vector2(0,60),true);button(at-Vector2(0,60),false);await settle()
 check(toggle.button_pressed,"Dragging a toggle preserves its setting")
 scroll.scroll_vertical=0;await settle()
 motion(Vector2(5,5));await settle()
 for i in 10:Router.scroll(view,.4,scroll)
 check(scroll.scroll_vertical>=3,"Fractional joystick motion accumulates")
 var bar:VScrollBar=scroll.get_v_scroll_bar();check(bar.visible and bar.modulate.a==1 and bar.mouse_filter==Control.MOUSE_FILTER_IGNORE and bar.focus_mode==Control.FOCUS_NONE,"Visible scrollbar cannot capture pointer or focus")
 var before:int=scroll.scroll_vertical;at=bar.get_global_rect().get_center();motion(at);await settle();button(at,true);button(at,false);await settle()
 check(scroll.scroll_vertical==before,"Clicking scrollbar track does not jump content")
 scroll.scroll_vertical=0;await settle();choice.open_popup();await settle()
 before=scroll.scroll_vertical;motion(Vector2(5,5));Router.scroll(view,120,scroll);await settle()
 check(choice.scroll.scroll_vertical>100 and scroll.scroll_vertical==before,"Open selector receives joystick scrolling before page")
 choice.scroll.scroll_vertical=0;await settle();at=choice.entries.get_child(1).get_global_rect().get_center();motion(at);await settle();button(at,true);motion(at-Vector2(0,70),true);button(at-Vector2(0,70),false);await settle()
 check(choice.popup.visible and choice.value=="0" and choice.scroll.scroll_vertical>50,"Dragging selector rows neither selects nor dismisses popup")
 choice.scroll.scroll_vertical=0;await settle();at=choice.entries.get_child(1).get_global_rect().get_center();motion(at);await settle();button(at,true);motion(at+Vector2(0,4),true);button(at+Vector2(0,4),false);await settle()
 check(not choice.popup.visible and choice.value=="1","Stationary jitter selects intended option")
 var joy:=InputEventJoypadMotion.new();joy.device=0;joy.axis=JOY_AXIS_LEFT_Y;joy.axis_value=.7;Input.parse_input_event(joy);await settle()
 check(Router.device_axis(0)>.6,"Left desktop joystick is accepted")
 joy.axis_value=.1;Input.parse_input_event(joy);await settle();check(Router.device_axis(0)==0,"Stick deadzone suppresses drift")
 joy.axis=JOY_AXIS_RIGHT_Y;joy.axis_value=-.8;Input.parse_input_event(joy);await settle();check(Router.device_axis(0)<-.7,"Right desktop joystick is accepted")
 view.queue_free();await settle();print("MENU_SCROLL_CONSISTENCY_RESULT ",checks," checks, ",failures);quit(0 if failures.is_empty() else 1)
