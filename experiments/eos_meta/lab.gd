extends Control
var flow := preload("res://workflow.gd").new()
var backend := preload("res://eos_backend.gd").new()
var meta := preload("res://meta_provider.gd").new()
var status_label := Label.new()
var reference := LineEdit.new()
var metrics := Label.new()
var buttons: Dictionary = {}
var config: Dictionary

func _ready() -> void:
	get_tree().auto_accept_quit = false
	add_child(backend); add_child(meta); add_child(flow)
	flow.setup(backend, meta)
	var path := "res://private/eos.cfg"
	var args := OS.get_cmdline_user_args()
	var index := args.find("--config")
	if index >= 0 and index + 1 < args.size(): path = args[index + 1]
	config = preload("res://config.gd").read(path)
	var column := VBoxContainer.new(); column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 28; column.offset_top = 24; column.offset_right = -28; column.offset_bottom = -24
	column.add_theme_constant_override("separation", 18); add_child(column)
	var title := Label.new(); title.text = "UBS · EOS + Meta integration lab"; title.add_theme_font_size_override("font_size", 28); column.add_child(title)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; column.add_child(status_label)
	var row := HBoxContainer.new(); column.add_child(row)
	_button(row, "Connect", func(): flow.connect_services(config))
	_button(row, "Host lab lobby", flow.host)
	_button(row, "Leave", flow.leave)
	_button(row, "Meta invites", flow.invite)
	reference.placeholder_text = "Paste a join reference from the host"; column.add_child(reference)
	var join_row := HBoxContainer.new(); column.add_child(join_row)
	_button(join_row, "Join reference", func(): flow.join_reference(reference.text))
	_button(join_row, "Copy current reference", func():
		if not flow.lobby.is_empty(): DisplayServer.clipboard_set(preload("res://config.gd").join_reference(config, flow.lobby)))
	_button(join_row, "Accept pending invite", func(): flow.join_reference(flow.pending_reference))
	metrics.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; column.add_child(metrics)
	var note := Label.new(); note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.text = "Experimental public test lobbies. This scene checks identity, membership, invites and tiny P2P probes.\nGameplay, avatars and voice remain on the existing ENet transport.\nUse a separate desktop user-data directory for each test identity.\nOn Quest, use Meta identity and a configured, entitled test app."
	column.add_child(note)
	flow.changed.connect(_refresh); _refresh()
	if "--preflight" in args:
		var error: String = preload("res://config.gd").validate(config)
		print("EOS_META_PREFLIGHT sdk=", Engine.has_singleton("IEOS"), " config=", "ready" if error.is_empty() else error)
		get_tree().quit(0 if error.is_empty() and Engine.has_singleton("IEOS") else 2)

func _button(parent: Node, text: String, action: Callable) -> void:
	var button := Button.new(); button.text = text; button.custom_minimum_size.y = 48
	parent.add_child(button); button.pressed.connect(action); buttons[text] = button

func _refresh() -> void:
	status_label.text = flow.status
	for button in buttons.values(): button.disabled = flow.busy
	buttons["Connect"].disabled = flow.busy or flow.state != "offline"
	for title in ["Host lab lobby", "Join reference"]: buttons[title].disabled = flow.busy or flow.state != "ready"
	buttons["Leave"].disabled = flow.busy or flow.state != "lobby"
	buttons["Meta invites"].disabled = flow.busy or not flow.presence_ready or config.get("provider") != "meta"
	buttons["Copy current reference"].disabled = flow.lobby.is_empty()
	buttons["Accept pending invite"].disabled = flow.busy or flow.state != "ready" or flow.pending_reference.is_empty()

func _process(_delta: float) -> void:
	metrics.text = "P2P replies: %d · RTT: %.1f ms · Members: %d · Network type: %s\nRejected packets/requests: %d" % [backend.received, backend.last_rtt_ms, backend.members.size(), backend.transport, backend.rejected]

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if flow.busy: return
		if flow.state == "lobby": await flow.leave()
		get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_PAUSED and backend.initialized:
		backend.sdk.platform_interface_set_application_status(2)
	elif what == NOTIFICATION_APPLICATION_RESUMED and backend.initialized:
		backend.sdk.platform_interface_set_application_status(3)
