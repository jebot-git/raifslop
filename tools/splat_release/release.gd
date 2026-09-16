extends "res://locations.gd"

var preferences := ConfigFile.new()
var test_run := false

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	test_run = "--benchmark" in args or "--validate" in args or "--release-smoke" in args
	preferences.load("user://viewer.cfg")
	chosen = str(preferences.get_value("viewer","location","lake_pier"))
	if chosen not in ["lake_pier","simons_town_rocks"]:chosen="lake_pier"
	xr = OS.has_feature("standalone_xr") or "--xr" in args
	super._ready()
	if not is_instance_valid(splat):return
	if not test_run:
		splat.visible = bool(preferences.get_value("viewer","splats",true))
		lighting_original = bool(preferences.get_value("viewer","original_lighting",false))
		if location_id=="simons_town_rocks":_set_lighting(lighting_original)
	print("SPLAT_RELEASE_READY version=",ProjectSettings.get_setting("application/config/version")," user_dir=",OS.get_user_data_dir())
	if "--release-smoke" in args:call_deferred("_release_smoke")

func _save_preferences(force := false) -> void:
	if (test_run and not force) or not is_instance_valid(splat):return
	preferences.set_value("viewer","location",get_tree().get_meta("location_override",location_id))
	preferences.set_value("viewer","splats",splat.visible)
	preferences.set_value("viewer","original_lighting",lighting_original)
	var error := preferences.save("user://viewer.cfg")
	if error!=OK:push_warning("Viewer settings could not be saved: "+error_string(error))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode==KEY_ESCAPE:
		_save_preferences()
		get_tree().quit()
		return
	super._unhandled_input(event)
	if event is InputEventKey and event.pressed:_save_preferences()

func _exit_tree() -> void:
	_save_preferences()

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_PAUSED or what==NOTIFICATION_WM_CLOSE_REQUEST:_save_preferences()

func _release_smoke() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	var checks := _check_collisions()
	_save_preferences(true)
	var saved_preferences := ConfigFile.new()
	var preferences_ok: bool = saved_preferences.load("user://viewer.cfg")==OK and saved_preferences.get_value("viewer","location","")==location_id
	var save := ConfigFile.new()
	save.set_value("test","location",location_id)
	var saved := save.save("user://release-smoke.cfg")
	var readback := ConfigFile.new()
	var loaded := readback.load("user://release-smoke.cfg")
	var isolated: bool = ProjectSettings.get_setting("application/config/use_custom_user_dir",false) and ProjectSettings.get_setting("application/config/custom_user_dir_name","")=="RealAIFishing-SplatTesting"
	var passed: bool = preferences_ok and isolated and saved==OK and loaded==OK and readback.get_value("test","location","")==location_id and checks.side_barrier_blocks and checks.floor_hits.all(func(value):return value) and point_count>0
	var report := {"location":location_id,"points":point_count,"user_dir":OS.get_user_data_dir(),"isolated_save":isolated,"preferences_roundtrip":preferences_ok,"save_roundtrip":saved==OK and loaded==OK,"microphone_enabled":ProjectSettings.get_setting("audio/driver/enable_input",false),"checks":checks,"passed":passed}
	FileAccess.open(report_path(location_id+"_release_smoke.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	await capture(location_id+"_release_smoke")
	DirAccess.remove_absolute("user://release-smoke.cfg")
	print("SPLAT_RELEASE_SMOKE ",JSON.stringify(report))
	get_tree().quit(0 if passed else 1)
