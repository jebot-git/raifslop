extends SceneTree
## Opt-in real EOS check. Desktop device identity only; never launches XR.
const Config = preload("res://config.gd")
var backend := preload("res://eos_backend.gd").new()
var meta := preload("res://meta_provider.gd").new()
var flow := preload("res://workflow.gd").new()
var settings: Dictionary = {}
var role := ""
var handoff := ""
var result_path := ""
var config_path := "res://private/eos.cfg"
var samples: Array = []
var started := 0
var finished := false

func _initialize() -> void: _run.call_deferred()

func argument(key: String, fallback: String = "") -> String:
	var args := OS.get_cmdline_user_args()
	var index := args.find(key)
	return args[index + 1] if index >= 0 and index + 1 < args.size() else fallback

func _run() -> void:
	role = argument("--role")
	handoff = argument("--handoff")
	result_path = argument("--result")
	config_path = argument("--config", config_path)
	if OS.get_name() == "Android" or role not in ["host", "client"] or handoff.is_empty() or result_path.is_empty():
		print("EOS_LIVE invalid desktop probe arguments"); quit(2); return
	root.add_child(backend); root.add_child(meta); root.add_child(flow)
	flow.setup(backend, meta)
	backend.probe_received.connect(func(ms: float): samples.append(ms))
	settings = Config.read(config_path)
	# Override only this process, preserving the configured Meta production identity.
	settings["provider"] = "device"
	settings["relay"] = argument("--relay", "auto")
	started = Time.get_ticks_msec()
	await flow.connect_services(settings)
	if flow.state != "ready": await finish(false, "authentication", flow.status); return
	if role == "host":
		await flow.host()
		if flow.state != "lobby": await finish(false, "host", flow.status); return
		write_json(handoff, {"reference":Config.join_reference(settings, flow.lobby)})
		while Time.get_ticks_msec() - started < 90000:
			await process_frame
			if FileAccess.file_exists(handoff + ".done"):
				await finish(true, "complete", "Host served the client probe."); return
			if flow.state != "lobby": await finish(false, "host_lost", flow.status); return
		await finish(false, "timeout", "Client did not complete.")
	else:
		var data = JSON.parse_string(FileAccess.get_file_as_string(handoff))
		if not data is Dictionary or not data.get("reference") is String:
			await finish(false, "reference", "Invalid handoff."); return
		await flow.join_reference(data.reference)
		if flow.state != "lobby": await finish(false, "join", flow.status); return
		while samples.size() < 10 and Time.get_ticks_msec() - started < 60000:
			await process_frame
			if flow.state != "lobby": await finish(false, "connection_lost", flow.status); return
		await finish(samples.size() >= 10, "probes", "Client probe completed.")

func write_json(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(value))

func finish(ok: bool, stage: String, message: String) -> void:
	if finished: return
	finished = true
	var diagnostics := backend.diagnostics()
	var expected_transport := ["2"] if settings.get("relay") == "force" else ["1", "2"]
	if ok and diagnostics.get("network_type") not in expected_transport:
		ok = false
		stage = "transport"
		message = "EOS did not report the requested connection type."
	var cleanup := await backend.leave_lobby()
	var sorted := samples.duplicate(); sorted.sort()
	var report := {"ok":ok and cleanup,"stage":stage,"message":message,"cleanup":cleanup,
		"role":role,"relay":settings.get("relay", ""),"samples_ms":samples,
		"rtt_median_ms":(sorted[(sorted.size() - 1) / 2] + sorted[sorted.size() / 2]) / 2.0 if not sorted.is_empty() else -1,
		"elapsed_ms":Time.get_ticks_msec() - started,"diagnostics":diagnostics}
	write_json(result_path, report)
	if role == "client": write_json(handoff + ".done", {"ok":report.ok})
	print("EOS_LIVE_RESULT role=%s ok=%s stage=%s samples=%d cleanup=%s" % [role, report.ok, stage, samples.size(), cleanup])
	quit(0 if report.ok else 1)
