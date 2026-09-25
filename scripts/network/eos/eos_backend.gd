extends Node
const Options = preload("res://scripts/network/eos/options.gd")
const Config = preload("res://scripts/network/eos/config.gd")
signal expired
signal session_lost
signal membership_changed
var sdk: Object
var requests := preload("res://scripts/network/eos/requests.gd").new()
var initialized := false
var sdk_started := false
var product_user_id := ""
var lobby_id := ""
var owner_id := ""
var peer: MultiplayerPeer
var members: Array = []
var rejected := 0
var transport := "unknown"
var socket_name := ""
var deployment := ""
var initialization_error := ""
var search_pending := false
var search_poisoned := false

func _ready() -> void:
	add_child(requests)
	requests.late_lobby.connect(_abandon_lobby)

func initialize(config: Dictionary) -> String:
	if initialized: return initialization_error
	if not Engine.has_singleton("IEOS"):
		var extension := "res://addons/epic-online-services-godot/eosg.gdextension"
		if FileAccess.file_exists(extension): GDExtensionManager.load_extension(extension)
	if not Engine.has_singleton("IEOS") or not ClassDB.class_exists("EOSGMultiplayerPeer"):
		return "EOSG is not installed. Run tools/eos/setup_lab.py --game."
	sdk = Engine.get_singleton("IEOS")
	var result: int = sdk.platform_interface_initialize(Options.new({"product_name":"Ultimate Boomer Simulator","product_version":"0.1"}))
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
	initialization_error = "EOS initialization incomplete. Restart the game."
	var queue_result: int = sdk.p2p_interface_set_packet_queue_size(Options.new({"incoming_packet_queue_max_size_bytes":2097152,"outgoing_packet_queue_max_size_bytes":262144}))
	if queue_result != 0: return "EOS queue configuration failed (%d). Restart the game." % queue_result
	if Engine.has_singleton("EOSGPacketPeerMediator"):
		Engine.get_singleton("EOSGPacketPeerMediator").set_queue_size_limit(2048)
	deployment = config.deployment_id
	var relay_result: int = sdk.p2p_interface_set_relay_control(2 if config.relay == "force" else 1)
	if relay_result != 0: return "EOS relay configuration failed (%d)." % relay_result
	sdk.connect("connect_interface_auth_expiration", func(_data: Dictionary): expired.emit())
	sdk.connect("connect_interface_login_status_changed", func(data: Dictionary):
		if not product_user_id.is_empty() and data.get("current_status") == 0: session_lost.emit())
	sdk.connect("lobby_interface_lobby_member_status_received_callback", _membership)
	sdk.connect("lobby_interface_create_lobby_callback", requests.observe_lobby)
	sdk.connect("lobby_interface_join_lobby_by_id_callback", requests.observe_lobby)
	initialization_error = ""
	return ""

func _call(method: String, values: Dictionary) -> Dictionary:
	return await requests.eos(sdk, method, method + "_callback", Options.new(values))

func login(identity: Dictionary, refresh_identity: Callable = Callable()) -> String:
	if identity.type == 10: # EOS_ECT_DEVICEID_ACCESS_TOKEN, stable across test launches.
		var device := await _call("connect_interface_create_device_id", {"device_model":"UBS desktop test"})
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
	if new_id.is_empty() or (not product_user_id.is_empty() and new_id != product_user_id): return "EOS identity changed; restart the game."
	product_user_id = new_id
	return ""

func create_lobby(config: Dictionary, title:String="Fishing together", locked:bool=false) -> Dictionary:
	var answer := await _call("lobby_interface_create_lobby", {"local_user_id":product_user_id,
		"bucket_id":Config.bucket(config),"lobby_id":"","max_lobby_members":Config.MAX_MEMBERS,
		"permission_level":0,"presence_enabled":false,"allow_invites":true,"disable_host_migration":true,
		"enable_rtc_room":false,"crossplay_opt_out":false,"rtc_room_join_action_type":0,
		"local_rtc_options":null,"enable_join_by_id":true,"rejoin_after_kick_requires_invite":false,"allowed_platform_ids":[]})
	var info:=_lobby_answer(answer)
	if info.has("error"):return info
	var modified:Dictionary=sdk.lobby_interface_update_lobby_modification(Options.new({"local_user_id":product_user_id,"lobby_id":lobby_id}))
	if modified.get("result_code")!=0:return {"error":"Cannot publish lobby listing."}
	var update:Object=modified.lobby_modification
	for pair in [["ubs_bucket",Config.bucket(config)],["ubs_name",title],["ubs_locked",locked],["ubs_protocol",Config.PROTOCOL]]:
		if update.add_attribute(pair[0],pair[1],0)!=0:return {"error":"Cannot set lobby details."}
	var published:=await _call("lobby_interface_update_lobby",{"lobby_modification":update})
	if published.get("result_code")!=0:return {"error":"Cannot publish lobby listing (%d)."%published.get("result_code",-1)}
	return snapshot()

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
	data["title"] = attribute(details,"ubs_name","")
	data["locked"] = attribute(details,"ubs_locked",false)
	return data

static func attribute(details:Object,key:String,fallback:Variant)->Variant:
	var value:Dictionary=details.copy_attribute_by_key(key)
	if value.get("result_code")!=0:return fallback
	var data:Dictionary=value.get("attribute",{}).get("data",{})
	var result:Variant=data.get("value",fallback)
	# EOSG converts EOS_Bool (an int32) to a Godot integer, not a bool.
	if fallback is bool and result is int and result in [0,1]:return bool(result)
	return result

func browse(config:Dictionary)->Dictionary:
	if search_pending or search_poisoned:return {"error":"Lobby search is still finishing. Restart the game after a timeout."}
	var result:Dictionary=sdk.lobby_interface_create_lobby_search(Options.new({"max_results":50}))
	if result.get("result_code")!=0:return {"error":"Cannot start lobby search."}
	var search:Object=result.lobby_search
	if search.set_parameter("ubs_bucket",Config.bucket(config),0)!=0 or search.set_parameter("ubs_protocol",Config.PROTOCOL,0)!=0:
		return {"error":"Cannot filter lobby search."}
	# EOSG's search callback has no client_data. Serialize it and prohibit reuse
	# after timeout so a late callback cannot complete a newer search.
	search_pending=true
	var replies:Array=[]
	var receive:=func(data:Dictionary):replies.append(data)
	sdk.connect("lobby_search_find_callback",receive);search.find(product_user_id)
	var deadline:=Time.get_ticks_msec()+15000
	while replies.is_empty() and Time.get_ticks_msec()<deadline:await get_tree().process_frame
	sdk.disconnect("lobby_search_find_callback",receive);search_pending=false
	if replies.is_empty():search_poisoned=true;return {"error":"Lobby search timed out. Restart the game to retry."}
	if replies[0].get("result_code")!=0:return {"error":"Lobby search failed (%d)."%replies[0].get("result_code",-1)}
	var rows:Array=[]
	for i in mini(50,search.get_search_result_count()):
		var copied:Dictionary=search.copy_search_result_by_index(i)
		if copied.get("result_code")!=0:continue
		var details:Object=copied.lobby_details
		var info:Dictionary=details.copy_info()
		if info.get("result_code")!=0:continue
		var data:Dictionary=info.lobby_details
		var title:Variant=attribute(details,"ubs_name","")
		var locked:Variant=attribute(details,"ubs_locked",false)
		if data.get("bucket_id")!=Config.bucket(config) or data.get("max_members")!=8 or not title is String or not locked is bool:continue
		if Config.clean_title(title).is_empty():continue
		rows.append({"id":str(data.get("lobby_id","")),"title":Config.clean_title(title),"locked":locked,"members":details.get_member_count(),"capacity":8})
	rows.sort_custom(func(a,b):return a.title.naturalnocasecmp_to(b.title)<0)
	return {"lobbies":rows}

func reject_member(id:int)->void:
	if peer==null or owner_id!=product_user_id or id not in peer.get_all_peers():return
	var remote:String=peer.get_peer_user_id(id)
	if remote.is_empty():return
	await _call("lobby_interface_kick_member",{"local_user_id":product_user_id,"lobby_id":lobby_id,"target_user_id":remote})

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
	# EOS callbacks and native mediator run on this same thread. SceneMultiplayer
	# exclusively polls/consumes the wrapped gameplay peer; no probe drain here.
	assert(OS.get_thread_caller_id() == OS.get_main_thread_id())
	if initialized: sdk.tick()

func identity_token(id: int) -> String:
	if peer == null: return ""
	var puid: String = product_user_id if id == peer.get_unique_id() else peer.get_peer_user_id(id)
	if puid.is_empty() or puid not in members: return ""
	return ("eos:" + deployment + ":" + puid).sha256_text()

func leave_lobby() -> bool:
	if peer != null: peer.close(); peer = null
	members.clear(); owner_id = ""
	var old := lobby_id; lobby_id = ""
	if old.is_empty(): return true
	var answer := await _call("lobby_interface_leave_lobby", {"local_user_id":product_user_id,"lobby_id":old})
	return answer.get("result_code") == 0

func _abandon_lobby(id: String) -> void:
	if not id.is_empty(): await _call("lobby_interface_leave_lobby", {"local_user_id":product_user_id,"lobby_id":id})

func diagnostics() -> Dictionary:
	return {"rejected":rejected,"network_type":transport,
		"queues":sdk.p2p_interface_get_packet_queue_info() if initialized else {}}

func _exit_tree() -> void:
	if peer != null: peer.close(); peer = null
	if initialized:
		initialized = false
		sdk.platform_interface_release()
	if sdk_started:
		sdk_started = false
		sdk.platform_interface_shutdown()
