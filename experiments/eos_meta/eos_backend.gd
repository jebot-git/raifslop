extends Node
const Options = preload("res://options.gd")
const Config = preload("res://config.gd")
signal expired
signal session_lost
signal membership_changed
signal probe_received(rtt_ms: float)
var sdk: Object
var requests := preload("res://requests.gd").new()
var initialized := false
var sdk_started := false
var product_user_id := ""
var lobby_id := ""
var owner_id := ""
var peer: MultiplayerPeer
var members: Array = []
var last_ping := 0
var outstanding: Dictionary = {}
var last_rtt_ms := -1.0
var received := 0
var rejected := 0
var transport := "unknown"
var connection_deadline := 0
var socket_name := ""

func _ready() -> void:
	add_child(requests)
	requests.late_lobby.connect(_abandon_lobby)

func initialize(config: Dictionary) -> String:
	if initialized: return ""
	if not Engine.has_singleton("IEOS") or not ClassDB.class_exists("EOSGMultiplayerPeer"):
		return "EOSG is not installed. Run tools/eos/setup_lab.py."
	sdk = Engine.get_singleton("IEOS")
	var result: int = sdk.platform_interface_initialize(Options.new({"product_name":"UBS EOS Meta Lab","product_version":"0.1"}))
	if result not in [0, 15]: return "EOS initialization failed (%d)." % result
	sdk_started = true
	var values := config.duplicate()
	values.merge({"encryption_key":"","cache_directory":ProjectSettings.globalize_path("user://eos-cache"),
		"flags":6,"is_server":false,"override_country_code":"","override_locale_code":"",
		"tick_budget_in_milliseconds":2,"task_network_timeout_seconds":15.0,
		"rtc_options":Options.new({"background_mode":0})})
	DirAccess.make_dir_recursive_absolute(values.cache_directory)
	if not sdk.platform_interface_create(Options.new(values)): return "EOS platform creation failed. Check portal configuration."
	initialized = true
	var relay_result: int = sdk.p2p_interface_set_relay_control(2 if config.relay == "force" else 1)
	if relay_result != 0: return "EOS relay configuration failed (%d)." % relay_result
	sdk.connect("connect_interface_auth_expiration", func(_data: Dictionary): expired.emit())
	sdk.connect("connect_interface_login_status_changed", func(data: Dictionary):
		if not product_user_id.is_empty() and data.get("current_status") == 0: session_lost.emit())
	sdk.connect("lobby_interface_lobby_member_status_received_callback", _membership)
	sdk.connect("lobby_interface_create_lobby_callback", requests.observe_lobby)
	sdk.connect("lobby_interface_join_lobby_by_id_callback", requests.observe_lobby)
	return ""

func _call(method: String, values: Dictionary) -> Dictionary:
	return await requests.eos(sdk, method, method + "_callback", Options.new(values))

func login(identity: Dictionary, refresh_identity: Callable = Callable()) -> String:
	if identity.type == 10: # EOS_ECT_DEVICEID_ACCESS_TOKEN, stable across test launches.
		var device := await _call("connect_interface_create_device_id", {"device_model":"UBS desktop lab"})
		if device.get("result_code") not in [0, 24]: return "EOS device identity failed (%d)." % device.get("result_code", -1)
	var credentials := Options.new({"type":identity.type,"token":identity.get("token")})
	var options := {"credentials":credentials,"user_login_info":Options.new({"display_name":"UBS Tester","nsa_id_token":""}) if identity.type == 10 else null}
	var answer := await _call("connect_interface_login", options)
	if answer.get("result_code") == 3 and answer.get("continuance_token") != null:
		var created := await _call("connect_interface_create_user", {"continuance_token":answer.continuance_token})
		if created.get("result_code") != 0: return "EOS user creation failed (%d)." % created.get("result_code", -1)
		# EOSG initializes the native peer mediator on a successful LOGIN callback.
		# Obtain a fresh Meta proof for that second authentication request as well.
		if identity.type == 13:
			if not refresh_identity.is_valid(): return "A fresh Meta proof is required after user creation."
			var fresh: Dictionary = await refresh_identity.call()
			if fresh.has("error"): return str(fresh.error)
			credentials.values["token"] = fresh.get("token")
			fresh.clear()
		answer = await _call("connect_interface_login", options)
	credentials.values["token"] = null
	if answer.get("result_code") != 0: return "EOS Connect login failed (%d)." % answer.get("result_code", -1)
	var new_id := str(answer.get("local_user_id", ""))
	if new_id.is_empty() or (not product_user_id.is_empty() and new_id != product_user_id): return "EOS identity changed; restart the lab."
	product_user_id = new_id
	return ""

func create_lobby(config: Dictionary) -> Dictionary:
	var answer := await _call("lobby_interface_create_lobby", {"local_user_id":product_user_id,
		"bucket_id":Config.bucket(config),"lobby_id":"","max_lobby_members":Config.MAX_MEMBERS,
		"permission_level":0,"presence_enabled":false,"allow_invites":true,"disable_host_migration":true,
		"enable_rtc_room":false,"crossplay_opt_out":false,"rtc_room_join_action_type":0,
		"local_rtc_options":null,"enable_join_by_id":true,"rejoin_after_kick_requires_invite":true,"allowed_platform_ids":[]})
	return _lobby_answer(answer)

func join_lobby(id: String) -> Dictionary:
	var answer := await _call("lobby_interface_join_lobby_by_id", {"local_user_id":product_user_id,
		"lobby_id":id,"presence_enabled":false,"local_rtc_options":null,"rtc_room_join_action_type":0})
	return _lobby_answer(answer)

func _lobby_answer(answer: Dictionary) -> Dictionary:
	if answer.get("result_code") != 0: return {"error":"EOS lobby request failed (%d)." % answer.get("result_code", -1)}
	lobby_id = str(answer.get("lobby_id", ""))
	return snapshot()

func snapshot() -> Dictionary:
	if lobby_id.is_empty(): return {"error":"No lobby."}
	var copy: Dictionary = sdk.lobby_interface_copy_lobby_details(Options.new({"local_user_id":product_user_id,"lobby_id":lobby_id}))
	if copy.get("result_code") != 0 or copy.get("lobby_details") == null: return {"error":"Cannot read EOS lobby membership."}
	var details: Object = copy.lobby_details
	var info: Dictionary = details.copy_info()
	if info.get("result_code") != 0: return {"error":"Cannot read EOS lobby details."}
	var data: Dictionary = info.lobby_details.duplicate()
	members.clear()
	for index in details.get_member_count(): members.append(details.get_member_by_index(index))
	data["members"] = members.duplicate()
	return data

func open_peer(host: bool) -> String:
	var info := snapshot()
	if info.has("error"): return info.error
	owner_id = str(info.get("lobby_owner_user_id", ""))
	if host != (owner_id == product_user_id): return "Lobby ownership does not match requested role."
	peer = ClassDB.instantiate("EOSGMultiplayerPeer")
	peer.set_auto_accept_connection_requests(false)
	peer.connect("incoming_connection_request", _admit)
	peer.connect("peer_connection_established", func(data: Dictionary): transport = str(data.get("network_type", "unknown")))
	socket_name = "ubs" + lobby_id.sha256_text().left(24)
	var result: int = peer.create_server(socket_name) if host else peer.create_client(socket_name, owner_id)
	if result != OK:
		peer.close(); peer = null
		return "EOS P2P setup failed (%d)." % result
	connection_deadline = Time.get_ticks_msec() + 20000 if not host else 0
	return ""

func _admit(data: Dictionary) -> void:
	var remote := str(data.get("remote_user_id", ""))
	var info := snapshot()
	if not info.has("error") and remote in members and remote != product_user_id and members.size() <= Config.MAX_MEMBERS:
		peer.accept_connection_request(remote)
	else:
		rejected += 1
		peer.deny_connection_request(remote)

func _membership(data: Dictionary) -> void:
	if data.get("lobby_id") != lobby_id or lobby_id.is_empty(): return
	var info := snapshot()
	if info.has("error") or not product_user_id in members or (not owner_id.is_empty() and info.get("lobby_owner_user_id") != owner_id):
		session_lost.emit()
		return
	if peer != null:
		for id in peer.get_all_peers():
			if not peer.get_peer_user_id(id) in members: peer.disconnect_peer(id)
	membership_changed.emit()

func _process(_delta: float) -> void:
	if initialized: sdk.tick()
	if peer == null: return
	peer.poll()
	var now := Time.get_ticks_msec()
	if connection_deadline > 0 and now > connection_deadline:
		connection_deadline = 0; session_lost.emit(); return
	if peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		session_lost.emit(); return
	# Deliberately tiny raw probes: no gameplay RPCs or avatar files on this peer.
	for _index in mini(peer.get_available_packet_count(), 32):
		var sender := peer.get_packet_peer()
		var bytes := peer.get_packet()
		if bytes.size() != 17 or bytes.decode_u32(0) != 0x55425331: rejected += 1; continue
		if not peer.get_peer_user_id(sender) in members: rejected += 1; continue
		var stamp := bytes.decode_u64(5)
		if bytes[4] == 0 and owner_id == product_user_id:
			bytes[4] = 1
			_send(sender, bytes)
		elif bytes[4] == 1 and sender == 1 and outstanding.has(stamp):
			last_rtt_ms = now - stamp; outstanding.erase(stamp); received += 1
			connection_deadline = 0
			probe_received.emit(last_rtt_ms)
	if owner_id != product_user_id and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED and now - last_ping >= 1000:
		last_ping = now
		var bytes := PackedByteArray(); bytes.resize(17)
		bytes.encode_u32(0, 0x55425331); bytes.encode_u64(5, now)
		if _send(1, bytes) == OK: outstanding[now] = true
		for stamp in outstanding.keys():
			if now - stamp > 10000: outstanding.erase(stamp)

func _send(target: int, bytes: PackedByteArray) -> int:
	peer.set_target_peer(target)
	peer.transfer_channel = 0
	peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_UNRELIABLE
	return peer.put_packet(bytes)

func leave_lobby() -> bool:
	if peer != null: peer.close(); peer = null
	connection_deadline = 0; outstanding.clear(); members.clear(); owner_id = ""
	var old := lobby_id; lobby_id = ""
	if old.is_empty(): return true
	var answer := await _call("lobby_interface_leave_lobby", {"local_user_id":product_user_id,"lobby_id":old})
	return answer.get("result_code") == 0

func _abandon_lobby(id: String) -> void:
	if not id.is_empty(): await _call("lobby_interface_leave_lobby", {"local_user_id":product_user_id,"lobby_id":id})

func diagnostics() -> Dictionary:
	return {"probe_replies":received,"rtt_ms":last_rtt_ms,"rejected":rejected,"network_type":transport,
		"queues":sdk.p2p_interface_get_packet_queue_info() if initialized else {}}

func _exit_tree() -> void:
	if peer != null: peer.close(); peer = null
	if initialized:
		initialized = false
		sdk.platform_interface_release()
	if sdk_started:
		sdk_started = false
		sdk.platform_interface_shutdown()
