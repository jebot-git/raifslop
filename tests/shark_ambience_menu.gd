extends SceneTree
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func run():
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await create_timer(.3).timeout
	game.set_process(false);game.motor.set_physics_process(false)
	check(game.avatars.selected_path=="res://assets/avatars/sharkperson.vrm","New profile equips SharkPerson")
	check(is_instance_valid(game.avatar) and game.avatar.skeleton!=null,"Shark humanoid rig loads")
	check(game.avatar.mouth.binds.slice(0,5).all(func(b):return not b.is_empty()),"Shark has all five vowel expressions")
	check(not game.avatar.eyes.binds[4].is_empty() and not game.avatar.eyes.binds[5].is_empty(),"Shark has left and right blink bindings")
	var menu=game.avatar_menu;menu.show();game._layout_avatar_menu()
	check(menu.tabs.get_child_count()==6 and menu.pages.has("help"),"Six section tabs plus header tutorial")
	for id in menu.pages:
		menu.show_page(id);await process_frame
		check(menu.pages.values().filter(func(row):return row.view.visible).size()==1,"Only selected page visible: "+id)
		check(menu.pages[id].button.button_pressed,"Selected tab stays highlighted: "+id)
	menu.show_page("together");await process_frame
	var choices=menu.multiplayer_page.find_children("*","VBoxContainer",true,false).filter(func(n):return n.get_script()==preload("res://scripts/ui/choice.gd"))
	check(choices.size()==2,"Voice selectors use in-panel FPSloppa controls")
	if not choices.is_empty():
		choices[0].open_popup();check(choices[0].popup.visible,"Selector opens inside menu viewport")
		menu.show_page("sound");check(not choices[0].popup.visible,"Changing tabs closes selector")
	menu.show_page("together")
	var input: LineEdit=menu.multiplayer_page.find_children("*","LineEdit",true,false)[0]
	input.text="";input.grab_focus();menu.keyboard.open_for(input);menu.keyboard.send_character("S")
	await process_frame;await process_frame
	check(input.text=="S","Deferred virtual keyboard inserts into focused field")
	menu.keyboard.deliver(KEY_BACKSPACE,0);await process_frame;await process_frame
	check(input.text.is_empty(),"Virtual keyboard backspace works")
	menu.keyboard.hide()
	var audio=game.ambience
	for entry in game.Locations.CATALOG:
		audio.select_location(entry.id);audio._process(2.1)
		check(audio.voices[entry.id].player.playing and audio.voices[entry.id].player.stream.loop,"Location bed plays and loops: "+entry.id)
		check(audio.voices.values().filter(func(v):return v.player.playing).size()==1,"Old ambience stops after crossfade: "+entry.id)
	audio.select_location("lakeside");audio._process(.5)
	check(audio.voices.values().filter(func(v):return v.gain>0).size()==2,"Travel crossfades two locations")
	audio.set_muted(true);audio._process(.1)
	check(audio.voices.values().all(func(v):return v.player.volume_db<=-79),"Environment mute reaches all beds")
	audio.set_volume(.4);var cfg:=ConfigFile.new();cfg.load("user://sound.cfg")
	check(is_equal_approx(cfg.get_value("ambience","volume",0),.4),"Ambience preference persists")
	game.network.leave();game.queue_free();await process_frame;await create_timer(.3).timeout
	print("SHARK_AMBIENCE_MENU_RESULT ",failures);quit(0 if failures.is_empty() else 1)
