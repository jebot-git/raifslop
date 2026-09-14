## Adapted from jebot-git/FPSloppa, commit 5105fb8cfa38c76aa1d5d172af3047fe2d12ae0d.
extends RefCounted
const DEFAULT_MODE := 2 # Voice activation; saved player choices take precedence.
static func read_settings(path: String="") -> Dictionary:
	var cfg:=ConfigFile.new();cfg.load("user://voice.cfg" if path.is_empty() else path)
	var mode=cfg.get_value("voice","mode",DEFAULT_MODE)
	var mute=cfg.get_value("voice","mute_all",false)
	var input=cfg.get_value("voice","input_device","Default")
	var threshold=cfg.get_value("voice","threshold",.018)
	return {"mode":clampi(int(mode),0,2) if (mode is int or mode is float) and is_finite(mode) else DEFAULT_MODE,
		"mute_all":mute if mute is bool else false,
		"input_device":input if input is String else "Default",
		"threshold":clampf(float(threshold),.001,.5) if (threshold is float or threshold is int) and is_finite(threshold) else .018}
static func save_settings(values: Dictionary,path: String="") -> Error:
	if path.is_empty():path="user://voice.cfg"
	var cfg:=ConfigFile.new();var error:=cfg.load(path)
	if error!=OK and error!=ERR_FILE_NOT_FOUND:return error
	for key in ["mode","mute_all","input_device","threshold"]:cfg.set_value("voice",key,values[key])
	return cfg.save(path)
