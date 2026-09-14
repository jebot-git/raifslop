extends SceneTree
const Fixture=preload("res://tests/opus_fixture.gd")
var failures: Array=[]
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game.set_process(false);game.motor.set_physics_process(false)
	var net=game.network;net.set_process(false)
	var voice=net.voice
	net.active=true;net.players={1:{"name":"Listener"},2:{"name":"Speaker"}}
	net.states={1:{"location":"lakeside"},2:{"location":"lakeside"}}
	game.xr=true;game.tracking_manager.focused=true;game.tracking_was_valid=false
	game.menu_open=true
	check(voice.can_transmit(),"Voice works in menu after fishing tracking is invalidated")
	game.menu_open=false;game.fish_guide.held=true
	check(voice.can_transmit(),"Voice works while holding Guide after controller loss")
	game.fish_guide.held=false;game.rod_holster.stowed=true
	check(voice.can_transmit(),"Voice works with rod stashed after controller loss")
	game.tracking_manager.focused=false
	check(not voice.can_transmit(),"Unfocused XR session still mutes transmission")
	game.tracking_manager.focused=true
	check(voice.can_transmit(),"Voice resumes immediately when XR focus returns")
	net.active=false;check(not voice.can_transmit(),"Offline session cannot transmit")
	net.active=true;net.voice_enabled=false;check(not voice.can_transmit(),"Host voice disable is respected")
	net.voice_enabled=true;game.xr=false;voice.test_receive=true;voice.set_mode(0)
	var enc=Fixture.encoder();var serial:=0
	for pause in [.25,2.5]:
		var before: int=voice.decoded_packets
		for frame in range(12):
			serial+=1;net.clock+=.02
			voice.receive(2,serial,Fixture.packet(enc,frame*960))
			await create_timer(.02).timeout
		check(voice.decoded_packets>=before+10,"Voice decodes after pause cycle "+str(pause))
		net.clock+=pause;voice._process(.01)
		if pause>2:check(not voice.streams.has(2),"Idle voice stream is released")
		else:check(not voice.streams[2].speaker.inopusstream,"Short silence drains playback")
	var before: int=voice.decoded_packets
	for frame in range(12):
		serial+=1;net.clock+=.02;voice.receive(2,serial,Fixture.packet(enc,frame*960))
		await create_timer(.02).timeout
	check(voice.decoded_packets>=before+10,"Voice rebuilds playback after idle stream removal")
	voice.set_muted(2,true);before=voice.received_packets;serial+=1
	voice.receive(2,serial,Fixture.packet(enc))
	check(voice.received_packets==before,"Recovery respects per-player mute")
	voice.set_muted(2,false);serial+=1;voice.receive(2,serial,Fixture.packet(enc))
	check(voice.received_packets==before+1,"Unmuting recreates stream on next packet")
	net.leave();game.queue_free();await process_frame;await create_timer(.3).timeout
	print("VOICE_RECOVERY_RESULT ",failures);quit(0 if failures.is_empty() else 1)
