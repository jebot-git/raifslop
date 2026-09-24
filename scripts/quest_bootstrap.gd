extends Node3D

const LOADING_LOGO = preload("res://assets/ui/store_logo.png")
const LOADING_BACKGROUND = Color(0.063, 0.122, 0.133, 1)
const Entitlement = preload("res://scripts/quest_entitlement.gd")
const Expansion = preload("res://scripts/quest_expansion.gd")
var worker := Thread.new()
var record: Dictionary = {}
var expansion_path := ""
var label: Label3D
var status: Label

func _ready() -> void:
	if not FileAccess.file_exists("res://quest_expansion.json") and not FileAccess.file_exists("res://quest_store.json"):
		_start_game.call_deferred()
		return
	_show_loading()
	_message("Checking store access…\nPlease wait.")
	var config = JSON.parse_string(FileAccess.get_file_as_string("res://quest_store.json")) if FileAccess.file_exists("res://quest_store.json") else null
	if not config is Dictionary or config.get("entitlement_required") != true or not config.get("app_id") is String:
		_access_failed("This store build is not configured correctly.")
		return
	var gate := Entitlement.new()
	add_child(gate)
	gate.completed.connect(_entitlement_completed)
	var sdk: Object = Engine.get_singleton("MetaPlatformSDK") if Engine.has_singleton("MetaPlatformSDK") else null
	gate.start(config.app_id, sdk)

func _entitlement_completed(allowed: bool, reason: String) -> void:
	if not allowed:
		_access_failed(reason)
		return
	_message("Checking game download…\nPlease wait.")
	_check_expansion()

func _access_failed(reason: String) -> void:
	push_error("Quest entitlement: access denied")
	_message(reason + "\nClose the game using the system menu.")

func _check_expansion() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://quest_expansion.json"))
	if not parsed is Dictionary:
		_fail("Invalid game download information.")
		return
	record = parsed
	var error := Expansion.metadata_error(record)
	if not error.is_empty():
		_fail(error)
		return
	if not Engine.has_singleton("AndroidRuntime"):
		_fail("Cannot access the game download folder.")
		return
	var context = Engine.get_singleton("AndroidRuntime").getApplicationContext()
	if context == null or str(context.getPackageName()) != str(record.package):
		_fail("The game download belongs to another app.")
		return
	var package_info = context.getPackageManager().getPackageInfo(str(record.package), 0)
	if package_info == null or int(package_info.getLongVersionCode()) != int(record.version_code):
		_fail("The game download belongs to another version.")
		return
	var folder = context.getObbDir()
	if folder == null:
		_fail("Cannot access the game download folder.")
		return
	expansion_path = str(folder.getAbsolutePath()).path_join(str(record.file))
	if worker.start(Expansion.verify_file.bind(expansion_path, record)) != OK:
		_fail("Cannot verify the game download.")

func _show_loading() -> void:
	var xr := XRServer.find_interface("OpenXR")
	if xr and (xr.is_initialized() or xr.initialize()):
		get_viewport().use_xr = true
	var origin := XROrigin3D.new()
	add_child(origin)
	var camera := XRCamera3D.new()
	origin.add_child(camera)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = LOADING_BACKGROUND
	add_child(environment)
	var logo := Sprite3D.new()
	logo.name = "LoadingLogoVR"
	logo.texture = LOADING_LOGO
	logo.pixel_size = 0.00075
	logo.position = Vector3(0, 0.16, -1.5)
	logo.no_depth_test = true
	camera.add_child(logo)
	label = Label3D.new()
	label.position = Vector3(0, -0.25, -1.5)
	label.font_size = 36
	label.pixel_size = 0.001
	label.no_depth_test = true
	camera.add_child(label)
	# Canvas UI is for the flat display only; the headset uses stereo geometry.
	if not get_viewport().use_xr:
		var canvas := CanvasLayer.new()
		add_child(canvas)
		var panel := Control.new()
		panel.name = "LoadingScreen"
		canvas.add_child(panel)
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var background := ColorRect.new()
		background.color = LOADING_BACKGROUND
		panel.add_child(background)
		background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var image := TextureRect.new()
		image.name = "LoadingLogo"
		image.texture = LOADING_LOGO
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		panel.add_child(image)
		image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		image.set_anchor_and_offset(SIDE_LEFT, 0.08, 0);image.set_anchor_and_offset(SIDE_RIGHT, 0.92, 0)
		image.set_anchor_and_offset(SIDE_TOP, 0.15, 0);image.set_anchor_and_offset(SIDE_BOTTOM, 0.66, 0)
		status = Label.new()
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		status.add_theme_font_size_override("font_size", 24)
		status.add_theme_color_override("font_color", Color("f3ecd6"))
		panel.add_child(status)
		status.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		status.set_anchor_and_offset(SIDE_LEFT, 0.12, 0);status.set_anchor_and_offset(SIDE_RIGHT, 0.88, 0)
		status.set_anchor_and_offset(SIDE_TOP, 0.69, 0);status.set_anchor_and_offset(SIDE_BOTTOM, 0.98, 0)
	_message("Checking game download…\nPlease wait.")

func _message(text: String) -> void:
	label.text = text
	if is_instance_valid(status):status.text = text

func _process(_delta: float) -> void:
	if worker.is_started() and not worker.is_alive():
		var error: String = worker.wait_to_finish()
		if not error.is_empty():
			_fail(error)
		# Android's sparse APK index still lists textures moved into the OBB.
		# The verified expansion must replace those entries with its real payloads.
		elif not ProjectSettings.load_resource_pack(expansion_path, true):
			_fail("Cannot open the game download.")
		else:
			_start_game()

func _fail(reason: String) -> void:
	push_error("Quest expansion: " + reason)
	_message(reason + "\nClose the game and finish its download\nin your library, then launch it again.\nIf this persists, reinstall the game.")

func _start_game() -> void:
	# A string path prevents scene/script preloads from reaching moved textures early.
	if get_tree().change_scene_to_file("res://scenes/main.tscn") != OK:
		if label == null: _show_loading()
		_fail("Cannot start the game.")

func _exit_tree() -> void:
	if worker.is_started(): worker.wait_to_finish()
