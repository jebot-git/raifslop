extends Control
const Icons=preload("res://addons/golfminus/scripts/golf/pictograms.gd")
const ACTIONS={"Preview club angle & reach from address pose":["fit","Fit club"],"Undo last accepted fit":["return","Undo fit"],"Reverse fitted club face":["orbit","Reverse face"],"Stash / retrieve club":["stash","Stash / retrieve"],"Avatar, tracking & shared settings":["tracking","Avatar & settings"],"Scorecard":["score","Scorecard"],"Godview · course & shot trajectory":["godview","Godview"],"Hole / course tracker":["course","Course tracker"],"Resume saved round":["return","Resume round"],"Putting practice":["putter","Putting practice"],"Start local swing capture":["capture","Record swings"],"Return to course":["return","Return to course"],"Courses":["course","Courses"],"Controls":["tracking","Controls"],"Round":["flag","Round"]}
var icon_buttons:Array[Button]=[]
var icon_hints:Array[Control]=[]
var text_hints:Array[Control]=[]
var icons_were_enabled:=true
const Style=preload("res://scripts/ui/waterside_theme.gd")
var game: Node
var menu: PanelContainer
var menu_content: BoxContainer
var menu_scroll: ScrollContainer
var stats: Label
var club_text: Label
var message: Label
var power: ProgressBar
var map: Control
var score: Label
var course_title: Label
var tee_choice: OptionButton
var hand_choice: CheckButton
var length_slider: HSlider
var attachment_controls:VBoxContainer
var play_button: Button
var analytics_button: Button
var tag: Label
var modal := true
var pages:Dictionary={}
var tabs:HBoxContainer
var page_host:VBoxContainer
func label(parent: Node,text: String,size_px:=20,color:=Color("e4ead7")) -> Label:
	var l:=Label.new();l.text=text;l.add_theme_font_size_override("font_size",size_px);l.add_theme_color_override("font_color",color);parent.add_child(l);return l
func button(parent: Node,text: String,callback: Callable) -> Button:
	var b:=Button.new();b.text=text;b.tooltip_text=text;b.custom_minimum_size.y=46;parent.add_child(b);b.pressed.connect(callback)
	if ACTIONS.has(text):
		b.set_meta("symbol",ACTIONS[text][0]);b.text=ACTIONS[text][1];b.expand_icon=true;b.add_theme_constant_override("icon_max_width",32);b.add_theme_constant_override("h_separation",12);icon_buttons.append(b)
		if Icons.enabled:b.icon=Icons.texture(ACTIONS[text][0])
	return b
func guidance(parent:Node,entries:Array)->void:
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",18);parent.add_child(row);icon_hints.append(row);row.visible=Icons.enabled
	for entry in entries:
		var cell:=VBoxContainer.new();cell.tooltip_text=entry[2];row.add_child(cell)
		var symbol:=TextureRect.new();symbol.texture=Icons.texture(entry[0]);symbol.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;symbol.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;symbol.custom_minimum_size=Vector2(42,42);symbol.mouse_filter=Control.MOUSE_FILTER_IGNORE;cell.add_child(symbol)
		var binding:=label(cell,entry[1],14,Style.MUTED);binding.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
func refresh_icons()->void:
	icons_were_enabled=Icons.enabled
	for b in icon_buttons:b.icon=Icons.texture(b.get_meta("symbol")) if Icons.enabled else null
	for hint in icon_hints:hint.visible=Icons.enabled
	for hint in text_hints:hint.visible=not Icons.enabled
func panel(pos: Vector2,dimensions: Vector2) -> PanelContainer:
	var p:=PanelContainer.new();p.position=pos;p.size=dimensions;p.add_theme_stylebox_override("panel",Style.panel(8));add_child(p);return p
func _ready() -> void:
	theme=Style.theme();mouse_filter=Control.MOUSE_FILTER_IGNORE
	var branding:=label(self,"G / −    GOLF MINUS",21,Style.BRASS);branding.position=Vector2(34,22)
	var ecosystem:=label(self,"REAL AI OUTDOORS   /   GOLF",14,Style.MUTED);ecosystem.position=Vector2(1020,28)
	var top:=panel(Vector2(32,76),Vector2(334,126))
	var v:=VBoxContainer.new();top.add_child(v)
	course_title=label(v,"DALKEY LINKS",16,Style.BRASS)
	stats=label(v,"HOLE 01     PAR 4     308 m",22)
	tag=label(v,"CLUB TEES  ·  STROKE PLAY",13,Style.MUTED)
	var map_panel:=panel(Vector2(1220,90),Vector2(184,310))
	map_panel.visible=not game.xr
	var mv:=VBoxContainer.new();map_panel.add_child(mv);label(mv,"YARDAGE BOOK",12,Style.BRASS)
	map=preload("res://addons/golfminus/scripts/golf/hole_map.gd").new();map.game=game;map.custom_minimum_size=Vector2(145,242);mv.add_child(map)
	var bottom:=panel(Vector2(32,678),Vector2(460,184))
	var bv:=VBoxContainer.new();bottom.add_child(bv)
	club_text=label(bv,"DRIVER",25)
	power=ProgressBar.new();power.custom_minimum_size=Vector2(400,12);power.show_percentage=false;bv.add_child(power)
	message=label(bv,"",16,Style.BRASS)
	text_hints.append(label(bv,"Grip/trigger: swing, lock movement · release: walk" if game.xr else "SPACE: swing · TAB + arrows: club bag · H: stash · J: guide",14,Style.MUTED))
	text_hints.append(label(bv,"Other hip + grip: hole / course tracker" if game.xr else "T: address · G: grid · ESC: field station",14,Style.MUTED))
	guidance(bv,[["swing","Grip / trigger" if game.xr else "Space","Hold either to swing and lock stick movement"],["stash","Hip" if game.xr else "H","Grip at striking-hand hip to stash or retrieve"],["bag","Club-hand click" if game.xr else "Tab","Click to open; point then centre to select. Click again to close"],["godview","Other click" if game.xr else "V","Toggle Godview"],["menu","B" if game.xr else "Esc","Open field station"]])
	score=label(self,"",18);score.position=Vector2(560,818)
	menu=panel(Vector2(395,76),Vector2(670,768))
	var shell:=VBoxContainer.new();shell.add_theme_constant_override("separation",12);menu.add_child(shell)
	label(shell,"Field station · Golf",28,Style.BRASS)
	tabs=HBoxContainer.new();shell.add_child(tabs)
	page_host=VBoxContainer.new();page_host.size_flags_vertical=Control.SIZE_EXPAND_FILL;shell.add_child(page_host)
	var box:=_register_page("courses","Courses")
	label(box,"T H E   C L U B H O U S E",14,Style.BRASS)
	label(box,"A little closer to the outdoors.",30)
	label(box,"Four courses. Seventy-two holes. Your next round.",17,Style.MUTED)
	for id in preload("res://addons/golfminus/scripts/golf/catalog.gd").ACTIVE:
		button(box,preload("res://addons/golfminus/scripts/golf/catalog.gd").NAMES[id],game.select_course.bind(id))
	box=_register_page("controls","Controls")
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",14);box.add_child(row)
	tee_choice=OptionButton.new();for t in ["Club tees","Forward tees","Back tees"]:tee_choice.add_item(t)
	row.add_child(tee_choice);tee_choice.item_selected.connect(func(i):game.tee_kind=["club","forward","back"][i])
	hand_choice=CheckButton.new();hand_choice.text="Left-handed swing";row.add_child(hand_choice)
	hand_choice.toggled.connect(game.set_hand)
	label(box,"VR club reach  ·  adjust until the head rests on the turf",14,Style.MUTED)
	length_slider=HSlider.new();length_slider.min_value=.35;length_slider.max_value=1.6;length_slider.step=.01;length_slider.value=1.0;box.add_child(length_slider)
	length_slider.custom_minimum_size.y=46
	length_slider.value_changed.connect(game.set_club_reach)
	attachment_controls=preload("res://addons/golfminus/scripts/golf/attachment_controls.gd").new();attachment_controls.game=game;box.add_child(attachment_controls)
	button(box,"Preview club angle & reach from address pose",func():game.begin_club_fit())
	button(box,"Undo last accepted fit",func():game.undo_club_fit())
	button(box,"Reverse fitted club face",func():game.flip_club_face())
	if not is_instance_valid(game.host_activity):button(box,"Stash / retrieve club",func():game.equipment.set_stowed(not game.equipment.stowed))

	else:
		var turning:=CheckButton.new();turning.text="Smooth turning";turning.button_pressed=game.body.smooth_turn;box.add_child(turning)
		turning.toggled.connect(func(value):game.body.smooth_turn=value;game._save_preferences())
		for entry in [["Smooth turn speed (degrees/sec)","smooth_turn_speed",30,360,5],["Snap turn angle (degrees)","snap_turn_angle",15,90,5]]:
			label(box,entry[0],14,Style.MUTED)
			var slider:=HSlider.new();slider.min_value=entry[2];slider.max_value=entry[3];slider.step=entry[4];slider.value=game.body.get(entry[1]);box.add_child(slider)
			slider.value_changed.connect(func(value):game.body.set(entry[1],value);game._save_preferences())
	if not is_instance_valid(game.host_activity):
		var icons_toggle:=CheckButton.new();icons_toggle.text="Guiding icons";icons_toggle.button_pressed=Icons.enabled;box.add_child(icons_toggle)
		icons_toggle.toggled.connect(func(value):Icons.enabled=value;refresh_icons();game._save_preferences())
	box=pages.courses.page
	play_button=button(box,"BEGIN ROUND   →",func():game.start_round())
	button(box,"Resume saved round",func():game.resume_round())
	button(box,"Putting practice",func():game.start_practice())
	box=_register_page("round","Round")
	button(box,"Scorecard",show_scorecard)
	button(box,"Godview · course & shot trajectory",func():game.godview.enter())
	button(box,"Hole / course tracker",func():
		game.toggle_menu(false)
		if game.xr:game.status_text="Grab the tracker at your non-striking-hand hip."
		else:game.course_guide.toggle())
	analytics_button=button(box,"Start local swing capture",func():game.toggle_analytics())
	game.telemetry.capture_changed.connect(func(active):analytics_button.text="Save capture" if active else "Record swings")
	var footer:=HBoxContainer.new();shell.add_child(footer)
	for step in [-1,1]:button(footer,"↑" if step<0 else "↓",func():menu_scroll.scroll_vertical+=step*180)
	button(footer,"Return to course",func():game.toggle_menu(false))
	menu_content=footer
	show_page("courses")
	text_hints.append(label(box,"VR: grip/trigger locks movement for swing • release to walk\nClub hand A/X: address • B/Y: menu • stick click: bag\nPoint then centre to equip; click again to close • Other stick click: Godview",14,Style.MUTED))
	guidance(box,[["ball","Club A/X" if game.xr else "T","Address ball"],["grid","Other trigger" if game.xr else "G","Green grid"],["course","Other hip" if game.xr else "J","Hole and course tracker"],["godview","Other click" if game.xr else "V","Course and shot overview"]])
	refresh_icons()
	refresh()
func _register_page(id:String,title:String)->VBoxContainer:
	var scroll:=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;page_host.add_child(scroll)
	var box:=VBoxContainer.new();box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;box.add_theme_constant_override("separation",9);scroll.add_child(box)
	var tab:=button(tabs,title,func():show_page(id));tab.toggle_mode=true
	pages[id]={"view":scroll,"page":box,"button":tab}
	return box
func show_page(id:String)->void:
	for key in pages:
		pages[key].view.visible=key==id;pages[key].button.set_pressed_no_signal(key==id)
	menu_scroll=pages[id].view
func refresh() -> void:
	if not is_instance_valid(game) or game.model.hole.is_empty():return
	if icons_were_enabled!=Icons.enabled:refresh_icons()
	var m=game.model
	course_title.text=m.course.name.to_upper()
	var distance: float=Vector2(game.ball.position.x-m.pin().x,game.ball.position.z-m.pin().z).length()
	stats.text="HOLE %02d    PAR %d    %.0f m"%[game.round_state.hole+1,m.hole.par,distance]
	var wind: Vector3=m.wind()
	tag.text="%s   ·   WIND %.1f m/s"%[m.hole.name.to_upper(),wind.length()]
	club_text.text="%s   /   %s"%[game.CLUBS.BAG[game.club_index].name.to_upper(),m.lie(game.ball.position.x,game.ball.position.z).to_upper()]
	power.value=game.power*100
	message.text=game.status_text
	score.text="STROKES  %d    |    COMPLETED  %d / 18    |    TOTAL  %d"%[game.round_state.strokes,game.round_state.scores.size(),game.round_state.total()]
	play_button.text="BEGIN ROUND AT %s   →"%m.course.name.to_upper()
	map.queue_redraw()

func show_scorecard() -> void:
	var dialog:=AcceptDialog.new();dialog.title=game.model.course.name+" · Scorecard"
	var text:="HOLE     PAR     STROKES\n"
	var par_total:=0
	for i in game.model.course.holes.size():
		var par_value:=int(game.model.course.holes[i].par)
		var value:=("F" if game.round_state.scores[i]<0 else str(game.round_state.scores[i])) if i<game.round_state.scores.size() else str(game.round_state.strokes)+" *" if i==game.round_state.hole else "—"
		text+="%02d           %d         %s\n"%[i+1,par_value,value]
		if i<game.round_state.scores.size():par_total+=par_value
	text+="\nCompleted: %d strokes (%+d to par)\n* Current hole"%[game.round_state.total(),game.round_state.total()-par_total]
	dialog.dialog_text=text;add_child(dialog);dialog.confirmed.connect(dialog.queue_free);dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(500,650))
