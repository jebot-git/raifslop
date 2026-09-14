extends SceneTree
var failures: Array = []
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func run():
	var g=load("res://scenes/main.tscn").instantiate();root.add_child(g)
	await create_timer(.5).timeout
	g.set_process(false);g.motor.set_physics_process(false)
	var args:=OS.get_cmdline_user_args()
	if "--write" in args:
		g.motor.smooth_turn=true;g.game.bait=4
		g.ambience.volume=.3;g.ambience.muted=true
		g.tracking_manager.seated=true;g.tracking_manager.expressions_enabled=false
		g.tracking_manager.tracked_leg_animation=true;g.tracking_manager.tracking.enabled=false
		g.shadow_policy.set_mode("dynamic",false)
		g.network.display_name="Persistence Tester";g.network.host_address="192.0.2.17";g.network.preferred_port=25432
		g.network.voice.mode=1;g.network.voice.muted_all=true;g.network.voice.threshold=.035;g.network.voice.input_device="Default"
		g.avatars.selected_path=g.avatars.DEFAULTS[1]
		g._select_location("lake_pier",false)
		g.game.tackle.shekels=432;g.game.tackle.owned.assign([0,1]);g.game.tackle.equipped=1
		if "--window-close" in args:g.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
		elif "--escape" in args:
			var key:=InputEventKey.new();key.keycode=KEY_ESCAPE;key.pressed=true;g._unhandled_input(key)
		else:g.avatar_menu.quit_button.pressed.emit()
		await create_timer(2).timeout
		push_error("Exit path failed to quit");quit(1);return
	check(g.motor.smooth_turn and g.avatar_menu.turn_mode.button_pressed,"Turn mode restores in motor and menu")
	check(g.game.bait==4,"Selected bait restores")
	check(is_equal_approx(g.ambience.volume,.3) and g.ambience.muted,"Ambience volume and mute restore")
	var m=g.tracking_manager
	check(m.seated and not m.expressions_enabled and m.tracked_leg_animation and not m.tracking.enabled,"All four body tracking preferences restore")
	check(g.shadow_policy.mode=="dynamic","Shadow mode restores")
	check(g.network.display_name=="Persistence Tester" and g.network.host_address=="192.0.2.17" and g.network.preferred_port==25432,"Multiplayer name, address and port restore without reconnecting")
	check(not g.network.active,"Saved connection does not automatically connect")
	check(g.network.voice.mode==1 and g.network.voice.muted_all and is_equal_approx(g.network.voice.threshold,.035) and g.network.voice.input_device=="Default","Voice mode, mute, threshold and input restore")
	check(g.avatars.selected_path==g.avatars.DEFAULTS[1],"Avatar selection restores")
	check(g.current_location=="lake_pier","Location restores")
	check(g.game.tackle.shekels==432 and g.game.tackle.equipped==1 and 1 in g.game.tackle.owned,"Balance, owned and equipped rods restore")
	g.avatar_menu.turn_mode.toggled.emit(false)
	g._select_bait(2)
	var cfg:=ConfigFile.new();cfg.load("user://player.cfg")
	check(not cfg.get_value("controls","smooth_turn",true) and cfg.get_value("tackle","bait",-1)==2,"Turn and bait choices also save immediately")
	g.queue_free();await process_frame;await create_timer(.3).timeout
	print("SETTINGS_RESULT ",failures);quit(0 if failures.is_empty() else 1)
