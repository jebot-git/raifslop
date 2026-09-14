extends SceneTree
const Opus=preload("res://tests/opus_fixture.gd")
var failures: Array=[]
var packets: Array=[0,0,0]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func wait_for(condition: Callable) -> bool:
	var deadline:=Time.get_ticks_msec()+15000
	while Time.get_ticks_msec()<deadline:
		if condition.call():return true
		await create_timer(.02).timeout
	return false
func run() -> void:
	var args:=OS.get_cmdline_user_args();var role: String=args[0]
	var address: String=args[args.find("--address")+1] if "--address" in args else "127.0.0.1"
	var g=load("res://scenes/main.tscn").instantiate();root.add_child(g)
	var net=g.network;net.voice.test_receive=true
	net.voice.packet_received.connect(func(_id,serial,_data):packets[clampi((serial-1)/100,0,2)]+=1)
	if role=="server":
		check(await wait_for(func():return net.players.size()==3),"Three radio clients joined dedicated server")
		await create_timer(10).timeout
		check(net.voice.relayed_packets>=270,"Dedicated server relays bounded proximity and radio packets")
	else:
		g.set_process(false);g.motor.set_physics_process(false)
		g.current_location="gray_pier" if role in ["far","host"] else "lakeside"
		net.display_name=role
		if role=="host":net.host(int(args[1]))
		else:net.join(address,int(args[1]))
		check(await wait_for(func():return net.active and net.players.size()==3 and net.states.size()==3),"Roster and locations replicated")
		if role=="sender":
			await create_timer(.5).timeout
			var encoder:=Opus.encoder()
			for serial in range(1,301):
				var radio: bool=serial>100 and serial<=200
				net.voice.submit.rpc_id(1,serial,Opus.packet(encoder,serial*960),radio)
				await create_timer(.02).timeout
			await create_timer(.6).timeout
			check(net.voice.received_packets==0,"Radio and nearby voice have no sender echo")
		else:
			await create_timer(9).timeout
			check(packets[1]>=85,"Radio reaches listeners across water boundaries")
			if role in ["far","host"]:
				check(packets[0]==0 and packets[2]==0,"Other waters never receive ordinary proximity speech")
			else:
				check(packets[0]>=85 and packets[2]>=85,"Nearby voice works before and after radio channel")
			check(net.voice.decoded_packets>70 and net.voice.decoded_peak>.01,"Real Opus radio packets decode audibly")
	print("RADIO_NETWORK_RESULT ",role," ",packets," ",failures)
	net.leave();g.queue_free();await process_frame;await create_timer(.3).timeout
	quit(0 if failures.is_empty() else 1)
