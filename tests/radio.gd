extends SceneTree
const Fixture=preload("res://tests/opus_fixture.gd")
var failures: Array=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func run() -> void:
	var g=load("res://scenes/main.tscn").instantiate();root.add_child(g)
	await create_timer(.3).timeout
	g.set_process(false);g.motor.set_physics_process(false)
	var net=g.network;net.set_process(false)
	var voice=net.voice;voice.set_process(false);voice.test_receive=true
	net.active=true;net.players={1:{"name":"Here"},2:{"name":"Nearby"},3:{"name":"Elsewhere"}}
	net.states={1:{"location":"lakeside"},2:{"location":"lakeside"},3:{"location":"gray_pier"}}
	check(voice.recipients(2,false)==[1],"Nearby voice stays within current water")
	check(voice.recipients(2,true)==[1,3],"Radio reaches every other angler across waters without echo")
	check(voice.recipients(99,true).is_empty(),"Unknown sender cannot use radio")
	var packet:=Fixture.packet(Fixture.encoder())
	voice.receive(3,10,packet,false)
	check(not voice.streams.has(3),"Receiver refuses ordinary speech from another water")
	voice.receive(3,11,packet,true)
	check(voice.streams.has(3) and voice.streams[3].radio and voice.streams[3].player is AudioStreamPlayer,"Radio is audible without distance attenuation")
	voice._process(.02)
	check(voice.streams.has(3),"Location filter keeps radio playback alive")
	voice.receive(2,20,packet,true);voice.receive(2,22,packet,false)
	var count: int=voice.received_packets
	voice.receive(2,21,packet,true)
	check(voice.received_packets==count and not voice.streams[2].radio,"Delayed packet cannot switch back to radio")
	voice.receive(2,23,packet,true);voice.receive(2,22,packet,false)
	check(voice.streams[2].radio,"Delayed proximity packet cannot interrupt newer radio")
	voice.set_muted(3,true);count=voice.received_packets;voice.receive(3,12,packet,true)
	check(voice.received_packets==count and not voice.streams.has(3),"Per-player mute stops radio")
	voice.set_muted(3,false);voice.muted_all=true;voice.receive(3,13,packet,true)
	check(voice.received_packets==count,"Mute all stops radio")
	voice.muted_all=false;net.voice_enabled=false;voice.receive(3,14,packet,true)
	check(voice.received_packets==count and voice.recipients(2,true).is_empty(),"Host voice disable covers radio")
	net.voice_enabled=true
	var tracker:=XRControllerTracker.new();tracker.name="radio_test_left";XRServer.add_tracker(tracker)
	var left:=XRController3D.new();left.tracker=tracker.name;left.pose="grip";g.origin.add_child(left);g.left=left
	g.xr=true;g.tracking_manager.focused=true;voice.mode=2;voice.hangover=.25
	var radio=g.shoulder_radio
	var yaw:=Basis(Vector3.UP,.8);g.head.rotation.y=.8
	var mount: Transform3D=radio.shoulder()
	check((mount.origin-g.head.global_position).dot(yaw.x)<-.22,"Radio follows left shoulder when turning")
	tracker.set_pose("grip",Transform3D(Basis.IDENTITY,g.origin.to_local(mount.origin)),Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	tracker.set_input("grip",0.0);await process_frame;radio.update()
	tracker.set_input("grip",1.0);tracker.set_input("trigger_click",true);await process_frame;radio.update()
	check(radio.held and voice.radio_channel() and voice.wants_transmit(),"Fresh shoulder grab and trigger activate cross-water radio in voice-activation mode")
	check(not g.rod_holster.stowed,"Using radio keeps rod available")
	preload("res://scripts/ui/pictograms.gd").enabled=false;radio.update()
	check(not radio.indicator.visible and voice.wants_transmit(),"Pictogram toggle hides radio symbol without interrupting transmission")
	preload("res://scripts/ui/pictograms.gd").enabled=true;radio.update()
	check(radio.indicator.visible,"Re-enabling pictograms restores radio symbol")
	for orientation in [Basis.IDENTITY, Basis.from_euler(Vector3(.4,.8,-.6))]:
		tracker.set_pose("grip",Transform3D(orientation,g.origin.to_local(mount.origin)),Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
		await process_frame;radio.update();radio.update()
		var expected: Basis=left.global_basis*Basis(Vector3.RIGHT,-PI/2)
		check(radio.model.global_basis.is_equal_approx(expected),"Held radio matches FPSloppa rotation without accumulating")
		check(radio.model.global_position.is_equal_approx(left.global_position),"Rotation preserves radio grip position")
	tracker.set_input("trigger_click",false);await process_frame;radio.update()
	check(radio.held and not voice.radio_channel() and not voice.wants_transmit(),"Trigger release silences held radio without leaking voice activation locally")
	voice.mode=1;tracker.set_input("trigger_click",true);await process_frame;radio.update()
	check(voice.wants_transmit(),"Radio overrides nearby push-to-talk binding")
	g.menu_open=true;radio.update()
	check(not radio.held and not voice.radio_active and not radio.model.visible,"Menu cancels radio transmission")
	g.menu_open=false;radio.update()
	check(not radio.held,"Held grip cannot reacquire radio after menu closes")
	tracker.set_input("grip",0.0);await process_frame;radio.update()
	tracker.set_input("grip",1.0);await process_frame;radio.update()
	g.tracking_manager.focused=false;radio.update()
	check(not radio.held and not voice.wants_transmit(),"Focus loss cancels radio")
	g.tracking_manager.focused=true;voice.mode=0;radio.update()
	check(not radio.held and not voice.wants_transmit(),"Listen-only mode cannot transmit through radio")
	voice.reset();check(voice.channel_serial.is_empty() and not voice.radio_active,"Disconnect clears channel history and PTT")
	g.xr=false;XRServer.remove_tracker(tracker);net.leave();g.queue_free()
	await process_frame;await create_timer(.3).timeout
	print("RADIO_RESULT ",failures);quit(0 if failures.is_empty() else 1)
