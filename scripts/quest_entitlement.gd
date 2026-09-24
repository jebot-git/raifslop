extends Node
## Only a successful platform result opens the store startup gate.
signal completed(allowed: bool, reason: String)
const TIMEOUT_MS := 10000
var pending := false
var deadline := 0
var provider: Object
var request: Object
var phase := ""

func start(app_id: String, sdk: Object) -> void:
	if pending or not phase.is_empty(): return
	phase = "initializing"
	pending = true
	deadline = Time.get_ticks_msec() + TIMEOUT_MS
	provider = sdk
	if not app_id.is_valid_int() or app_id.begins_with("0") or int(app_id) <= 0:
		_finish(false, "This store build is not configured correctly.")
		return
	if provider == null or not provider.has_method("initialize_platform_async") or not provider.has_method("entitlement_get_is_viewer_entitled_async"):
		_finish(false, "The store connection is unavailable.")
		return
	_watch(provider.initialize_platform_async(app_id), _initialized)

func _watch(value: Object, callback: Callable) -> void:
	request = value
	if request == null or not request.has_signal("completed") or not request.has_method("get_id") or int(request.get_id()) == 0:
		_finish(false, "The store connection could not start.")
		return
	request.connect("completed", callback, CONNECT_ONE_SHOT)

func _initialized(message: Object) -> void:
	if not _accept_callback(): return
	if not _valid_message(message):
		_finish(false, "Could not connect to the store. Check your connection and relaunch.")
		return
	# Initialization can report failure in its result even without an error message.
	var initialization = message.get_platform_initialize() if message.has_method("get_platform_initialize") else null
	if initialization == null or not initialization.has_method("get_result") or int(initialization.get_result()) != 0:
		_finish(false, "Could not initialize the store connection. Relaunch from your library.")
		return
	phase = "checking"
	_watch(provider.entitlement_get_is_viewer_entitled_async(), _checked)

func _checked(message: Object) -> void:
	if not _accept_callback(): return
	if not _valid_message(message):
		_finish(false, "Access could not be verified. Get this free game in the store\nand launch it from the library of the account that owns it.")
	else:
		_finish(true, "")

func _accept_callback() -> bool:
	if not pending: return false
	_process(0.0)
	return pending

func _valid_message(message: Object) -> bool:
	return message != null and message.has_method("is_error") and not message.is_error()

func _process(_delta: float) -> void:
	if pending and Time.get_ticks_msec() >= deadline:
		_finish(false, "The store check timed out. Check your connection\nand relaunch the game from your library.")

func _finish(allowed: bool, reason: String) -> void:
	if not pending: return
	pending = false
	phase = "allowed" if allowed else "denied"
	completed.emit(allowed, reason)
