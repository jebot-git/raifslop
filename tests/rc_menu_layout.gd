extends SceneTree
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,message:String)->void:
	if not ok:failures.append(message);push_error(message)
func settle()->void:
	for i in 8:await process_frame
func inspect(menu,id:String)->void:
	menu.show_page(id);await settle()
	var scroll:ScrollContainer=menu.pages[id].view
	var page:Control=menu.pages[id].page
	check(menu.get_global_rect().end.x<=1000 and menu.get_global_rect().end.y<=720,"Menu fits the VR texture: "+id)
	check(page.size.x<=scroll.size.x,"No horizontal page clipping: %s (%s / %s)"%[id,page.size.x,scroll.size.x])
	check(menu.tabs.get_global_rect().end.x<=menu.get_global_rect().end.x-18,"Navigation fits: "+id)
	check(menu.resume_button.get_global_rect().end.y<=menu.get_global_rect().end.y-18,"Return action stays visible: "+id)
func run()->void:
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await settle()
	game.set_process(false);game.motor.set_physics_process(false)
	var view:=SubViewport.new();view.size=Vector2i(1000,720);view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
	var menu=game.avatar_menu;menu.reparent(view);menu.position=Vector2(50,30);menu.size=Vector2(900,656);menu.show()
	check(menu.tabs.get_child_count()==5,"Five logical top-level sections")
	for id in menu.pages:await inspect(menu,id)
	for category in menu.Locations.WATER_TYPES:
		menu.open_water_category(category.id);await inspect(menu,"waters")
	for id in ["online","lan","voice"]:
		menu.multiplayer_page.show_section(id);await inspect(menu,"together")
	for id in ["controls","alignment"]:await inspect(menu,id)
	if "--capture" in OS.get_cmdline_user_args():
		for id in ["activities","settings","controls","together"]:
			menu.show_page(id);await settle();await RenderingServer.frame_post_draw
			view.get_texture().get_image().save_png("/tmp/rc-menu-"+id+".png")
	menu.reparent(game);view.queue_free();game.queue_free();await settle()
	print("RC_MENU_LAYOUT_RESULT ",failures);quit(0 if failures.is_empty() else 1)
