extends RefCounted
## Clients require OpenXR. Dedicated servers bypass client construction entirely.
static func require_session(client:Node)->bool:
	var interface:=XRServer.find_interface("OpenXR")
	if interface!=null and interface.is_initialized():return true
	# Explicit development fixture: test scripts can supply synthetic XR poses.
	# This never supplies a desktop camera or keyboard/mouse gameplay controls.
	if OS.has_feature("debug") and "--script" in OS.get_cmdline_args() and "--xr-test" in OS.get_cmdline_user_args():return true
	client.process_mode=Node.PROCESS_MODE_DISABLED
	push_error("VR_REQUIRED: OpenXR did not initialize. Start your OpenXR runtime, connect the headset, and restart. This game requires VR.")
	# Release builds launched from Steam otherwise disappear with only a log.
	if OS.has_feature("pc") and DisplayServer.get_name()!="headless":
		OS.alert("A VR headset and an active OpenXR runtime are required.\n\nConnect your headset, start its VR software, and select it as the active OpenXR runtime. Then launch Ultimate Boomer Simulator again.\n\nSteamVR users: check Settings > OpenXR. Meta Link and Virtual Desktop users: check the runtime setting in your VR software.", "Ultimate Boomer Simulator — VR setup required")
	client.get_tree().quit(1)
	return false
