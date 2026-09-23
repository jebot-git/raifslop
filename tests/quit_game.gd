extends SceneTree
func _initialize():run.call_deferred()
func run():
	var g=load("res://scenes/main.tscn").instantiate();root.add_child(g)
	await create_timer(.5).timeout
	g.game.tackle.shekels=321
	g.golf_activity.join_course("cypress")
	g._toggle_avatar_menu()
	g.avatar_menu.quit_button.pressed.emit()
	if not g.golf_activity.loading_course.is_empty() or g.golf_activity.pending_loader!=null:
		push_error("Quit failed to cancel pending golf preparation");quit(1);return
	var saved=JSON.parse_string(FileAccess.get_file_as_string("user://tackle.json"))
	if not saved is Dictionary or saved.get("shekels")!=321:
		push_error("Quit failed to save progression");quit(1);return
	print("PASS Quit button saves progression and requests exit")
	await create_timer(1).timeout
	push_error("Quit button did not exit the application");quit(1)
