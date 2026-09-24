## Reused from FPSloppa 5105fb8cfa38c76aa1d5d172af3047fe2d12ae0d.
extends VBoxContainer
## In-canvas selection: no native PopupMenu window or outside-click dismissal.
signal selected(value: String)
var trigger: Button
var popup: PanelContainer
var entries: VBoxContainer
var scroll: ScrollContainer
var value:=""
var items: Array=[]
var prompt:="SELECT"
func _init() -> void:
	trigger=Button.new();trigger.custom_minimum_size.y=48;trigger.text=prompt;add_child(trigger)
	popup=PanelContainer.new();popup.add_theme_stylebox_override("panel",preload("res://scripts/ui/waterside_theme.gd").panel(8));var layer:=CanvasLayer.new();layer.layer=50;add_child(layer);layer.add_child(popup);popup.hide()
	popup.theme=preload("res://scripts/ui/waterside_theme.gd").theme()
	scroll=preload("res://scripts/ui/drag_scroll.gd").new();scroll.custom_minimum_size.y=156;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;popup.add_child(scroll)
	entries=VBoxContainer.new();entries.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(entries)
	trigger.pressed.connect(open_popup)
func _ready() -> void:add_to_group("fishing_selectors")
func open_popup() -> void:
	for other in get_tree().get_nodes_in_group("fishing_selectors"):
		if other!=self and other.get_viewport()==get_viewport():other.popup.hide()
	popup.scale=trigger.get_global_transform_with_canvas().get_scale()
	popup.size=Vector2(trigger.size.x,156)
	popup.position=trigger.get_global_transform_with_canvas()*Vector2(0,trigger.size.y)
	popup.position.y=minf(popup.position.y,get_viewport_rect().size.y-popup.size.y*popup.scale.y-8)
	scroll.cancel_drag()
	popup.show()
func _process(_delta: float) -> void:
	if not is_visible_in_tree():popup.hide()
func configure(options: Array,label: String) -> void:
	prompt=label
	if items==options:update_label();return
	items=options.duplicate(true)
	if not items.any(func(row):return row.id==value):value=""
	for child in entries.get_children():entries.remove_child(child);child.queue_free()
	for item in items:
		var b:=Button.new();b.text=item.title;b.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;b.custom_minimum_size.y=44;entries.add_child(b)
		b.pressed.connect(func():
			choose(item.id))
	update_label()
func choose(id: String) -> void:
	if not items.any(func(row):return row.id==id):return
	value=id;popup.hide();update_label();selected.emit(id)
func update_label() -> void:
	trigger.text=prompt+"  ▾"
	for item in items:
		if item.id==value:trigger.text=item.title+"  ▾"
	trigger.disabled=items.is_empty()
func clear_selection() -> void:
	value="";popup.hide();update_label()
