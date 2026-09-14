extends MultiplayerPeerExtension
## ENet has one owner thread. Following FPSloppa's disk-worker boundary, only
## packet bytes/events cross the queue; SceneMultiplayer and RPCs stay on main.
## This transport worker is fishing-specific; FPSloppa currently threads disk I/O.
const MAX_BYTES := 8_388_608
const MAX_PACKETS := 4096
class Worker extends RefCounted:
	var peer: ENetMultiplayerPeer
	var mutex := Mutex.new()
	var outgoing: Array = []
	var incoming: Array = []
	var events: Array = []
	var peers: Dictionary = {}
	var incoming_bytes := 0
	var outgoing_bytes := 0
	var stopping := false
	var status := MultiplayerPeer.CONNECTION_DISCONNECTED
	var failed := false
	var polls := 0
	var received := 0
	var sent := 0
	var peer_stats: Dictionary = {}
	var next_stats := 0
	func connected(id: int) -> void: peers[id]=true;events.append([true,id])
	func disconnected(id: int) -> void: peers.erase(id);events.append([false,id])
	func run() -> void:
		peer.peer_connected.connect(connected)
		peer.peer_disconnected.connect(disconnected)
		while true:
			mutex.lock()
			if stopping:mutex.unlock();break
			var work: Array=outgoing;outgoing=[];outgoing_bytes=0
			# Signals from peer.poll synchronously append events under this lock.
			for command in work:
				match command[0]:
					"send":
						if peer.get_connection_status()!=MultiplayerPeer.CONNECTION_CONNECTED:continue
						if command[1]>0 and not peers.has(command[1]):continue
						peer.set_target_peer(command[1]);peer.transfer_channel=command[2];peer.transfer_mode=command[3]
						var error:=peer.put_packet(command[4])
						if error==OK:sent+=1
						elif error==ERR_OUT_OF_MEMORY:failed=true
					"disconnect":peer.disconnect_peer(command[1],command[2])
					"refuse":peer.refuse_new_connections=command[1]
			if peer.get_connection_status()!=MultiplayerPeer.CONNECTION_DISCONNECTED:
				peer.poll();polls+=1
				while peer.get_available_packet_count()>0:
					var id:=peer.get_packet_peer();var channel:=peer.get_packet_channel();var mode:=peer.get_packet_mode()
					var bytes:=peer.get_packet()
					if incoming_bytes+bytes.size()>MAX_BYTES or incoming.size()>=MAX_PACKETS:
						# Never silently corrupt the reliable RPC stream on overflow.
						failed=true;break
					incoming.append([id,channel,mode,bytes]);incoming_bytes+=bytes.size();received+=1
			if Time.get_ticks_msec()>=next_stats:
				next_stats=Time.get_ticks_msec()+1000;peer_stats.clear()
				for id in peers:
					if peer.get_unique_id()!=1 and id!=1:continue
					var remote:=peer.get_peer(id)
					if remote and remote.is_active():
						peer_stats[id]={"rtt_ms":remote.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME),"throttle":remote.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE),"throttle_limit":remote.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE_LIMIT),"reliable_loss":remote.get_statistic(ENetPacketPeer.PEER_PACKET_LOSS)/ENetPacketPeer.PACKET_LOSS_SCALE}
			if failed:peer.close()
			status=peer.get_connection_status()
			mutex.unlock()
			OS.delay_usec(2000)
		peer.peer_connected.disconnect(connected);peer.peer_disconnected.disconnect(disconnected)
		peer.close()
var worker: Worker
var thread: Thread
var packets: Array=[]
var cursor := 0
var uid := 0
var server := false
var status := CONNECTION_DISCONNECTED
var target := 0
var channel := 0
var mode := TRANSFER_MODE_RELIABLE
var refusing := false
var bind_address := "*"
func set_bind_ip(address: String) -> void: bind_address=address
func create_server(port: int,max_clients: int=8,channels: int=7) -> Error:
	_close()
	var native:=ENetMultiplayerPeer.new();native.set_bind_ip(bind_address)
	var error:=native.create_server(port,max_clients,channels)
	return _start(native,true) if error==OK else error
func create_client(address: String,port: int,channels: int=7) -> Error:
	_close()
	var native:=ENetMultiplayerPeer.new()
	var error:=native.create_client(address,port,channels)
	return _start(native,false) if error==OK else error
func _start(native: ENetMultiplayerPeer,hosting: bool) -> Error:
	uid=native.get_unique_id();server=hosting;status=native.get_connection_status()
	worker=Worker.new();worker.peer=native;worker.status=status
	thread=Thread.new();var error:=thread.start(worker.run)
	if error!=OK:native.close();worker=null;thread=null;status=CONNECTION_DISCONNECTED
	return error
func _poll() -> void:
	if not worker:return
	worker.mutex.lock()
	var events: Array=worker.events;worker.events=[]
	var fresh: Array=worker.incoming;worker.incoming=[];worker.incoming_bytes=0
	status=worker.status
	worker.mutex.unlock()
	if cursor>0:packets=packets.slice(cursor);cursor=0
	packets.append_array(fresh)
	for event in events:
		if not worker:break
		if event[0]:peer_connected.emit(event[1])
		else:peer_disconnected.emit(event[1])
func _close() -> void:
	if worker:
		worker.mutex.lock();worker.stopping=true;worker.mutex.unlock()
		if thread and thread.is_started():thread.wait_to_finish()
	worker=null;thread=null;packets.clear();cursor=0;status=CONNECTION_DISCONNECTED;uid=0
func _notification(what: int) -> void:
	if what==NOTIFICATION_PREDELETE and worker:
		# Do not call methods on self after RefCounted has reached zero refs.
		worker.mutex.lock();worker.stopping=true;worker.mutex.unlock()
		if thread and thread.is_started():thread.wait_to_finish()
func _put_packet_script(buffer: PackedByteArray) -> Error:
	if not worker or status!=CONNECTION_CONNECTED:return ERR_UNCONFIGURED
	worker.mutex.lock()
	if worker.outgoing_bytes+buffer.size()>MAX_BYTES or worker.outgoing.size()>=MAX_PACKETS:
		worker.mutex.unlock();return ERR_OUT_OF_MEMORY
	worker.outgoing.append(["send",target,channel,mode,buffer.duplicate()]);worker.outgoing_bytes+=buffer.size()
	worker.mutex.unlock();return OK
func _get_packet_script() -> PackedByteArray:
	if cursor>=packets.size():return PackedByteArray()
	var bytes: PackedByteArray=packets[cursor][3];cursor+=1;return bytes
func _get_available_packet_count() -> int:return packets.size()-cursor
func _get_packet_peer() -> int:return packets[cursor][0] if cursor<packets.size() else 0
func _get_packet_channel() -> int:return packets[cursor][1] if cursor<packets.size() else 0
func _get_packet_mode() -> MultiplayerPeer.TransferMode:return packets[cursor][2] if cursor<packets.size() else TRANSFER_MODE_RELIABLE
func _get_max_packet_size() -> int:return 1_048_576
func _get_connection_status() -> MultiplayerPeer.ConnectionStatus:return status
func _get_unique_id() -> int:return uid
func _is_server() -> bool:return server
func _is_server_relay_supported() -> bool:return true
func _set_target_peer(value: int) -> void:target=value
func _set_transfer_channel(value: int) -> void:channel=value
func _get_transfer_channel() -> int:return channel
func _set_transfer_mode(value: MultiplayerPeer.TransferMode) -> void:mode=value
func _get_transfer_mode() -> MultiplayerPeer.TransferMode:return mode
func _disconnect_peer(id: int,force: bool) -> void:
	if worker:
		worker.mutex.lock();worker.outgoing.append(["disconnect",id,force]);worker.mutex.unlock()
func _set_refuse_new_connections(value: bool) -> void:
	refusing=value
	if worker:
		worker.mutex.lock();worker.outgoing.append(["refuse",value]);worker.mutex.unlock()
func _is_refusing_new_connections() -> bool:return refusing
func diagnostics() -> Dictionary:
	if not worker:return {"running":false}
	worker.mutex.lock()
	var result:={"running":thread.is_started(),"polls":worker.polls,"received":worker.received,"sent":worker.sent,"queued_bytes":worker.incoming_bytes,"failed":worker.failed,"peers":worker.peer_stats.duplicate(true)}
	worker.mutex.unlock();return result
