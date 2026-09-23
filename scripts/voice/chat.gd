## Adapted from jebot-git/FPSloppa, commit 5105fb8cfa38c76aa1d5d172af3047fe2d12ae0d.
extends Node
const Visemes=preload("res://scripts/voice/visemes.gd")
const Preferences=preload("res://scripts/voice/preferences.gd")
var input_device:="Default"
const Permissions=preload("res://scripts/voice/permissions.gd")
var game
var mode:=Preferences.DEFAULT_MODE # 0 listen only, 1 push-to-talk, 2 voice activation.
var muted_all:=false
var muted: Dictionary={}
var volume:=0.8
var threshold:=0.018
var meter:=0.0
var transmitting:=false
var message:="Voice activation"
var mic: Node
var sequence:=0
var hangover:=0.0
var streams: Dictionary={}
var mouth_poses: Dictionary={}
var guard: Dictionary={}
var received_packets:=0
var decoded_packets:=0
var diagnostic_counts:Dictionary={"normal":0,"fec_attempt":0,"duplicate_drop":0,"late_drop":0,"filtered_drop":0,"reordered":0,"empty_playback_queue":0}
func diagnostics() -> Dictionary:
	return diagnostic_counts.duplicate()
func count_event(kind:String) -> void:
	diagnostic_counts[kind]=diagnostic_counts.get(kind,0)+1
var relayed_packets:=0
var rejected_packets:=0
var permission_wait:=false
var panel: Control
var test_receive:=false
var radio_active:=false
var radio_audio: Node
var channel_serial: Dictionary={}

func setup(arena: Node) -> void:
	game=arena
	load_preferences()
	if not game.headless:
		apply_input_device()
		radio_audio=load("res://scripts/voice/radio_audio.gd").new();add_child(radio_audio);radio_audio.setup()
	multiplayer.peer_disconnected.connect(remove_peer)
	game.permissions.completed.connect(_permission_result)
	if not game.headless: set_mode.call_deferred(mode)

func _permission_result(permission: String,allowed: bool) -> void:
	if permission!=Permissions.MICROPHONE: return
	permission_wait=false
	if mode==0 or not game.voice_enabled: return
	if allowed: start_capture()
	else: message="Microphone access denied · listening only. Use RETRY ACCESS or headset app permissions."

func load_preferences(path: String="") -> void:
	var saved:=Preferences.read_settings(path)
	mode=saved.mode;muted_all=saved.mute_all;threshold=saved.threshold;input_device=saved.input_device

func save_preferences(path: String="") -> void:
	var error:=Preferences.save_settings({"mode":mode,"mute_all":muted_all,"threshold":threshold,"input_device":input_device},path)
	if error!=OK:push_warning("Cannot save voice settings: "+error_string(error))

func apply_input_device() -> void:
	var available:=AudioServer.get_input_device_list()
	AudioServer.input_device=input_device if input_device in available else "Default"

func select_input_device(value: String) -> void:
	input_device=value;apply_input_device();save_preferences();set_mode(mode)

func set_mode(value: int,persist: bool=false) -> void:
	mode=clampi(value,0,2)
	if persist:save_preferences()
	stop_capture()
	if mode==0: message="Microphone off"; return
	if game.headless or not game.active: return
	if not game.voice_enabled: message="Voice disabled by host"; return
	if not game.permissions.granted(Permissions.MICROPHONE):
		permission_wait=true
		message="Allow microphone access to speak"
		game.permissions.request(Permissions.MICROPHONE)
		return
	start_capture()

func retry_access() -> void:
	if mode>0 and not game.headless:
		game.permissions.request(Permissions.MICROPHONE,true)

func start_capture() -> void:
	if mic or mode==0 or not game.active or game.headless or not game.voice_enabled or not game.permissions.granted(Permissions.MICROPHONE): return
	mic=load("res://scripts/voice/microphone.gd").new();add_child(mic)
	if not mic.configure(self):
		mic.queue_free();mic=null;message="Microphone unavailable · select an input device and retry";return
	mic.transmit_audio_packet.connect(send_packet)
	message="TwoVoIP · hold T / left stick click" if mode==1 else "TwoVoIP · voice activation enabled"

func stop_capture() -> void:
	permission_wait=false;transmitting=false;meter=0;hangover=0;set_radio(false)
	if is_instance_valid(mic):
		mic.set_process(false);remove_child(mic);mic.queue_free();mic=null

func can_transmit() -> bool:
	# Fishing's tracking flag can stay false while the menu, Guide or holster
	# bypasses rod updates. Like FPSloppa, voice follows XR focus independently
	# of controller tracking and resumes as soon as focus returns.
	return game.active and not game.dedicated and game.voice_enabled and game.players.has(multiplayer.get_unique_id()) and game.root_game.tracking_manager.focused

func push_to_talk() -> bool:
	if radio_channel():return true
	if radio_held():return false
	return game.root_game.left.get_has_tracking_data() and game.root_game.left.is_button_pressed("primary_click")

func radio_held() -> bool:
	return is_instance_valid(game.root_game.get("shoulder_radio")) and game.root_game.shoulder_radio.held

func set_radio(value: bool) -> void:
	value=value and mode>0 and can_transmit()
	if value==radio_active:return
	radio_active=value
	if is_instance_valid(radio_audio):radio_audio.cue(value,volume if not muted_all else 0.0)

func radio_channel() -> bool:
	return radio_active and mode>0 and can_transmit()

func wants_transmit() -> bool:
	return mode>0 and can_transmit() and (radio_channel() or not radio_held() and (push_to_talk() if mode==1 else hangover>0))

func _process(delta: float) -> void:
	if radio_active and not can_transmit():set_radio(false)
	for id in streams.keys():
		var state: Dictionary=streams[id]
		if not game.players.has(id) or not state.radio and not game.same_location(multiplayer.get_unique_id(),id) or game.clock-state.last_time>2:remove_stream(id);continue
		var speaker=state.speaker
		if game.clock-state.last_time>.16 and speaker.inopusstream:speaker.external_end_stream()
		if game.fighters.has(id) and state.player is AudioStreamPlayer3D:state.player.global_position=game.fighters[id].head.global_position
		state.player.volume_db=linear_to_db(maxf(.0001,volume)) if not muted_all and not muted.has(id) else -80.0
		if speaker.audio_stream_playback_opus:
			var empty:bool=speaker.inopusstream and not speaker.playbackpausedonmark and speaker.audio_stream_playback_opus.queue_length_frames()==0
			if empty and not state.get("empty_queue",false):count_event("empty_playback_queue")
			state.empty_queue=empty
			var peak: float=speaker.audio_stream_playback_opus.get_chunk_max()
			if peak>.001:decoded_peak=maxf(decoded_peak,peak)
			var audible: bool=speaker.inopusstream or speaker.audio_stream_playback_opus.queue_length_frames()>0
			var opening: float=clampf(sqrt(maxf(0,peak-.004))*2.6,0,.9) if audible else 0.0
			# Avatar visemes arrive in the validated pose stream; audio drives playback only.

	if panel:panel.refresh(delta)

var decoded_peak:=0.0
signal packet_received(id: int,serial: int,data: PackedByteArray)
static func valid_packet(data: PackedByteArray) -> bool:
	# Fixed 48 kHz mono, 20 ms Opus frames. The prefix is replaced by the relay sequence.
	return data.size()>=3 and data.size()<=400 and (data[2]>>3) in [1,5,9,13,15,19,23,27,31] and (data[2]&7)==0

func send_packet(data: PackedByteArray) -> void:
	sequence+=1
	if multiplayer.is_server():relay(multiplayer.get_unique_id(),sequence,data,radio_channel())
	else:submit.rpc_id(1,sequence,data,radio_channel())

@rpc("any_peer","call_remote","unreliable",6)
func submit(serial: int,data: PackedByteArray,radio: bool=false) -> void:
	if multiplayer.is_server():relay(multiplayer.get_remote_sender_id(),serial,data,radio)

func accept_sender(id: int,serial: int,data: PackedByteArray) -> bool:
	if not game.active or not game.voice_enabled or not game.players.has(id) or id<1 or not valid_packet(data) or serial<0 or serial>2147483647:
		rejected_packets+=1;return false
	var state: Dictionary=guard.get(id,{"last":-1,"seen":{},"tokens":12.0,"time":game.clock})
	state.tokens=minf(12,state.tokens+maxf(0,game.clock-state.time)*55);state.time=game.clock;guard[id]=state
	if serial<state.last-32 or state.seen.has(serial) or state.tokens<1:
		rejected_packets+=1;return false
	state.last=maxi(state.last,serial);state.seen[serial]=true;state.tokens-=1
	for old in state.seen.keys():
		if old<state.last-32:state.seen.erase(old)
	return true

func recipients(id: int,radio: bool) -> Array:
	var result: Array=[]
	if not game.active or not game.voice_enabled or not game.players.has(id):return result
	for peer in game.players:
		if peer!=id and (radio or game.same_location(peer,id)):result.append(peer)
	return result

func relay(id: int,serial: int,data: PackedByteArray,radio: bool=false) -> void:
	if not accept_sender(id,serial,data):return
	for peer in recipients(id,radio):
		if peer>1:receive.rpc_id(peer,id,serial,data,radio)
		elif not game.dedicated:receive(id,serial,data,radio)
	relayed_packets+=1

func create_stream(id: int,serial: int,radio: bool=false) -> void:
	var player=AudioStreamPlayer.new() if game.headless or radio else AudioStreamPlayer3D.new()
	if player is AudioStreamPlayer3D:
		player.unit_size=8;player.max_distance=60;player.attenuation_filter_cutoff_hz=18000
	if radio and is_instance_valid(radio_audio):player.bus=radio_audio.bus
	add_child(player)
	var speaker=load("res://addons/twovoip/voiphelper/two_voip_speaker.gd").new();speaker.audio_buffer_lag_time_target=.08;speaker.audio_buffer_lag_time_target_tolerance=.06;player.add_child(speaker)
	speaker.packet_decoded.connect(func():decoded_packets+=1)
	speaker.decode_event.connect(count_event)
	var header:={"opussamplerate":48000,"opuschannels":1,"lenchunkprefix":2,"opusstreamcount":0,"opusframesize":960,"opusframecount":0,"talkingtimestart":0}
	speaker.receive_audio_packet(JSON.stringify(header).to_ascii_buffer())
	streams[id]={"radio":radio,"player":player,"speaker":speaker,"base":serial,"last":serial-1,"seen":{},"last_time":game.clock}

@rpc("authority","call_remote","unreliable",6)
func receive(id: int,serial: int,data: PackedByteArray,radio: bool=false) -> void:
	if not game.voice_enabled or not game.players.has(id) or id==multiplayer.get_unique_id() or muted_all or muted.has(id) or not valid_packet(data):count_event("filtered_drop");return
	if serial<0 or serial>2147483647:count_event("filtered_drop");return
	# FPSloppa's monotonic channel history prevents delayed radio frames from
	# switching playback back after a newer local-voice packet (and vice versa).
	var channel: Dictionary=channel_serial.get(id,{"serial":-1,"radio":radio})
	if serial<=channel.serial and radio!=channel.radio:count_event("late_drop");return
	if serial>channel.serial:channel_serial[id]={"serial":serial,"radio":radio}
	if streams.has(id) and streams[id].radio!=radio:remove_stream(id)
	if not radio and not game.same_location(multiplayer.get_unique_id(),id):count_event("filtered_drop");return
	if game.headless and not test_receive:count_event("filtered_drop");return
	if streams.has(id):
		var old: Dictionary=streams[id]
		if old.seen.has(serial):count_event("duplicate_drop");return
		if serial<old.base or serial<old.last-32:count_event("late_drop");return
		if serial<old.last:count_event("reordered")
		if serial>old.last+50 or serial-old.base>=32000 or game.clock-old.last_time>.16:remove_stream(id)
	if not streams.has(id):
		create_stream(id,serial,radio)
		if radio and is_instance_valid(radio_audio):radio_audio.cue(true,volume)
	var state: Dictionary=streams[id]
	state.last=maxi(state.last,serial);state.last_time=game.clock;state.seen[serial]=true
	for old in state.seen.keys():
		if old<state.last-32:state.seen.erase(old)
	var frame: int=serial-state.base
	var packet:=data.duplicate();packet[0]=frame&255;packet[1]=(frame>>8)&127
	state.speaker.receive_audio_packet(packet)
	received_packets+=1;packet_received.emit(id,serial,data)

func set_muted(id: int,value: bool) -> void:
	if value: muted[id]=true; remove_stream(id)
	else: muted.erase(id)

func remove_stream(id: int) -> void:
	if streams.has(id):
		if is_instance_valid(streams[id].player):
			var state: Dictionary=streams[id]
			state.speaker.set_process(false)
			state.player.stop()
			state.speaker.audio_stream_playback_opus=null
			state.player.stream=null
			state.speaker.audiostreamopus=null
			state.player.queue_free()
		streams.erase(id);mouth_poses.erase(id)

func remove_peer(id: int) -> void:
	remove_stream(id); guard.erase(id); muted.erase(id);channel_serial.erase(id)

func reset() -> void:
	for id in streams.keys(): remove_stream(id)
	guard.clear(); muted.clear();mouth_poses.clear();channel_serial.clear(); sequence=0;set_radio(false)
	game.voice_enabled=true
	set_mode(mode)

func _exit_tree() -> void:
	stop_capture()

func animate_mouth(id: int,samples: PackedVector2Array) -> void:
	set_mouth_pose(id,Visemes.analyze(samples))
func set_mouth_pose(id: int,weights: PackedFloat32Array) -> void:
	mouth_poses[id]={"weights":weights,"until":game.clock+.14}
	if not game.dedicated and id==multiplayer.get_unique_id() and is_instance_valid(game.root_game.avatar):
		if not game.root_game.avatar.face.has("mouth"): game.root_game.avatar.mouth.speak(weights)
func mouth_pose(id: int) -> PackedFloat32Array:
	var state: Dictionary=mouth_poses.get(id,{})
	return state.weights if state.get("until",0)>game.clock else PackedFloat32Array([0,0,0,0,0])
