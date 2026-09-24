extends Node
## Correlated EOS callbacks and bounded Meta requests. Never log callback payloads.
var sequence := 0
var timeout_ms := 15000
var abandoned: Dictionary = {}
signal late_lobby(lobby_id: String)

func eos(sdk: Object, method: String, signal_name: String, options: Object) -> Dictionary:
	sequence += 1
	var tag := sequence
	options.values["client_data"] = tag
	var replies: Array = []
	var receive := func(data: Dictionary):
		if data.get("client_data") == tag: replies.append(data)
	sdk.connect(signal_name, receive)
	sdk.call(method, options)
	var end := Time.get_ticks_msec() + timeout_ms
	while replies.is_empty() and Time.get_ticks_msec() < end: await get_tree().process_frame
	sdk.disconnect(signal_name, receive)
	if replies.is_empty():
		abandoned[tag] = true
		return {"result_code":27}
	return replies[0]

func observe_lobby(data: Dictionary) -> void:
	var tag = data.get("client_data")
	if abandoned.has(tag):
		abandoned.erase(tag)
		if data.get("result_code") == 0: late_lobby.emit(str(data.get("lobby_id", "")))

func meta(request: Object) -> Object:
	if request == null or not request.has_signal("completed") or int(request.get_id()) == 0: return null
	var replies: Array = []
	var receive := func(message: Object): replies.append(message)
	request.connect("completed", receive)
	var end := Time.get_ticks_msec() + timeout_ms
	while replies.is_empty() and Time.get_ticks_msec() < end: await get_tree().process_frame
	request.disconnect("completed", receive)
	if replies.is_empty() or replies[0] == null or replies[0].is_error(): return null
	return replies[0]
