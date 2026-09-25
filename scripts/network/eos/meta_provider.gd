extends Node
signal join_requested(reference: String)
signal leave_requested(lobby: String)
var sdk: Object
var requests := preload("res://scripts/network/eos/requests.gd").new()
var destination := ""
var enabled := false
var user_id := ""
var settings:Dictionary={}

func _ready() -> void: add_child(requests)

func identity(config: Dictionary) -> Dictionary:
	if sdk == null:
		if not Engine.has_singleton("MetaPlatformSDK"): return {"error":"Meta Platform SDK is not installed."}
		sdk = Engine.get_singleton("MetaPlatformSDK")
	settings={"deployment_id":config.deployment_id}
	destination = config.destination
	if not sdk.is_platform_initialized():
		var init: Object = await requests.meta(sdk.initialize_platform_async(config.app_id))
		if init == null or init.get_platform_initialize() == null or init.get_platform_initialize().get_result() != 0:
			return {"error":"Meta initialization failed."}
	if await requests.meta(sdk.entitlement_get_is_viewer_entitled_async()) == null:
		return {"error":"Meta entitlement denied or timed out."}
	var user_message: Object = await requests.meta(sdk.user_get_logged_in_user_async())
	if user_message == null or user_message.get_user() == null: return {"error":"Meta user lookup failed."}
	var user: Object = user_message.get_user()
	var proof_message: Object = await requests.meta(sdk.user_get_user_proof_async())
	if proof_message == null or proof_message.get_user_proof() == null: return {"error":"Meta proof request failed."}
	var resolved_id := str(user.get_id())
	var nonce := str(proof_message.get_user_proof().get_nonce())
	if not resolved_id.is_valid_int() or int(resolved_id) <= 0 or nonce.is_empty(): return {"error":"Meta returned an invalid identity."}
	if not sdk.is_connected("notification_received", _on_platform_notification): sdk.connect("notification_received", _on_platform_notification)
	user_id = resolved_id
	enabled = true
	_read_intent(sdk.application_lifecycle_get_launch_details())
	return {"type":13,"token":resolved_id + "|" + nonce} # EOS_ECT_OCULUS_USERID_NONCE

func _read_intent(details: Object) -> void:
	if details == null or str(details.get_destination_api_name()) != destination: return
	var reference := str(details.get_deeplink_message())
	if reference.is_empty() and details.has_method("get_lobby_session_id"):
		var lobby:=str(details.get_lobby_session_id())
		if not lobby.is_empty():reference=preload("res://scripts/network/eos/config.gd").join_reference(settings,lobby)
	if not reference.is_empty(): join_requested.emit(reference)

func _on_platform_notification(message: Object) -> void:
	if message == null or message.is_error(): return
	match int(message.get_type()):
		78859427: _read_intent(sdk.application_lifecycle_get_launch_details())
		2000194038: _read_intent(message.get_group_presence_join_intent())
		1194846749:
			var intent: Object = message.get_group_presence_leave_intent()
			if intent != null and str(intent.get_destination_api_name()) == destination:
				leave_requested.emit(str(intent.get_lobby_session_id()))

func publish(config: Dictionary, lobby: String, joinable: bool) -> bool:
	if not enabled: return true
	var options: Object = ClassDB.instantiate("MetaPlatformSDK_GroupPresenceOptions")
	options.set_destination_api_name(destination)
	options.set_lobby_session_id(lobby)
	options.set_is_joinable(joinable)
	options.set_deeplink_message_override(preload("res://scripts/network/eos/config.gd").join_reference(config, lobby))
	return await requests.meta(sdk.group_presence_set_async(options)) != null

func clear() -> bool:
	if not enabled: return true
	return await requests.meta(sdk.group_presence_clear_async()) != null

func invite() -> bool:
	if not enabled: return false
	var options: Object = ClassDB.instantiate("MetaPlatformSDK_InviteOptions")
	return await requests.meta(sdk.group_presence_launch_invite_panel_async(options)) != null
