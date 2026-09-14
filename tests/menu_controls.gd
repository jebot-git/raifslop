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
func run():
	var g=load("res://scenes/main.tscn").instantiate(); root.add_child(g); await settle()
	g.set_process(false);g.motor.set_physics_process(false)
	view=SubViewport.new();view.size=Vector2i(1000,720);root.add_child(view)
	var menu=g.avatar_menu; menu.reparent(view); menu.position=Vector2(50,30);menu.size=Vector2(900,656);menu.scale=Vector2.ONE;menu.show()
	for page in menu.pages.values(): page.view.vr_mode_override=true
	menu.show_page("avatar");await settle()
	check(menu.import_button.get_global_rect().end.y<690 and not menu.pages.avatar.view.is_ancestor_of(menu.import_button),"Import action remains visible outside scrolling content")
	await click(menu.import_button,12)
	check(menu.vrm_browser.visible and not menu.picker.visible,"Trigger-sized jitter opens in-headset import browser instead of dragging page")
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
	menu.close_overlays();menu.reparent(g);view.queue_free();g.queue_free();await settle();await create_timer(.3).timeout
	print("MENU_CONTROLS_RESULT ",failures);quit(0 if failures.is_empty() else 1)
