extends SceneTree
const Transport = preload("res://scripts/network/threaded_peer.gd")
const Codec = preload("res://scripts/network/pose_codec.gd")
const Fixture = preload("res://tests/network_fixture.gd")
var failures: Array = []
func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label); push_error(label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var host := Transport.new(); var client := Transport.new()
	host.framed=true; client.framed=true; host.set_bind_ip("127.0.0.1")
	var port := 27000+OS.get_process_id()%1000
	check(host.create_server(port,2,7)==OK and client.create_client("127.0.0.1",port,7)==OK, "Framed peers start")
	var deadline := Time.get_ticks_msec()+5000
	while client.get_connection_status()!=MultiplayerPeer.CONNECTION_CONNECTED and Time.get_ticks_msec()<deadline:
		host.poll();client.poll();await create_timer(.01).timeout
	check(client.get_connection_status()==MultiplayerPeer.CONNECTION_CONNECTED,"Connect")
	var original := PackedByteArray(); original.resize(200000)
	for i in original.size(): original[i]=(i*37)%256
	client.set_target_peer(1);client.transfer_channel=4;client.transfer_mode=MultiplayerPeer.TRANSFER_MODE_RELIABLE
	for i in 4: check(client.put_packet(original)==OK,"Bulk queued")
	var pose := Codec.encode(Fixture.player(10,true))
	client.transfer_channel=1;client.transfer_mode=MultiplayerPeer.TRANSFER_MODE_UNRELIABLE
	check(client.put_packet(original)==ERR_INVALID_PARAMETER,"Oversize unreliable send fails explicitly")
	check(client.put_packet(pose)==OK,"Full pose queued unreliably")
	var bulk := 0;var poses := 0
	var start := Time.get_ticks_msec();var pose_delay := -1;var first_bulk_delay := -1
	deadline=Time.get_ticks_msec()+5000
	while (bulk<4 or poses<1) and Time.get_ticks_msec()<deadline:
		host.poll();client.poll()
		while host.get_available_packet_count()>0:
			var channel:=host.get_packet_channel();var mode:=host.get_packet_mode();var sender:=host.get_packet_peer();var bytes:=host.get_packet()
			check(sender==client.get_unique_id(),"Sender retained")
			if channel==4:
				check(bytes==original and mode==MultiplayerPeer.TRANSFER_MODE_RELIABLE,"Bulk round trip exact");bulk+=1
				if first_bulk_delay<0:first_bulk_delay=Time.get_ticks_msec()-start
			elif channel==1:
				check(bytes==pose and mode==MultiplayerPeer.TRANSFER_MODE_UNRELIABLE,"Pose remains unreliable");poses+=1
				pose_delay=Time.get_ticks_msec()-start
		await create_timer(.01).timeout
	check(bulk==4 and poses==1,"All payloads delivered")
	check(pose_delay>=0 and pose_delay<first_bulk_delay and pose_delay<250,"Pose is not trapped behind paced bulk")
	check(Time.get_ticks_msec()-start>=2700,"Bulk uses the configured aggregate pacing")
	var stats:=client.diagnostics()
	check(stats.wire_max_bytes<=994 and stats.wire_sent>800 and stats.oversize_rejected==1,"Wire budget and diagnostics")
	check(host.diagnostics().reassembly_bytes==0,"Reassembly memory released")
	# A malformed sender must not close the host or its healthy connection.
	var rogue := ENetMultiplayerPeer.new()
	check(rogue.create_client("127.0.0.1",port,7)==OK,"Malformed-peer fixture connects")
	deadline=Time.get_ticks_msec()+3000
	while rogue.get_connection_status()!=MultiplayerPeer.CONNECTION_CONNECTED and Time.get_ticks_msec()<deadline:
		rogue.poll();host.poll();client.poll();await create_timer(.01).timeout
	rogue.set_target_peer(1);rogue.transfer_channel=0;rogue.transfer_mode=MultiplayerPeer.TRANSFER_MODE_RELIABLE
	rogue.put_packet(PackedByteArray([1,2,3]))
	deadline=Time.get_ticks_msec()+3000
	while host.diagnostics().malformed_frames==0 and Time.get_ticks_msec()<deadline:
		rogue.poll();host.poll();client.poll();await create_timer(.01).timeout
	check(host.diagnostics().malformed_frames==1 and not host.diagnostics().failed,"Malformed sender isolated")
	client.transfer_channel=0;client.transfer_mode=MultiplayerPeer.TRANSFER_MODE_RELIABLE
	check(client.put_packet(PackedByteArray([42]))==OK,"Healthy peer continues sending")
	deadline=Time.get_ticks_msec()+3000
	while host.get_available_packet_count()==0 and Time.get_ticks_msec()<deadline:
		host.poll();client.poll();await create_timer(.01).timeout
	check(host.get_available_packet_count()==1 and host.get_packet()==PackedByteArray([42]),"Healthy peer survives bad sender")
	rogue.close()
	print("FRAMED_NETWORK_RESULT bulk=",bulk," poses=",poses," pose_delay_ms=",pose_delay," first_bulk_ms=",first_bulk_delay," wire_max=",stats.wire_max_bytes," failures=",failures)
	client.close();host.close();quit(0 if failures.is_empty() else 1)
