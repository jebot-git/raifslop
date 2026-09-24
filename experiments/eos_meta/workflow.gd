extends Node
const Config = preload("res://config.gd")
signal changed
var backend: Node
var meta: Node
var config: Dictionary = {}
var state := "offline"
var status := "Configure EOS, then connect."
var lobby := ""
var pending_reference := ""
var busy := false
var generation := 0
var presence_ready := false
var refresh_due := false
var loss_due := false
var presence_due := false

func setup(eos_backend: Node, meta_provider: Node) -> void:
	backend = eos_backend; meta = meta_provider
	backend.expired.connect(func(): refresh_due = true)
	backend.session_lost.connect(func(): loss_due = true)
	backend.membership_changed.connect(func(): presence_due = true)
	meta.join_requested.connect(queue_invite)
	meta.leave_requested.connect(func(id: String):
		if not id.is_empty() and id == lobby: loss_due = true)

func _show(next: String, message: String) -> void:
	state = next; status = message; changed.emit()
	# Only controlled phase text reaches logs, never credentials or callback payloads.
	print("EOS_META phase=", state, " message=", message)

func connect_services(settings: Dictionary) -> void:
	if busy or state != "offline": return
	config = settings.duplicate()
	var error := Config.validate(config)
	if not error.is_empty(): _show("offline", error); return
	busy = true
	_show("authenticating", "Connecting to online services…")
	error = backend.initialize(config)
	if error.is_empty(): error = await _authenticate()
	busy = false
	if not error.is_empty(): _show("error", error); return
	_show("ready", "Online services ready. Host a lab lobby or paste a join reference.")
	if not pending_reference.is_empty(): join_reference(pending_reference)

func _authenticate() -> String:
	var identity: Dictionary = await meta.identity(config) if config.provider == "meta" else {"type":10}
	if identity.has("error"): return identity.error
	var error: String = await backend.login(identity, meta.identity.bind(config))
	identity.clear()
	return error

func host() -> void:
	if busy or state != "ready": return
	busy = true; generation += 1
	var current := generation
	_show("creating", "Creating EOS lab lobby…")
	var answer: Dictionary = await backend.create_lobby(config)
	await _enter(answer, true, current)

func queue_invite(reference: String) -> void:
	if Config.parse_reference(config, reference).is_empty(): return
	if reference == Config.join_reference(config, lobby): return
	pending_reference = reference
	changed.emit()
	if state == "ready" and not busy: join_reference(reference)
	# While already in a session, retain it until the user leaves and accepts.

func join_reference(reference: String) -> void:
	if busy or state != "ready": return
	var id := Config.parse_reference(config, reference)
	if id.is_empty(): _show("ready", "Invalid join reference or different deployment/protocol."); return
	busy = true; generation += 1
	var current := generation
	pending_reference = ""
	_show("joining", "Joining EOS lab lobby…")
	var answer: Dictionary = await backend.join_lobby(id)
	await _enter(answer, false, current)

func _enter(answer: Dictionary, host_role: bool, current: int) -> void:
	if current != generation:
		await backend.leave_lobby(); busy = false; return
	var error := str(answer.get("error", ""))
	if error.is_empty():
		if answer.get("bucket_id") != Config.bucket(config) or answer.get("max_members") != Config.MAX_MEMBERS or not backend.product_user_id in answer.get("members", []):
			error = "Lobby protocol, capacity or membership does not match this lab."
	if error.is_empty(): error = backend.open_peer(host_role)
	if not error.is_empty():
		await backend.leave_lobby()
		busy = false
		_show("ready", error)
		return
	lobby = backend.lobby_id
	presence_ready = await meta.publish(config, lobby, answer.get("available_slots", 0) > 0)
	busy = false
	_show("lobby", "Lobby active. P2P probe running." if presence_ready else "Lobby active. Meta presence failed; invitations unavailable.")

func _update_presence() -> void:
	if lobby.is_empty() or busy: return
	busy = true; changed.emit()
	var info: Dictionary = backend.snapshot()
	presence_ready = await meta.publish(config, lobby, not info.has("error") and info.get("available_slots", 0) > 0)
	busy = false; changed.emit()

func invite() -> void:
	if busy or state != "lobby" or not presence_ready or config.provider != "meta": return
	busy = true; changed.emit()
	var opened: bool = await meta.invite()
	busy = false; changed.emit()
	if not opened: _show("lobby", "Could not open Meta invite panel.")

func leave(message: String = "Left lobby.") -> void:
	if busy: return # Native calls are serialized; UI disables leave during a request.
	busy = true; generation += 1
	_show("leaving", "Leaving online lobby…")
	presence_ready = false
	var cleared: bool = await meta.clear()
	var left: bool = await backend.leave_lobby()
	lobby = ""; busy = false; loss_due = false; presence_due = false
	_show("ready", message if cleared and left else "Local session closed; remote cleanup failed or timed out.")

func _process(_delta: float) -> void:
	if busy: return
	if loss_due and state == "lobby":
		await leave("Session ended. The host may have disconnected.")
		return
	if presence_due and state == "lobby":
		presence_due = false
		await _update_presence()
		return
	if not refresh_due or busy or state not in ["ready", "lobby"]: return
	refresh_due = false; busy = true
	changed.emit()
	var error := await _authenticate() # Meta provider obtains a NEW proof nonce.
	busy = false; changed.emit()
	if not error.is_empty():
		await leave("Authentication expired; reconnect after restarting the lab.")
		_show("error", error)
