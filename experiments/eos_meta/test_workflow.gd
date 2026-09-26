extends SceneTree
const Config = preload("res://config.gd")
const Workflow = preload("res://workflow.gd")
const Backend = preload("res://eos_backend.gd")
const Requests = preload("res://requests.gd")
const Options = preload("res://options.gd")
var checks := 0
var failures := 0

class FakeBackend extends Node:
	signal expired
	signal session_lost
	signal membership_changed
	var product_user_id := "test-user"
	var lobby_id := "lab-lobby"
	var login_error := ""
	var lobby_error := ""
	var peer_error := ""
	var mismatch := false
	var logins := 0
	var leaves := 0
	var peers := 0
	var slots := 7
	var login_types: Array = []
	func initialize(_config: Dictionary) -> String: return ""
	func login(identity: Dictionary, _refresh: Callable = Callable()) -> String:
		logins += 1; login_types.append(identity.type)
		return login_error
	func snapshot() -> Dictionary:
		return {"bucket_id":"wrong" if mismatch else "ubs-eos-lab-v1", "max_members":8,"members":[product_user_id],"available_slots":slots}
	func create_lobby(_config: Dictionary) -> Dictionary: return snapshot() if lobby_error.is_empty() else {"error":lobby_error}
	func join_lobby(_id: String) -> Dictionary: return snapshot() if lobby_error.is_empty() else {"error":lobby_error}
	func open_peer(_host: bool) -> String: peers += 1; return peer_error
	func leave_lobby() -> bool: leaves += 1; return true

class FakeMeta extends Node:
	signal join_requested(reference: String)
	signal leave_requested(lobby: String)
	var proofs := 0
	var clears := 0
	var publish_ok := true
	var identity_error := ""
	var joinable := false
	var invites := 0
	func identity(_config: Dictionary) -> Dictionary:
		proofs += 1
		return {"type":13,"token":"fresh-proof-%d" % proofs} if identity_error.is_empty() else {"error":identity_error}
	func publish(_config: Dictionary, _lobby: String, can_join: bool) -> bool: joinable = can_join; return publish_ok
	func clear() -> bool: clears += 1; return true
	func invite() -> bool: invites += 1; return true

class LoginSDK extends RefCounted:
	signal connect_interface_login_callback(data: Dictionary)
	signal connect_interface_create_user_callback(data: Dictionary)
	signal connect_interface_create_device_id_callback(data: Dictionary)
	var login_count := 0
	var creates := 0
	var device_count := 0
	var types: Array = []
	var tokens: Array = []
	var failure := 0
	func connect_interface_login(options: Object) -> void:
		login_count += 1; types.append(options.get("credentials").get("type"))
		tokens.append(options.get("credentials").get("token"))
		# Match the native SDK: Oculus and Device ID both require login info.
		var info: Object = options.get("user_login_info")
		if types.back() in [10, 13] and (info == null or str(info.get("display_name")).strip_edges().is_empty()):
			connect_interface_login_callback.emit({"client_data":options.get("client_data"),"result_code":10})
			return
		connect_interface_login_callback.emit({"client_data":-1,"result_code":0,"local_user_id":"wrong"})
		connect_interface_login_callback.emit({"client_data":options.get("client_data"),"result_code":failure if failure else (3 if login_count == 1 else 0),"continuance_token":RefCounted.new(),"local_user_id":"native-user"})
	func connect_interface_create_user(options: Object) -> void:
		creates += 1
		connect_interface_create_user_callback.emit({"client_data":options.get("client_data"),"result_code":0,"local_user_id":"native-user"})
	func connect_interface_create_device_id(options: Object) -> void:
		device_count += 1
		connect_interface_create_device_id_callback.emit({"client_data":options.get("client_data"),"result_code":24})

class SilentSDK extends RefCounted:
	signal reply(data: Dictionary)
	var tag := 0
	func request(options: Object) -> void: tag = options.get("client_data")

class MetaRequest extends RefCounted:
	signal completed(message: Object)
	func get_id() -> int: return 1
	func finish(message: Object) -> void: completed.emit(message)

class MetaPayload extends RefCounted:
	var nonce := ""
	var result := 0
	func get_id() -> int: return 12345
	func get_nonce() -> String: return nonce
	func get_result() -> int: return result

class MetaMessage extends RefCounted:
	var payload := MetaPayload.new()
	var error := false
	func is_error() -> bool: return error
	func get_user() -> Object: return payload
	func get_user_proof() -> Object: return payload
	func get_platform_initialize() -> Object: return payload

class MetaSDK extends RefCounted:
	signal notification_received(message: Object)
	var scenario := "success"
	var proofs := 0
	var entitlements := 0
	var initialized := false
	func is_platform_initialized() -> bool: return initialized
	func reply(kind: String) -> Object:
		var request := MetaRequest.new(); var message := MetaMessage.new()
		message.error = scenario == kind
		message.payload.nonce = "nonce-%d" % proofs
		if scenario == "empty_nonce": message.payload.nonce = ""
		if scenario == "init_result": message.payload.result = -1
		request.finish.call_deferred(message)
		return request
	func initialize_platform_async(_id: String) -> Object:
		initialized = true
		return reply("init")
	func entitlement_get_is_viewer_entitled_async() -> Object: entitlements += 1; return reply("entitlement")
	func user_get_logged_in_user_async() -> Object: return reply("user")
	func user_get_user_proof_async() -> Object: proofs += 1; return reply("proof")
	func application_lifecycle_get_launch_details() -> Object: return null

func expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("EOS_TEST_FAIL " + label)

func settings(provider: String = "meta") -> Dictionary:
	return {"product_id":"test-product","sandbox_id":"test-sandbox","deployment_id":"test-deployment","client_id":"test-client","client_secret":"test-placeholder","relay":"auto","provider":provider,"app_id":"12345","destination":"eos_lab"}

func _initialize() -> void: _run.call_deferred()

func fixture() -> Array:
	var backend := FakeBackend.new(); var meta := FakeMeta.new(); var flow := Workflow.new()
	root.add_child(backend); root.add_child(meta); root.add_child(flow)
	flow.setup(backend, meta)
	return [flow, backend, meta]

func dispose(values: Array) -> void:
	for value in values: value.free()

func _run() -> void:
	var config := settings()
	expect(Config.validate(config).is_empty(), "valid Meta configuration")
	for key in ["product_id","sandbox_id","deployment_id","client_id","client_secret"]:
		var missing := config.duplicate(); missing.erase(key)
		expect(not Config.validate(missing).is_empty(), "missing " + key)
	expect(not Config.validate(settings("device"), "Android").is_empty(), "no device auth bypass on Quest")
	expect(Config.validate(settings("device"), "Linux").is_empty(), "desktop device identity")
	var reference := Config.join_reference(config, "lobby-1")
	expect(Config.parse_reference(config, reference) == "lobby-1", "reference round trip")
	for invalid in ["{}", "[]", "not json", reference.replace("test-deployment","other"), reference.replace('"v":1','"v":2'), reference.replace("lobby-1","../bad"), "a".repeat(1025)]:
		expect(Config.parse_reference(config, invalid).is_empty(), "reject invalid reference")
	for scenario in ["host", "join", "identity_denied", "login_denied", "full", "mismatch", "peer_failure", "presence_failure", "refresh", "refresh_failure", "host_loss", "invite", "device"]:
		var values := fixture(); var flow = values[0]; var backend = values[1]; var meta = values[2]
		if scenario == "identity_denied": meta.identity_error = "denied"
		if scenario == "login_denied": backend.login_error = "denied"
		await flow.connect_services(settings("device" if scenario == "device" else "meta"))
		if scenario in ["identity_denied", "login_denied"]:
			expect(flow.state == "error" and backend.peers == 0, scenario + " fails closed")
			dispose(values); continue
		expect(flow.state == "ready", scenario + " authenticates")
		if scenario == "full": backend.lobby_error = "Lobby full"
		if scenario == "mismatch": backend.mismatch = true
		if scenario == "peer_failure": backend.peer_error = "Peer failed"
		if scenario == "presence_failure": meta.publish_ok = false
		if scenario == "join": await flow.join_reference(reference)
		else: await flow.host()
		if scenario in ["full", "mismatch", "peer_failure"]:
			expect(flow.state == "ready" and backend.leaves == 1 and flow.lobby.is_empty(), scenario + " cleans up")
			if scenario != "peer_failure": expect(backend.peers == 0, scenario + " never opens transport")
		elif scenario == "presence_failure":
			expect(flow.state == "lobby" and not flow.presence_ready, "presence failure keeps peer but disables invites")
		else:
			expect(flow.state == "lobby" and backend.peers == 1, scenario + " peer opens")
			if scenario in ["refresh", "refresh_failure"]:
				if scenario == "refresh_failure": backend.login_error = "expired"
				backend.expired.emit(); await flow._process(0)
				expect(meta.proofs == 2 and backend.logins == 2, "fresh proof on refresh")
				expect(flow.state == ("error" if scenario == "refresh_failure" else "lobby"), "refresh state")
			elif scenario == "host_loss":
				flow.busy = true; backend.session_lost.emit(); await flow._process(0)
				expect(backend.leaves == 0, "loss waits for outstanding operation")
				flow.busy = false; await flow._process(0)
				expect(flow.state == "ready" and backend.leaves == 1 and meta.clears == 1, "host loss cleanup")
			elif scenario == "invite":
				flow.queue_invite(reference)
				expect(flow.state == "lobby" and flow.pending_reference == reference, "warm invite preserves working session")
				await flow.invite(); expect(meta.invites == 1, "explicit invite panel")
				backend.slots = 0; backend.membership_changed.emit(); await flow._process(0)
				expect(not meta.joinable, "full lobby stops joinability")
			elif scenario == "device": expect(meta.proofs == 0 and backend.login_types == [10], "device login only explicit desktop path")
		dispose(values)
	# Actual low-level login wrapper: first-use creation, second login, callback correlation.
	for mode in ["meta", "device", "failure"]:
		var backend := Backend.new(); root.add_child(backend)
		var sdk := LoginSDK.new(); backend.sdk = sdk
		if mode == "failure": sdk.failure = 5
		var result := await backend.login({"type":10 if mode == "device" else 13,"token":"test-nonce"}, func(): return {"type":13,"token":"new-test-nonce"})
		if mode == "failure": expect(not result.is_empty() and sdk.creates == 0, "login denial does not create user")
		else:
			expect(result.is_empty() and backend.product_user_id == "native-user", "correlated native login result")
			expect(sdk.login_count == 2 and sdk.creates == 1, "new user logs in again for EOSG peer")
			expect(sdk.device_count == (1 if mode == "device" else 0), "existing device ID reused")
			if mode == "meta": expect(sdk.tokens == ["test-nonce", "new-test-nonce"], "first-use follow-up login obtains fresh Meta proof")
		backend.free()
	var requests := Requests.new(); root.add_child(requests); requests.timeout_ms = 1
	var silent := SilentSDK.new()
	var result := await requests.eos(silent, "request", "reply", Options.new())
	expect(result.result_code == 27, "bounded missing callback timeout")
	var cleaned: Array = []
	requests.late_lobby.connect(func(id: String): cleaned.append(id))
	requests.observe_lobby({"client_data":silent.tag,"result_code":0,"lobby_id":"late-lobby"})
	expect(cleaned == ["late-lobby"], "late successful lobby is cleaned up")
	expect((await requests.meta(null)) == null, "missing Meta request fails closed")
	requests.free()
	# Exercise the actual Meta adapter, including initialization-result failures.
	for scenario in ["success", "init", "init_result", "entitlement", "user", "proof", "empty_nonce"]:
		var provider := preload("res://meta_provider.gd").new(); root.add_child(provider)
		var sdk := MetaSDK.new(); sdk.scenario = scenario; provider.sdk = sdk
		var identity := await provider.identity(settings())
		if scenario == "success":
			expect(identity == {"type":13,"token":"12345|nonce-1"}, "Meta credential format")
			identity = await provider.identity(settings())
			expect(identity.token == "12345|nonce-2" and sdk.proofs == 2, "Meta refresh never reuses nonce")
		else:
			expect(identity.has("error") and not identity.has("token"), "Meta " + scenario + " fails closed")
			if scenario in ["init", "init_result"]: expect(sdk.entitlements == 0, "failed initialization never checks entitlement")
			if scenario == "entitlement": expect(sdk.proofs == 0, "entitlement denial never requests proof")
		provider.free()
	if Engine.has_singleton("IEOS"):
		expect(ClassDB.class_exists("EOSGMultiplayerPeer"), "native peer registered")
		for method in ["platform_interface_initialize","connect_interface_login","lobby_interface_create_lobby","lobby_interface_join_lobby_by_id","lobby_interface_copy_lobby_details","tick"]:
			expect(Engine.get_singleton("IEOS").has_method(method), "native API " + method)
		var native: Object = Engine.get_singleton("IEOS")
		var init_result: int = native.platform_interface_initialize(Options.new({"product_name":"UBS EOS Meta Lab","product_version":"0.1"}))
		expect(init_result == 0, "real native SDK initializes without account or platform creation")
		if init_result == 0: expect(native.platform_interface_shutdown() == 0, "real native SDK shuts down")
	print("EOS_META_TEST_RESULT checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
