extends VBoxContainer
var session: Node
var status := Label.new()
var roster := ItemList.new()
var voice_status := Label.new()
var refresh_time := 0.0
func setup(owner_session: Node, back: Callable) -> void:
	session=owner_session
	add_theme_constant_override("separation",12)
	var heading:=Label.new(); heading.text="Fish together"; heading.add_theme_font_size_override("font_size",28); add_child(heading)
	var name_input:=LineEdit.new(); name_input.placeholder_text="Your name"; name_input.text=session.display_name; name_input.max_length=32; add_child(name_input)
	name_input.text_changed.connect(func(value: String): session.display_name=value;session.save_preferences())
	var row:=HBoxContainer.new(); add_child(row)
	var address:=LineEdit.new(); address.text=session.host_address; address.max_length=253; address.placeholder_text="Host IP or hostname"; address.size_flags_horizontal=SIZE_EXPAND_FILL; row.add_child(address)
	var port:=SpinBox.new(); port.min_value=1024; port.max_value=65535; port.value=session.preferred_port; row.add_child(port)
	address.text_changed.connect(func(value: String): session.host_address=value;session.save_preferences())
	port.value_changed.connect(func(value: float): session.preferred_port=int(value);session.save_preferences())
	var actions:=HBoxContainer.new(); add_child(actions)
	button(actions,"Host",func(): session.host(int(port.value)))
	button(actions,"Join",func(): session.join(address.text,int(port.value)))
	button(actions,"Disconnect",func(): session.leave())
	status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; add_child(status)
	roster.custom_minimum_size.y=120; add_child(roster)
	roster.item_selected.connect(func(index: int):
		var id: int=roster.get_item_metadata(index)
		if id!=session.multiplayer.get_unique_id(): session.voice.set_muted(id,not session.voice.muted.has(id)))
	var voice_row:=HBoxContainer.new(); add_child(voice_row)
	var mode=preload("res://scripts/ui/choice.gd").new();voice_row.add_child(mode);mode.size_flags_horizontal=SIZE_EXPAND_FILL
	mode.configure([{"id":"0","title":"Listen only"},{"id":"1","title":"Push to talk · T / left stick"},{"id":"2","title":"Voice activation"}],"Microphone")
	mode.value=str(session.voice.mode);mode.update_label()
	mode.selected.connect(func(value: String): session.voice.set_mode(value.to_int(),true))
	var mute:=CheckButton.new(); mute.text="Mute all"; mute.button_pressed=session.voice.muted_all; voice_row.add_child(mute)
	mute.toggled.connect(func(value: bool): session.voice.muted_all=value; session.voice.save_preferences())
	var devices=preload("res://scripts/ui/choice.gd").new();add_child(devices)
	var options: Array=[]
	for device in AudioServer.get_input_device_list(): options.append({"id":device,"title":"Microphone · "+device})
	devices.configure(options,"Microphone device");devices.value=session.voice.input_device;devices.update_label()
	devices.selected.connect(session.voice.select_input_device)
	voice_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; add_child(voice_status)
	var note:=Label.new(); note.text="Voice reaches anglers at your location. Select a player to mute them.\nInternet hosting needs UDP port forwarding. Fish Guide stays on this device."
	note.add_theme_font_size_override("font_size",16); add_child(note)
	var bottom:=HBoxContainer.new(); add_child(bottom)
	button(bottom,"Retry microphone access",session.voice.retry_access)
	refresh()
func button(parent: Node,title: String,action: Callable) -> void:
	var control:=Button.new(); control.text=title; control.custom_minimum_size=Vector2(150,40); parent.add_child(control); control.pressed.connect(action)
func _process(delta: float) -> void:
	refresh_time+=delta
	if refresh_time>.5 and is_visible_in_tree(): refresh_time=0; refresh()
func refresh() -> void:
	if not session: return
	status.text=session.status
	voice_status.text=session.voice.message+(" · speaking" if session.voice.transmitting else "")
	if not session.avatars.message.is_empty(): voice_status.text+="\n"+session.avatars.message
	roster.clear()
	for id in session.players:
		var location: String=session.states.get(id,{}).get("location","joining")
		roster.add_item("%s · %s%s" % [session.players[id].name,location," · muted" if session.voice.muted.has(id) else ""])
		roster.set_item_metadata(roster.item_count-1,id)
