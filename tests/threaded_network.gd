extends SceneTree
const Transport=preload("res://scripts/network/threaded_peer.gd")
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func run():
	var host=Transport.new();var client=Transport.new()
	var port:=29000+OS.get_process_id()%1000
	host.set_bind_ip("127.0.0.1")
	check(host.create_server(port,2,7)==OK and client.create_client("127.0.0.1",port,7)==OK,"Threaded ENet peers start")
	var callbacks: Array=[]
	host.peer_connected.connect(func(_id):callbacks.append(Thread.is_main_thread()))
	var deadline:=Time.get_ticks_msec()+4000
	while client.get_connection_status()!=MultiplayerPeer.CONNECTION_CONNECTED and Time.get_ticks_msec()<deadline:
		host.poll();client.poll();await create_timer(.01).timeout
	host.poll()
	check(client.get_connection_status()==MultiplayerPeer.CONNECTION_CONNECTED and callbacks==[true],"Transport handshake callbacks dispatch on main thread")
	await create_timer(1.1).timeout
	check(host.diagnostics().peers.has(client.get_unique_id()) and client.diagnostics().peers.has(1),"Worker samples peer RTT and throttle without accessing ENet on the main thread")
	client.set_target_peer(1);client.transfer_channel=4;client.transfer_mode=MultiplayerPeer.TRANSFER_MODE_RELIABLE
	for i in 32:check(client.put_packet(var_to_bytes({"frame":i,"payload":"x".repeat(8192)}))==OK,"Reliable transfer queued "+str(i))
	# Deliberately stall scene dispatch. Both sockets must keep servicing ENet.
	var previous: int=host.diagnostics().polls
	OS.delay_msec(400)
	check(host.diagnostics().polls>previous+20 and host.diagnostics().received>=32,"Network worker polls and receives while main thread is blocked")
	host.poll();var frames: Array=[]
	while host.get_available_packet_count()>0:
		check(host.get_packet_channel()==4 and host.get_packet_peer()==client.get_unique_id(),"Packet routing metadata preserved")
		frames.append(bytes_to_var(host.get_packet()).frame)
	check(frames==range(32),"Reliable packet order and contents survive main-thread stall")
	var legacy:=ENetMultiplayerPeer.new()
	check(legacy.create_client("127.0.0.1",port,7)==OK,"Stock ENet client connects to threaded host")
	deadline=Time.get_ticks_msec()+4000
	while legacy.get_connection_status()!=MultiplayerPeer.CONNECTION_CONNECTED and Time.get_ticks_msec()<deadline:
		legacy.poll();host.poll();client.poll();await create_timer(.01).timeout
	legacy.set_target_peer(1);legacy.transfer_channel=6;legacy.transfer_mode=MultiplayerPeer.TRANSFER_MODE_UNRELIABLE
	legacy.put_packet(PackedByteArray([21,22,23]))
	var compatible:=false
	deadline=Time.get_ticks_msec()+2000
	while not compatible and Time.get_ticks_msec()<deadline:
		legacy.poll();host.poll();client.poll()
		while host.get_available_packet_count()>0:
			var source:=host.get_packet_peer();var received_channel:=host.get_packet_channel()
			var bytes:=host.get_packet()
			if source==legacy.get_unique_id() and received_channel==6 and bytes==PackedByteArray([21,22,23]):compatible=true
		await create_timer(.01).timeout
	check(compatible,"Stock ENet wire protocol and unreliable voice channel remain compatible")
	legacy.close()
	var ht: Thread=host.thread;var ct: Thread=client.thread
	client.close();host.close()
	check(not ht.is_started() and not ct.is_started(),"Disconnect joins both workers")
	check(client.get_connection_status()==MultiplayerPeer.CONNECTION_DISCONNECTED,"Closed transport reports disconnected")
	print("THREADED_NETWORK_RESULT ",failures);quit(0 if failures.is_empty() else 1)
