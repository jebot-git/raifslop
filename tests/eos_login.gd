extends SceneTree
## Exercise the real gameplay login wrapper against EOS's credential contract.
const Backend = preload("res://scripts/network/eos/eos_backend.gd")
var failures: Array = []

class LoginSDK extends RefCounted:
	signal connect_interface_login_callback(data: Dictionary)
	signal connect_interface_create_user_callback(data: Dictionary)
	signal connect_interface_create_device_id_callback(data: Dictionary)
	var first_use := false
	var denial := 0
	var logins := 0
	var creates := 0
	var tokens: Array = []
	var names: Array = []
	func connect_interface_login(options: Object) -> void:
		logins += 1
		var credentials: Object = options.get("credentials")
		tokens.append(credentials.get("token"))
		var code := denial
		# EOS requires UserLoginInfo for BOTH Device ID and OculusUseridNonce.
		if credentials.get("type") in [10, 13]:
			var info: Object = options.get("user_login_info")
			if info!=null:names.append(info.get("display_name"))
			if info == null or str(info.get("display_name")).strip_edges().is_empty(): code = 10
		if code == 0 and first_use and logins == 1: code = 3
		connect_interface_login_callback.emit({"client_data":-1,"result_code":0,"local_user_id":"unrelated"})
		connect_interface_login_callback.emit({"client_data":options.get("client_data"),"result_code":code,
			"continuance_token":RefCounted.new() if code == 3 else null,"local_user_id":"test-user"})
	func connect_interface_create_user(options: Object) -> void:
		creates += 1
		connect_interface_create_user_callback.emit({"client_data":options.get("client_data"),"result_code":0})
	func connect_interface_create_device_id(options: Object) -> void:
		connect_interface_create_device_id_callback.emit({"client_data":options.get("client_data"),"result_code":24})

func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label); push_error(label)

func _initialize() -> void: run.call_deferred()

func run() -> void:
	for kind in [10, 13]:
		for first_use in [false, true]:
			var backend := Backend.new(); root.add_child(backend)
			var sdk := LoginSDK.new(); backend.sdk = sdk; sdk.first_use = first_use
			var identity := {"type":kind,"token":"initial-proof","display_name":"  Test angler\n  "}
			var refresh := func(): return {"type":13,"token":"fresh-proof"}
			var error := await backend.login(identity, refresh)
			check(error.is_empty() and backend.product_user_id == "test-user", "Login type %d, first_use=%s supplies required info" % [kind, first_use])
			check(sdk.creates == int(first_use), "Only first-use identities create a user")
			check(sdk.names.all(func(value):return value=="Test angler"),"Rankings receive the player's sanitized display name")
			if kind == 13 and first_use:
				check(sdk.tokens == ["initial-proof", "fresh-proof"], "User creation obtains a fresh Meta proof")
			if error.is_empty():
				check((await backend.login(identity, refresh)).is_empty(), "Reauthentication retains required login info")
			backend.free()
	var backend := Backend.new(); root.add_child(backend)
	var sdk := LoginSDK.new(); backend.sdk = sdk; sdk.denial = 5
	check(not (await backend.login({"type":13,"token":"denied-proof"})).is_empty(), "EOS denial is reported")
	check(backend.product_user_id.is_empty() and sdk.creates == 0, "Denial cannot authenticate or create a user")
	backend.free()
	print("EOS_LOGIN_RESULT ", failures)
	quit(0 if failures.is_empty() else 1)
