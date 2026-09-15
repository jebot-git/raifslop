extends SceneTree
var failures: Array[String] = []
var view: SubViewport
func _initialize(): run.call_deferred()
func check(ok: bool, label: String):
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures.append(label)
func settle():
	for i in 8: await process_frame
func motion(at: Vector2, held := false):
	var e := InputEventMouseMotion.new(); e.position=at; e.global_position=at; e.button_mask=MOUSE_BUTTON_MASK_LEFT if held else 0; view.push_input(e,true)
func button(at: Vector2, down: bool):
	var e := InputEventMouseButton.new(); e.position=at; e.global_position=at; e.button_index=MOUSE_BUTTON_LEFT; e.pressed=down; e.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0; view.push_input(e,true)
func click(control: Control, jitter := 0.0):
	var at := control.get_global_rect().get_center()
	motion(at); await settle(); button(at,true); motion(at+Vector2(0,jitter),true); await settle(); button(at+Vector2(0,jitter),false); await settle()
func key(menu, label: String):
	for b in menu.keyboard.find_children("*","Button",true,false):
		if b.text==label: await click(b,12); return
	check(false,"Key exists: "+label)
func check_list_drag(list:ItemList,label:String):
	list.vr_mode_override=true
	for i in 32:list.add_item("Scroll test %d"%i)
	list.select(0);list.get_v_scroll_bar().value=0;await settle()
	var at:Vector2=list.global_position+Vector2(list.size.x*.5,140)
	motion(at);await settle();button(at,true);motion(at-Vector2(0,100),true);await settle();button(at-Vector2(0,100),false);await settle()
	check(list.get_v_scroll_bar().value>80 and list.get_selected_items()[0]==0,label+" drags without selecting an avatar/file")
	check(list.get_v_scroll_bar().modulate.a==0,label+" hides the VR scrollbar")
func run():
	var g=load("res://scenes/main.tscn").instantiate(); root.add_child(g); await settle()
	g.set_process(false);g.motor.set_physics_process(false)
	view=SubViewport.new();view.size=Vector2i(1000,720);root.add_child(view)
	var menu=g.avatar_menu; menu.reparent(view); menu.position=Vector2(50,30);menu.size=Vector2(900,656);menu.scale=Vector2.ONE;menu.show()
	for page in menu.pages.values(): page.view.vr_mode_override=true
	menu.show_page("avatar");await settle()
	await check_list_drag(menu.list,"VRM library")
	menu.refresh();await settle()
	check(menu.import_button.get_global_rect().end.y<690 and not menu.pages.avatar.view.is_ancestor_of(menu.import_button),"Import action remains visible outside scrolling content")
	await click(menu.import_button,12)
	check(menu.vrm_browser.visible and not menu.picker.visible,"Trigger-sized jitter opens in-headset import browser instead of dragging page")
	await check_list_drag(menu.vrm_browser.files,"VRM import browser")
	var turning:bool=menu.turn_mode.button_pressed
	await click(menu.turn_mode)
	check(menu.turn_mode.button_pressed==turning,"Import browser blocks clicks into the menu underneath")
	var fixture:=OS.get_user_data_dir().path_join("browser-fixture")
	DirAccess.make_dir_recursive_absolute(fixture.path_join("avatars"))
	DirAccess.copy_absolute("res://assets/avatars/vita.vrm",fixture.path_join("avatars/test.vrm"))
	FileAccess.open(fixture.path_join("ignored.txt"),FileAccess.WRITE).store_string("not an avatar")
	var browser=menu.vrm_browser;browser.browse(fixture);await settle()
	check(browser.files.item_count==1,"Browser lists folders and filters unrelated files")
	var at:Vector2=browser.files.global_position+browser.files.get_item_rect(0).get_center();motion(at);button(at,true);button(at,false);await settle()
	await click(browser.open_button)
	check(browser.directory.ends_with("avatars") and browser.files.item_count==1,"Browser Open navigates selected folder")
	at=browser.files.global_position+browser.files.get_item_rect(0).get_center();motion(at);button(at,true);button(at,false);await settle();await click(browser.open_button)
	await create_timer(.5).timeout
	check(not browser.visible and not g.avatar_loading and g.avatars.selected_path.begins_with(g.AvatarLibrary.CACHE),"Selected VRM imports and equips through actual menu signal")
	menu.show_page("together");await settle()
	var field:LineEdit=menu.multiplayer_page.find_children("*","LineEdit",true,false)[0]
	field.text="";field.grab_focus();menu.keyboard.open_for(field);await settle()
	var scroll:int=menu.pages.together.view.scroll_vertical
	await key(menu,"q");await key(menu,"Space");await key(menu,"Shift");await key(menu,"W")
	check(field.text=="q W","Pointer presses type letters, spaces and shifted characters")
	await key(menu,"← Delete")
	check(field.text=="q " and g.network.display_name=="q ","Backspace updates field and saved multiplayer preference")
	check(menu.pages.together.view.scroll_vertical==scroll,"Keyboard presses with cursor movement cannot drag the page behind it")
	check(menu.keyboard.get_global_rect().end.y<=720 and menu.keyboard.preview.text.contains("q "),"Keyboard fits viewport and shows text being edited")
	await key(menu,"Done");check(not menu.keyboard.visible,"Done dismisses keyboard")
	var heading:Control=menu.multiplayer_page.get_child(0)
	at=heading.get_global_rect().get_center();motion(at);await settle();button(at,true);motion(at-Vector2(0,45),true);await settle();button(at-Vector2(0,45),false);await settle()
	check(menu.pages.together.view.scroll_vertical>scroll,"Empty page background still supports deliberate drag scrolling")
	menu.show_page("waters");menu.location_list.vr_mode_override=true;await settle()
	var waters:ItemList=menu.location_list
	waters.select(0);waters.get_v_scroll_bar().value=0;await settle()
	var outer_scroll:int=menu.pages.waters.view.scroll_vertical
	at=waters.global_position+waters.get_item_rect(2).get_center()
	motion(at);await settle();button(at,true);motion(at-Vector2(0,95),true);await settle();button(at-Vector2(0,95),false);await settle()
	check(waters.get_v_scroll_bar().value>80,"VR trigger drag scrolls water rows")
	check(waters.get_selected_items()[0]==0 and menu.pages.waters.view.scroll_vertical==outer_scroll,"Water dragging neither selects a row nor drags its parent page")
	check(waters.get_v_scroll_bar().modulate.a==0,"VR water browsing does not require scrollbar targeting")
	waters.get_v_scroll_bar().value=0;await settle()
	at=waters.global_position+waters.get_item_rect(1).get_center()
	motion(at);await settle();button(at,true);motion(at+Vector2(0,3),true);button(at+Vector2(0,3),false);await settle()
	check(waters.get_selected_items()[0]==1 and menu.location_description.text.contains(g.Locations.CATALOG[1].mood),"A stationary VR release selects and previews the water")
	menu.show_page("controls");menu.smooth_turn_speed.value=75;menu.snap_turn_angle.value=30;await settle()
	check(menu.smooth_turn_speed.get_global_rect().end.y<690 and menu.snap_turn_angle.get_global_rect().end.y<690,"Both turning controls fit without scrolling")
	await click(menu.smooth_turn_speed.get_parent().get_child(2))
	await click(menu.snap_turn_angle.get_parent().get_child(2))
	check(g.motor.smooth_turn_speed==90 and g.motor.snap_turn_angle==45,"Large plus buttons change smooth speed and snap angle")
	var cfg:=ConfigFile.new();cfg.load("user://player.cfg")
	check(cfg.get_value("controls","smooth_turn_speed")==90 and cfg.get_value("controls","snap_turn_angle")==45,"Turning adjustments save immediately")
	g.motor.smooth_turn_speed=75;g.motor.snap_turn_angle=30;g._load_player_preferences()
	check(g.motor.smooth_turn_speed==90 and g.motor.snap_turn_angle==45,"Turning values restore from disk")
	g.motor.smooth_turn=true
	var before:Basis=g.origin.global_basis
	g.motor.apply_turn_input(1,.5)
	check(g.origin.global_basis.is_equal_approx(Basis(Vector3.UP,deg_to_rad(-45))*before),"Smooth rotation uses selected degrees per second")
	g.motor.smooth_turn=false;g.motor.turn_latched=false;before=g.origin.global_basis
	g.motor.apply_turn_input(1,.02);g.motor.apply_turn_input(1,.02)
	check(g.origin.global_basis.is_equal_approx(Basis(Vector3.UP,deg_to_rad(-45))*before),"Snap uses selected angle once per stick deflection")
	g.motor.apply_turn_input(0,.02);g.motor.apply_turn_input(1,.02)
	check(g.origin.global_basis.is_equal_approx(Basis(Vector3.UP,deg_to_rad(-90))*before),"Centering rearms the next snap")
	menu.close_overlays();menu.reparent(g);view.queue_free();g.queue_free();await settle();await create_timer(.3).timeout
	print("MENU_CONTROLS_RESULT ",failures);quit(0 if failures.is_empty() else 1)
