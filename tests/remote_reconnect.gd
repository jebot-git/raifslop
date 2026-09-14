extends SceneTree
const Opus=preload("res://tests/opus_fixture.gd")
var failures: Array=[]
var packets:=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func wait_for(condition: Callable,seconds: float=15) -> bool:
	var deadline:=Time.get_ticks_msec()+seconds*1000
	while Time.get_ticks_msec()<deadline:
		if condition.call():return true
		await create_timer(.02).timeout
	return false
func run() -> void:
	var args:=OS.get_cmdline_user_args();var role: String=args[0]
	var g=load("res://scenes/main.tscn").instantiate();root.add_child(g)
	g.set_process(false);g.motor.set_physics_process(false)
	var net=g.network;net.voice.test_receive=true
	net.display_name="reconnect-"+role
	g.current_location="lakeside" if role=="sender" else "gray_pier"
	net.voice.packet_received.connect(func(_id,_serial,_data):packets+=1)
	var encoder:=Opus.encoder()
	for cycle in 2:
		packets=0;net.voice.decoded_peak=0
		var decoded_before: int=net.voice.decoded_packets
		net.join(args[1],int(args[2]))
		check(await wait_for(func():return net.active and net.players.size()==2 and net.states.size()==2),"Reconnect handshake/poses cycle "+str(cycle))
		if role=="sender":
			await create_timer(.7).timeout
			for burst in 2:
				for i in 100:
					var serial:=burst*100+i+1
					net.voice.submit.rpc_id(1,serial,Opus.packet(encoder,serial*960),true)
					await create_timer(.02).timeout
				if burst==0:await create_timer(3).timeout
			check(net.voice.received_packets==0,"No radio echo after reconnect")
			await create_timer(1).timeout
		else:
			check(await wait_for(func():return packets>=20),"Radio starts after reconnect")
			var transport=net.multiplayer.multiplayer_peer
			var polls: int=transport.diagnostics().polls
			OS.delay_msec(400)
			check(transport.diagnostics().polls>polls+30,"Socket polling continues through 400 ms client stall")
			check(await wait_for(func():return packets>=90),"Voice survives main-thread stall")
			check(await wait_for(func():return net.voice.streams.is_empty(),5),"Long silence drains and removes radio stream")
			var before: int=packets
			check(await wait_for(func():return packets>=before+85,6),"Radio automatically resumes after long silence")
			check(net.voice.decoded_packets>decoded_before+160 and net.voice.decoded_peak>.01,"Recovered radio decodes real audio")
			print("REMOTE_RECONNECT_METRICS ",JSON.stringify({"cycle":cycle,"received":packets,"decoded":net.voice.decoded_packets-decoded_before,"peak":net.voice.decoded_peak,"transport":transport.diagnostics()}))
			await create_timer(1).timeout
		net.leave()
		check(net.voice.streams.is_empty() and net.voice.channel_serial.is_empty(),"Disconnect clears stale audio and channel history")
		await create_timer(2).timeout
	print("REMOTE_RECONNECT_RESULT ",role," ",failures)
	g.queue_free();await process_frame;await create_timer(.3).timeout
	quit(0 if failures.is_empty() else 1)
