extends Node
## ENet host/client lifecycle and 20 Hz replication follow FPSloppa arena.gd.
## Fishing remains owner-simulated; the server validates and relays bounded state.
const SERVER_MAX_PLAYERS := 8 # Eight connected players; an ad-hoc host occupies one slot.
const VERSION := 11 # Shared BBQ ownership and cooking snapshots.
const State = preload("res://scripts/network/state.gd")
var leaderboard=preload("res://scripts/network/leaderboard.gd").new()
var leaderboard_view:Dictionary={}
var player_token:=""
var board_due:=0.0
signal leaderboard_changed
func leaderboard_path()->String:
	var args:=OS.get_cmdline_user_args();var at:=args.find("--leaderboard-path")
	return ProjectSettings.globalize_path(args[at+1]) if at>=0 and at+1<args.size() else ProjectSettings.globalize_path("user://server/leaderboard.json")
func publish_leaderboard()->void:
	if not active or not multiplayer.is_server():return
	leaderboard_view=leaderboard.snapshot();leaderboard_changed.emit()
	for peer in players:
		if peer>1:_leaderboard.rpc_id(peer,leaderboard_view)
	var result:int=leaderboard.save()
	if result!=OK:push_warning("Server leaderboard save failed: "+error_string(result))
@rpc("authority","call_remote","reliable",0)
func _leaderboard(data:Dictionary)->void:
	if multiplayer.is_server():return
	if not data.get("categories") is Dictionary or data.categories.size()!=5:return
	for category in leaderboard.CATEGORIES:
		if not data.categories.get(category) is Array or data.categories[category].size()>50:return
		for row in data.categories[category]:
			if not leaderboard.valid_row(row):return
	leaderboard_view=data.duplicate(true);leaderboard_changed.emit()

var bbq: Node
var root_game: Node
var active := false
var dedicated := false
var headless := false
var voice_enabled := true
var clock := 0.0
var players: Dictionary = {}
var fighters: Dictionary = {}
var states: Dictionary = {}
var guards: Dictionary = {}
var waiting: Dictionary = {}
var loading = preload("res://scripts/network/loading.gd").new()
var permissions = preload("res://scripts/voice/permissions.gd").new()
var avatars = preload("res://scripts/network/avatars.gd").new()
var voice = preload("res://scripts/voice/chat.gd").new()
var display_name := "Angler"
var host_address := "127.0.0.1"
var preferred_port := 24567
var status := "Offline"
var elapsed := 0.0
var serial := 0
var last_event: Array = []
var selected_path := ""
var connect_deadline := 0.0
var metrics_enabled := false
var metrics_next := 0.0
var state_arrivals:Dictionary={}
func state_diagnostics() -> Dictionary:
	var result:Dictionary={}
	var now:=Time.get_ticks_usec()
	for id in state_arrivals:
		var row:Dictionary=state_arrivals[id]
		result[id]={"age_ms":(now-row.last)/1000.0,"max_gap_ms":row.max_gap/1000.0,"accepted":row.count,"serial":row.serial}
		row.max_gap=0
	return result
signal changed

func setup(root: Node, server_only: bool = false) -> void:
	root_game = root
	metrics_enabled="--network-metrics" in OS.get_cmdline_user_args()
	dedicated = server_only
	headless = DisplayServer.get_name()=="headless"
	if not dedicated: load_preferences()
	name = "Network"
	bbq=preload("res://scripts/bbq/network.gd").new();add_child(bbq);bbq.setup(self)
	add_child(permissions)
	add_child(avatars); avatars.setup(self)
	voice.name = "Voice"; add_child(voice); voice.setup(self)
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_left)
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(func(): leave("Connection failed"))
	multiplayer.server_disconnected.connect(func(): leave("Host disconnected — offline fishing continues"))

func load_preferences() -> void:
	var cfg := ConfigFile.new();cfg.load("user://multiplayer.cfg")
	player_token=str(cfg.get_value("identity","token",""))
	if not leaderboard.valid_token(player_token):
		player_token=Crypto.new().generate_random_bytes(32).hex_encode()
		cfg.set_value("identity","token",player_token);cfg.save("user://multiplayer.cfg")
	var chosen_name = cfg.get_value("connection", "name", "Angler")
	display_name = clean_name(chosen_name) if chosen_name is String else "Angler"
	var address = cfg.get_value("connection", "address", "127.0.0.1")
	host_address = address.strip_edges().left(253) if address is String else "127.0.0.1"
	var port = cfg.get_value("connection", "port", 24567)
	preferred_port = clampi(int(port),1024,65535) if (port is int or port is float) and is_finite(port) else 24567

func save_preferences() -> void:
	if dedicated: return
	var cfg := ConfigFile.new()
	cfg.set_value("identity","token",player_token)
	cfg.set_value("connection", "name", display_name)
	cfg.set_value("connection", "address", host_address)
	cfg.set_value("connection", "port", preferred_port)
	var error := cfg.save("user://multiplayer.cfg")
	if error != OK: push_warning("Cannot save multiplayer settings: " + error_string(error))

func host(port: int = 24567, bind_address: String = "*") -> Error:
	leave()
	if port<1024 or port>65535: status="Use a port from 1024 to 65535"; return ERR_INVALID_PARAMETER
	var peer := preload("res://scripts/network/threaded_peer.gd").new()
	peer.set_bind_ip(bind_address)
	var error := peer.create_server(port,SERVER_MAX_PLAYERS if dedicated else SERVER_MAX_PLAYERS-1,7)
	if error!=OK: status="Cannot host: "+error_string(error); changed.emit(); return error
	multiplayer.multiplayer_peer = peer
	active = true
	leaderboard.start(leaderboard_path())
	if not dedicated:
		players[1] = {"name":clean_name(display_name)}
		leaderboard.connect_player(1,player_token,clean_name(display_name))
	publish_leaderboard()
	status = "Hosting on UDP %d%s" % [port," (dedicated)" if dedicated else ""]
	voice.set_mode(voice.mode)
	changed.emit()
	print(status)
	return OK

func join(address: String, port: int = 24567) -> Error:
	leave()
	if address.strip_edges().is_empty() or port<1024 or port>65535: status="Enter a host address and port (1024–65535)"; return ERR_INVALID_PARAMETER
	var peer := preload("res://scripts/network/threaded_peer.gd").new()
	var error := peer.create_client(address.strip_edges(),port,7)
	if error!=OK: status="Cannot join: "+error_string(error); changed.emit(); return error
	multiplayer.multiplayer_peer = peer
	connect_deadline = clock+15
	status = "Connecting to %s:%d…" % [address,port]
	changed.emit()
	return OK

func leave(reason: String = "Offline") -> void:
	if is_instance_valid(bbq):bbq.reset()
	if active and multiplayer.is_server():leaderboard.save()
	leaderboard.peers.clear();leaderboard.attempts.clear();leaderboard_view.clear()
	leaderboard_changed.emit()
	active = false
	connect_deadline = 0
	voice.stop_capture()
	avatars.reset()
	for id in fighters: fighters[id].queue_free()
	fighters.clear(); players.clear(); states.clear(); guards.clear(); waiting.clear()
	voice.reset()
	if multiplayer.multiplayer_peer: multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	serial = 0; last_event.clear(); selected_path = ""; loading.items.clear();loading.errors.clear();state_arrivals.clear()
	status = reason
	changed.emit()

static func clean_name(value: String) -> String:
	var result := ""
	for c in value.left(32):
		if c.unicode_at(0)>=32 and c.unicode_at(0)!=127: result+=c
	return result.strip_edges() if not result.strip_edges().is_empty() else "Angler"

func _peer_connected(id: int) -> void:
	if multiplayer.is_server(): waiting[id]=clock+10
func _connected() -> void:
	_hello.rpc_id(1,VERSION,clean_name(display_name),player_token)
@rpc("any_peer","call_remote","reliable",0)
func _hello(version: int, player_name: String, token: String) -> void:
	if not multiplayer.is_server(): return
	var id := multiplayer.get_remote_sender_id()
	if not waiting.has(id): return
	waiting.erase(id)
	if version!=VERSION or players.size()>=SERVER_MAX_PLAYERS or not leaderboard.valid_token(token) or token.sha256_text() in leaderboard.peers.values():
		multiplayer.multiplayer_peer.disconnect_peer(id)
		return
	players[id]={"name":clean_name(player_name)}
	leaderboard.connect_player(id,token,clean_name(player_name))
	publish_leaderboard()
	_publish_roster()
	for owner in states: _state_event.rpc_id(id,owner,states[owner])
	avatars.sync_peer(id)

func _publish_roster() -> void:
	_roster(players)
	for id in players:
		if id>1: _roster.rpc_id(id,players)
@rpc("authority","call_remote","reliable",0)
func _roster(data: Dictionary) -> void:
	if data.size()>SERVER_MAX_PLAYERS: return
	players=data.duplicate(true)
	active=true; connect_deadline=0
	if not multiplayer.is_server(): status="Connected · %d anglers" % players.size()
	for id in fighters.keys():
		if not players.has(id): fighters[id].queue_free(); fighters.erase(id)
	if not dedicated:
		for id in players:
			if id==multiplayer.get_unique_id() or fighters.has(id): continue
			var actor = load("res://scripts/network/remote_angler.gd").new()
			actor.name="Angler_%d" % id
			actor.session=self; actor.player_name=players[id].name
			root_game.add_child(actor); fighters[id]=actor
	voice.set_mode(voice.mode)
	changed.emit()

func _peer_left(id: int) -> void:
	if is_instance_valid(bbq):bbq.model.release_peer(id);bbq.limits.erase(id)
	leaderboard.disconnect_player(id)
	state_arrivals.erase(id)
	waiting.erase(id); players.erase(id); states.erase(id); guards.erase(id)
	avatars.remove_peer(id); voice.remove_peer(id)
	if fighters.has(id): fighters[id].queue_free(); fighters.erase(id)
	if active and multiplayer.is_server(): _publish_roster(); avatars.publish()
	changed.emit()

func same_location(a: int, b: int) -> bool:
	return states.has(a) and states.has(b) and states[a].location==states[b].location

func _process(delta: float) -> void:
	clock+=delta
	if connect_deadline>0 and clock>connect_deadline: leave("Connection timed out")
	if not active: return
	if multiplayer.is_server() and leaderboard.dirty and clock>=board_due:
		board_due=clock+2.0;publish_leaderboard()
	if metrics_enabled and clock>=metrics_next:
		metrics_next=clock+2.0
		print("NETWORK_METRICS ",JSON.stringify({"ticks_usec":Time.get_ticks_usec(),"seconds":clock,"voice_detail":voice.diagnostics(),"remote_states":state_diagnostics(),"players":players.size(),"states":states.size(),"voice_received":voice.received_packets,"voice_relayed":voice.relayed_packets,"voice_rejected":voice.rejected_packets,"transport":multiplayer.multiplayer_peer.diagnostics()}))
	if multiplayer.is_server():
		for id in waiting.keys():
			if clock>waiting[id]: waiting.erase(id); multiplayer.multiplayer_peer.disconnect_peer(id)
	if dedicated or not players.has(multiplayer.get_unique_id()) or not is_instance_valid(root_game.head): return
	# Register only successful local selections, not remote filesystem paths.
	if not root_game.avatar_loading and selected_path!=root_game.avatars.selected_path:
		selected_path=root_game.avatars.selected_path
		avatars.select_local(selected_path)
	elapsed+=delta
	if elapsed<.05: return
	elapsed=fmod(elapsed,.05); serial+=1
	var data := State.capture(root_game,serial)
	var event := State.event_key(data)
	var reliable := event!=last_event
	last_event=event
	if multiplayer.is_server(): _accept(1,data,reliable)
	else:
		states[multiplayer.get_unique_id()]=data
		if reliable: _submit_event.rpc_id(1,data)
		else: _submit_pose.rpc_id(1,data)

@rpc("any_peer","call_remote","unreliable_ordered",1)
func _submit_pose(data: Dictionary) -> void:
	if multiplayer.is_server(): _accept(multiplayer.get_remote_sender_id(),data,false)
@rpc("any_peer","call_remote","reliable",0)
func _submit_event(data: Dictionary) -> void:
	if multiplayer.is_server(): _accept(multiplayer.get_remote_sender_id(),data,true)
func _accept(id: int, data: Dictionary, reliable: bool) -> void:
	if not players.has(id) or not State.valid(data): return
	if states.has(id) and data.serial<=states[id].serial: return
	var guard: Dictionary=guards.get(id,{"time":clock,"tokens":8.0})
	guard.tokens=minf(8,guard.tokens+maxf(0,clock-guard.time)*30); guard.time=clock; guards[id]=guard
	if guard.tokens<1: return
	guard.tokens-=1
	leaderboard.observe(id,data)
	_apply(id,data)
	for peer in players:
		if peer<=1 or peer==id: continue
		if reliable: _state_event.rpc_id(peer,id,data)
		else: _state_pose.rpc_id(peer,id,data)
@rpc("authority","call_remote","unreliable_ordered",1)
func _state_pose(id: int, data: Dictionary) -> void: _apply(id,data)
@rpc("authority","call_remote","reliable",0)
func _state_event(id: int, data: Dictionary) -> void: _apply(id,data)
func _apply(id: int, data: Dictionary) -> void:
	if not players.has(id) or not State.valid(data): return
	if states.has(id) and data.serial<=states[id].serial: return
	if metrics_enabled:
		var now:=Time.get_ticks_usec()
		var row:Dictionary=state_arrivals.get(id,{"last":now,"count":0,"max_gap":0,"serial":-1})
		row.max_gap=maxi(row.max_gap,now-row.last);row.last=now;row.count+=1;row.serial=data.serial
		state_arrivals[id]=row
	states[id]=data.duplicate(true)
	if fighters.has(id): fighters[id].receive_state(data)

func command_line() -> void:
	var args := OS.get_cmdline_user_args()
	var port := 24567
	var address := "127.0.0.1"
	var bind_address := "*"
	for i in range(args.size()-1):
		match args[i]:
			"--port": port=args[i+1].to_int()
			"--join": address=args[i+1]
			"--bind": bind_address=args[i+1]
			"--name": display_name=args[i+1]
	var error := OK
	if "--host" in args or "--server" in args: error=host(port,bind_address)
	elif "--join" in args: error=join(address,port)
	if error!=OK and dedicated: push_error(status); get_tree().quit(1)

func _exit_tree() -> void:
	if active and multiplayer.is_server():leaderboard.save()
	# Scene teardown must stop the socket worker even without an explicit Leave.
	if multiplayer.multiplayer_peer is MultiplayerPeerExtension:
		multiplayer.multiplayer_peer.close()
