## Adapted from jebot-git/FPSloppa, commit 5105fb8cfa38c76aa1d5d172af3047fe2d12ae0d.
extends Node
## Server-mediated avatar sharing. Only announced SHA-256 assets can be requested.
const Library = preload("res://scripts/network/avatar_library.gd")
const CHUNK := 32_768
const WINDOW := CHUNK*8
const IO=preload("res://scripts/network/disk_worker.gd")
const Jobs=preload("res://scripts/network/asset_jobs.gd")
var disk=IO.new()
var generation:=0
var checking: Dictionary={}
var library
var game
var choices: Dictionary = {}
var pending: Dictionary = {}
var incoming: Dictionary = {}
var outgoing: Dictionary = {}
var expected: Dictionary = {}
var offered := ""
var next_offer := 0.0
var message := ""
var offer_times: Dictionary = {}
var load_queue: Array = []
var avatar_attempts: Dictionary={}
var transfer_budget := 0.0
const REQUEST_TIMEOUT := 10_000
const QUEUE_TIMEOUT := 90_000
const MAX_RETRIES := 3
var offer_attempts := 0
var offer_accepted := false
var request_serial := 0

func send_avatar(peer: int, method: String, args: Array) -> void:
	callv("rpc_id",[peer,method]+args)

func trace(event: String, hash: String, peer: int, extra: Dictionary = {}) -> void:
	var row := {"event":event,"sha256":hash,"peer":peer,"ticks_usec":Time.get_ticks_usec()}
	row.merge(extra)
	print("AVATAR_TRANSFER ",JSON.stringify(row))

func expect_model(hash: String, peer: int, size: int) -> void:
	request_serial+=1
	var now:=Time.get_ticks_msec()
	expected[hash]={"peer":peer,"size":size,"time":now,"started":now,"attempt":0,"transfer_id":request_serial}
	game.loading.begin_item("model:"+hash,size,"Player model")
	trace("request",hash,peer,{"transfer_id":request_serial,"size":size})
	send_avatar(peer,"_request",[hash])

func retry_request(hash: String, reason: String) -> void:
	if not expected.has(hash):return
	var request:Dictionary=expected[hash]
	if request.attempt>=MAX_RETRIES or Time.get_ticks_msec()-request.started>=QUEUE_TIMEOUT:
		trace("failed",hash,request.peer,{"phase":"request","reason":reason,"transfer_id":request.transfer_id,"elapsed_ms":Time.get_ticks_msec()-request.started})
		expected.erase(hash)
		for id in pending.keys():
			if pending[id].hash==hash:pending.erase(id)
		game.loading.fail("model:"+hash,reason)
		return
	request.attempt+=1
	request.retry_at=Time.get_ticks_msec()+1000*(1<<request.attempt)
	request.time=Time.get_ticks_msec()
	trace("retry",hash,request.peer,{"attempt":request.attempt,"reason":reason,"transfer_id":request.transfer_id})

func cancel_obsolete() -> void:
	var needed:Dictionary={}
	for row in choices.values():needed[row.hash]=true
	for row in pending.values():needed[row.hash]=true
	for item in game.loading.errors.keys():
		if item.begins_with("model:") and not needed.has(item.trim_prefix("model:")):game.loading.cancel(item)
	for hash in expected.keys():
		if not needed.has(hash):
			send_avatar(expected[hash].peer,"_cancel",[hash]);expected.erase(hash);game.loading.cancel("model:"+hash)
	for hash in incoming.keys():
		if not needed.has(hash):
			send_avatar(incoming[hash].peer,"_cancel",[hash]);drop_incoming(hash);game.loading.cancel("model:"+hash)

@rpc("authority","call_remote","reliable",4)
func _offer_result(hash: String, accepted: bool) -> void:
	if hash!=offered:return
	offer_accepted=accepted
	next_offer=game.clock+(35.0 if accepted else 3.2)
	trace("offer_accepted" if accepted else "offer_retry",hash,1)

@rpc("any_peer","call_remote","reliable",4)
func _cancel(hash: String) -> void:
	var peer:=multiplayer.get_remote_sender_id()
	if outgoing.has(peer) and outgoing[peer].hash==hash:outgoing.erase(peer)

func alternate_source(hash: String, previous: int) -> int:
	for id in pending:
		if id!=previous and game.players.has(id) and pending[id].hash==hash:return id
	return 0

@rpc("any_peer","call_remote","reliable",4)
func _unavailable(hash: String) -> void:
	var peer:=multiplayer.get_remote_sender_id()
	if expected.has(hash) and expected[hash].peer==peer:
		var alternate:=alternate_source(hash,peer)
		if alternate>0:expected[hash].peer=alternate
		retry_request(hash,"Player model is no longer available.")

func setup(arena: Node) -> void:
	game = arena
	add_child(disk)
	name = "AvatarNetwork"
	library = Library.new()
	library.name = "Library"
	add_child(library)

func reset() -> void:
	generation+=1;checking.clear()
	for key in incoming.keys(): drop_incoming(key)
	incoming.clear()
	outgoing.clear()
	expected.clear()
	pending.clear()
	choices.clear()
	offer_times.clear()
	offered = ""
	next_offer = 0
	offer_attempts=0;offer_accepted=false
	load_queue.clear();avatar_attempts.clear()

func remove_peer(id: int) -> void:
	choices.erase(id);avatar_attempts.erase(id)
	pending.erase(id)
	offer_times.erase(id)
	outgoing.erase(id)
	for hash in incoming.keys():
		if incoming[hash].peer==id:
			var size:int=incoming[hash].size
			drop_incoming(hash)
			var alternate:=alternate_source(hash,id)
			if alternate>0:expect_model(hash,alternate,size)
			else:game.loading.cancel("model:"+hash)
	for hash in expected.keys():
		if expected[hash].peer==id:
			var alternate:=alternate_source(hash,id)
			if alternate>0:
				expected[hash].peer=alternate;retry_request(hash,"Previous model sender disconnected.")
			else:
				expected.erase(hash);game.loading.cancel("model:"+hash)

func _process(delta: float) -> void:
	if not game: return
	if game.active:
		var mine := multiplayer.get_unique_id()
		if offered!=library.selected:
			offered=library.selected;offer_attempts=0;offer_accepted=false;next_offer=0
			if not multiplayer.is_server() and outgoing.has(1):outgoing.erase(1)
		var published:bool=choices.get(mine,{}).get("hash","")==offered
		if game.players.has(mine) and not published and offer_attempts<4 and game.clock>=next_offer and library.entries.has(offered):
			offer_attempts+=1
			next_offer=game.clock+3.2*pow(2,offer_attempts-1)
			if multiplayer.is_server(): accept_offer(mine,offered,library.entries[offered].size)
			else: send_avatar(1,"_offer",[offered,library.entries[offered].size])
	# Limit aggregate upload to 2 MiB/s and eight unacknowledged chunks per peer.
	transfer_budget = minf(transfer_budget+delta*2_097_152,WINDOW)
	for peer in outgoing.keys():
		if not multiplayer.get_peers().has(peer): outgoing.erase(peer); continue
		var transfer: Dictionary = outgoing[peer]
		if Time.get_ticks_msec()-transfer.time>30000: outgoing.erase(peer); continue
		if not transfer.get("reading",false) and transfer.sent-transfer.ack<WINDOW and transfer.sent<transfer.size and transfer_budget>=CHUNK:
			var count:=mini(mini(WINDOW-(transfer.sent-transfer.ack),transfer.size-transfer.sent),int(transfer_budget/CHUNK)*CHUNK)
			transfer.reading=true;transfer_budget-=count
			if not disk.submit(IO.read.bind(transfer.path,transfer.sent,count,transfer.size),func(data):
				if not is_same(outgoing.get(peer),transfer):return
				transfer.reading=false
				if data.size()!=count:outgoing.erase(peer);return
				for offset in range(0,data.size(),CHUNK):
					var part: PackedByteArray=data.slice(offset,offset+CHUNK)
					send_avatar(peer,"_chunk",[transfer.hash,transfer.sent,part]);transfer.sent+=part.size()):
				transfer.reading=false;transfer_budget+=count

	for hash in incoming.keys():
		if not incoming.has(hash):continue
		if Time.get_ticks_msec()-incoming[hash].time>30000:
			var stalled:Dictionary=incoming[hash]
			trace("stalled",hash,stalled.peer,{"phase":"download","bytes":stalled.written,"transfer_id":stalled.transfer_id})
			send_avatar(stalled.peer,"_cancel",[hash])
			disk.discard(stalled.path);incoming.erase(hash)
			expected[hash]={"peer":stalled.peer,"size":stalled.size,"time":Time.get_ticks_msec(),"started":stalled.started,"attempt":stalled.attempt,"transfer_id":stalled.transfer_id}
			retry_request(hash,"Required model download timed out.")
	for hash in expected.keys():
		var request:Dictionary=expected[hash]
		var now:=Time.get_ticks_msec()
		if now-request.started>=QUEUE_TIMEOUT:
			retry_request(hash,"Player model queue timed out.");continue
		if request.get("retry_at",0)>0:
			if now>=request.retry_at and game.active:
				request.erase("retry_at");request.time=now
				send_avatar(request.peer,"_request",[hash])
		elif now-request.time>REQUEST_TIMEOUT:retry_request(hash,"Required model request timed out.")
	if not game.headless:
		for player_id in choices:queue_avatar(player_id)
	if not load_queue.is_empty() and not game.headless:
		var id: int = load_queue.pop_front()
		if game.fighters.has(id) and choices.has(id):
			var hash: String = choices[id].hash
			if library.entries.has(hash):
				avatar_attempts[id]=hash+":"+str(game.fighters[id].get_instance_id())
				var avatar: Node3D = library.create_avatar(hash)
				if avatar:
					game.fighters[id].set_avatar(avatar,hash)
				else:
					message="Player avatar unavailable: "+library.last_error
					game.loading.fail("model:"+hash,message)
					printerr("REMOTE_AVATAR_LOAD_FAILED ",JSON.stringify({"peer":id,"sha256":hash,"error":library.last_error}))

@rpc("any_peer","call_remote","reliable",4)
func _offer(hash: String, size: int) -> void:
	if not multiplayer.is_server(): return
	accept_offer(multiplayer.get_remote_sender_id(),hash,size)

func accept_offer(id: int, hash: String, size: int) -> void:
	if not game.players.has(id) or not Library.valid_hash(hash) or size<=0 or size>Library.MAX_BYTES: return
	var now := Time.get_ticks_msec()
	if now-int(offer_times.get(id,-10000))<3000:
		if id!=multiplayer.get_unique_id():send_avatar(id,"_offer_result",[hash,false])
		return
	offer_times[id] = now
	if library.entries.has(hash) and library.entries[hash].size!=size:
		if id!=multiplayer.get_unique_id():send_avatar(id,"_offer_result",[hash,false])
		return
	# Replace the desired selection before cancelling old work: old completion
	# can never publish over the newest accepted choice, including shared hashes.
	pending[id]={"hash":hash,"size":size}
	cancel_obsolete()
	if id!=multiplayer.get_unique_id():send_avatar(id,"_offer_result",[hash,true])
	if library.entries.has(hash):
		if library.entries[hash].size!=size: return
		choices[id] = {"hash":hash,"size":size}
		pending.erase(id)
		publish()
	else:
		if not expected.has(hash) and not incoming.has(hash):expect_model(hash,id,size)

func publish() -> void:
	_catalog(choices)
	for peer in multiplayer.get_peers():
		if game.players.has(peer): send_avatar(peer,"_catalog",[choices])

func sync_peer(id: int) -> void:
	if multiplayer.is_server() and multiplayer.get_peers().has(id): send_avatar(id,"_catalog",[choices])

@rpc("authority","call_remote","reliable",4)
func _catalog(data: Dictionary) -> void:
	if data.size()>game.SERVER_MAX_PLAYERS: return
	choices = data.duplicate(true)
	cancel_obsolete()
	library.pinned = choices.values().map(func(row): return row.hash)
	for id in choices:
		var hash: String = choices[id].hash
		var size: int = choices[id].size
		if not Library.valid_hash(hash) or size<=0 or size>Library.MAX_BYTES: continue
		if library.entries.has(hash):queue_avatar(id)
		elif not multiplayer.is_server() and not expected.has(hash) and not incoming.has(hash) and not checking.has(hash):
			# Cache hashing/metadata inspection can be large; never do it in an RPC.
			checking[hash]=true
			game.loading.begin_item("model:"+hash,size,"Player model")
			var epoch:=generation
			if not disk.submit(Jobs.model_file.bind(Library.CACHE+hash+".vrm",hash,Library.CACHE,false),func(info):
				if epoch!=generation:return
				checking.erase(hash)
				if not choices.values().any(func(row):return row.hash==hash):
					game.loading.cancel("model:"+hash);return
				if not info.has("error") and info.size==size:
					library.entries[hash]=info;game.loading.complete("model:"+hash)
					for player_id in choices:queue_avatar(player_id)
				else:
					expect_model(hash,1,size)):
				checking.erase(hash);game.loading.fail("model:"+hash,"Model disk queue is full.")

func queue_avatar(id: int) -> void:
	if not game.fighters.has(id) or not choices.has(id):return
	var hash: String=choices[id].hash
	var attempt: String=hash+":"+str(game.fighters[id].get_instance_id())
	if library.entries.has(hash) and game.fighters[id].avatar_hash!=hash and avatar_attempts.get(id,"")!=attempt and not load_queue.has(id):
		load_queue.append(id)

@rpc("any_peer","call_remote","reliable",4)
func _request(hash: String) -> void:
	var peer := multiplayer.get_remote_sender_id()
	if not Library.valid_hash(hash):return
	# Dedicated authority is not an angler in the roster.
	if multiplayer.is_server():
		if not game.players.has(peer):return
	elif peer!=1:return
	if not library.entries.has(hash):
		send_avatar(peer,"_unavailable",[hash]);return
	if multiplayer.is_server():
		if not game.players.has(peer): return
		var allowed := false
		for row in choices.values():
			if row.hash==hash: allowed = true
		if not allowed:
			send_avatar(peer,"_unavailable",[hash]);return
	else:
		if peer!=1:return
		if hash!=offered:
			send_avatar(peer,"_unavailable",[hash]);return
	if outgoing.has(peer):
		# One upload per destination. Receiver retries after current asset completes.
		send_avatar(peer,"_busy",[hash])
		return
	var entry: Dictionary = library.entries[hash]
	if entry.size<=0 or entry.size>Library.MAX_BYTES:return
	outgoing[peer] = {"hash":hash,"size":entry.size,"path":entry.path,"sent":0,"ack":0,"time":Time.get_ticks_msec()}
	send_avatar(peer,"_begin",[hash,entry.size])

@rpc("any_peer","call_remote","reliable",4)
func _busy(hash: String) -> void:
	if not expected.has(hash) or expected[hash].peer!=multiplayer.get_remote_sender_id(): return
	expected[hash].retry_at = Time.get_ticks_msec()+1000

@rpc("any_peer","call_remote","reliable",4)
func _begin(hash: String, size: int) -> void:
	var peer := multiplayer.get_remote_sender_id()
	if not expected.has(hash) or expected[hash].peer!=peer or expected[hash].size!=size or size>Library.MAX_BYTES or size<=0: return
	if incoming.has(hash): return
	var path: String = Library.CACHE+hash+".%d.%d.part"%[get_instance_id(),Time.get_ticks_usec()]
	disk.track(path)
	incoming[hash] = {"peer":peer,"size":size,"offset":0,"written":0,"path":path,"time":Time.get_ticks_msec(),"started":expected[hash].started,"transfer_id":expected[hash].transfer_id,"attempt":expected[hash].attempt}
	trace("download_begin",hash,peer,{"transfer_id":expected[hash].transfer_id,"size":size})
	expected.erase(hash)

@rpc("any_peer","call_remote","reliable",4)
func _chunk(hash: String, offset: int, bytes: PackedByteArray) -> void:
	if not incoming.has(hash): return
	var transfer: Dictionary = incoming[hash]
	if transfer.peer!=multiplayer.get_remote_sender_id(): return
	if offset!=transfer.offset or bytes.is_empty() or bytes.size()>CHUNK or offset+bytes.size()>transfer.size:
		drop_incoming(hash)
		if game:game.loading.fail("model:"+hash,"Invalid model download chunk.")
		return
	var end:=offset+bytes.size()
	if end-transfer.written>WINDOW:
		drop_incoming(hash);game.loading.fail("model:"+hash,"Model transfer exceeded window.");return
	transfer.offset=end;transfer.time=Time.get_ticks_msec()
	if not disk.submit(IO.write.bind(transfer.path,offset,bytes),func(error):
		if not is_same(incoming.get(hash),transfer):return
		if error!=OK:
			drop_incoming(hash);game.loading.fail("model:"+hash,"Cannot write required model.");return
		transfer.written=end;transfer.time=Time.get_ticks_msec()
		if not multiplayer.is_server():game.loading.advance("model:"+hash,end)
		message="Downloading avatar · %d%%"%int(100.0*end/transfer.size)
		send_avatar(transfer.peer,"_ack",[hash,end])
		if end==transfer.size:finish_model(hash,transfer)):
		drop_incoming(hash);game.loading.fail("model:"+hash,"Model disk queue is full.")

func finish_model(hash: String,transfer: Dictionary) -> void:
	if not disk.submit(Jobs.model_file.bind(transfer.path,hash,Library.CACHE),func(info):
		if not is_same(incoming.get(hash),transfer):return
		disk.discard(transfer.path);incoming.erase(hash)
		if info.has("error"):
			if pending.get(transfer.peer,{}).get("hash","")==hash:pending.erase(transfer.peer)
			message=info.error
			game.loading.fail("model:"+hash,"Required model is invalid: "+message);return
		library.entries[hash]=info
		trace("complete",hash,transfer.peer,{"phase":"verify","transfer_id":transfer.transfer_id,"bytes":transfer.written,"elapsed_ms":Time.get_ticks_msec()-transfer.started})
		game.loading.complete("model:"+hash);message="Avatar downloaded and verified."
		if multiplayer.is_server():
			for id in pending.keys():
				if pending[id].hash==hash and game.players.has(id):
					choices[id]=pending[id];pending.erase(id)
			publish()
		else:
			for id in choices:
				if choices[id].hash==hash:queue_avatar(id)):
		drop_incoming(hash);game.loading.fail("model:"+hash,"Model disk queue is full.")

@rpc("any_peer","call_remote","reliable",4)
func _ack(hash: String, offset: int) -> void:
	var peer := multiplayer.get_remote_sender_id()
	if not outgoing.has(peer): return
	var transfer: Dictionary = outgoing[peer]
	if transfer.hash!=hash or offset<transfer.ack or offset>transfer.sent: return
	transfer.ack = offset
	transfer.time = Time.get_ticks_msec()
	if offset==transfer.size: outgoing.erase(peer)

func drop_incoming(hash: String) -> void:
	if not incoming.has(hash): return
	var peer:int=incoming[hash].peer
	if pending.get(peer,{}).get("hash","")==hash:pending.erase(peer)
	disk.discard(incoming[hash].path)
	incoming.erase(hash)

func select_local(path: String) -> void:
	for hash in library.entries:
		if library.entries[hash].path==path:
			library.selected=hash;offered=""
			return
	var epoch:=generation
	if not disk.submit(Jobs.local_model.bind(path),func(info):
		if epoch!=generation or game.selected_path!=path: return
		if info.has("error"): message=info.error; return
		library.entries[info.hash]=info
		library.selected=info.hash;offered=""): message="Avatar verification queue is full."
