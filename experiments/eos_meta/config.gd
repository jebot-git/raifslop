extends RefCounted
const PROTOCOL := 1 # Lab protocol, deliberately separate from gameplay protocol 17.
const MAX_MEMBERS := 8

static func read(path: String) -> Dictionary:
	var file := ConfigFile.new()
	if file.load(path) != OK: return {"error":"Configuration missing. Copy config.example.cfg to private/eos.cfg."}
	var result: Dictionary = {}
	for key in ["product_id", "sandbox_id", "deployment_id", "client_id", "client_secret", "relay"]:
		result[key] = file.get_value("eos", key, "auto" if key == "relay" else "")
	result.provider = file.get_value("identity", "provider", "meta")
	result.app_id = file.get_value("meta", "app_id", "")
	result.destination = file.get_value("meta", "destination", "eos_lab")
	return result

static func validate(config: Dictionary, platform: String = OS.get_name()) -> String:
	if config.has("error"): return str(config.error)
	for key in ["product_id", "sandbox_id", "deployment_id", "client_id", "client_secret"]:
		if not config.get(key) is String or config[key].strip_edges().is_empty(): return "Missing EOS setting: " + key
	if config.get("relay") not in ["auto", "force"]: return "Relay must be auto or force."
	if config.get("provider") not in ["meta", "device"]: return "Identity must be meta or device."
	if platform == "Android" and config.provider != "meta": return "Quest requires Meta identity and entitlement."
	if config.provider == "meta":
		if not config.get("app_id") is String or not config.app_id.is_valid_int() or int(config.app_id) <= 0: return "Missing numeric Meta app ID."
		if not config.get("destination") is String or config.destination.is_empty(): return "Missing Meta destination."
	return ""

static func bucket(_config: Dictionary) -> String:
	return "ubs-eos-lab-v%d" % PROTOCOL

static func join_reference(config: Dictionary, lobby: String) -> String:
	return JSON.stringify({"v":PROTOCOL,"deployment":config.deployment_id,"lobby":lobby})

static func parse_reference(config: Dictionary, text: String) -> String:
	if text.length() > 1024: return ""
	var parser := JSON.new()
	if parser.parse(text) != OK: return ""
	var value = parser.data
	if not value is Dictionary or value.get("v") != PROTOCOL or value.get("deployment") != config.get("deployment_id"): return ""
	var lobby = value.get("lobby")
	if not lobby is String or lobby.is_empty() or lobby.length() > 128: return ""
	for c in lobby:
		if not c in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_": return ""
	return lobby
