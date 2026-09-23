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
	client.get_tree().quit(1)
	return false
