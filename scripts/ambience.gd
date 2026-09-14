extends Node
## Location beds crossfade; occasional timber sounds remain fixed in the world.
const LOCATIONS=preload("res://scripts/locations.gd")
var root_game: Node
var location := ""
var volume := .65
var muted := false
var voices: Dictionary={}
var detail := AudioStreamPlayer3D.new()
var detail_wait := 9.0
var rng := RandomNumberGenerator.new()
func setup(root: Node) -> void:
	root_game=root; rng.randomize()
	var cfg:=ConfigFile.new();cfg.load("user://sound.cfg")
	var saved=cfg.get_value("ambience","volume",.65)
	volume=clampf(float(saved),0,1) if (saved is int or saved is float) and is_finite(saved) else .65
	muted=bool(cfg.get_value("ambience","muted",false))
	add_child(detail);detail.max_distance=18;detail.unit_size=2
	detail.stream=load("res://assets/audio/ambience/timber.ogg")
	select_location(root.current_location)
func select_location(id: String) -> void:
	if LOCATIONS.find_location(id).is_empty() or location==id:return
	location=id;detail.stop();detail_wait=rng.randf_range(7,14)
	detail.global_position=root_game.motor.safe_spawn+Vector3(-2,.15,-2)
	if not voices.has(id):
		var player:=AudioStreamPlayer.new();add_child(player)
		voices[id]={"player":player,"gain":0.0}
	var current: Dictionary=voices[id]
	if not current.player.stream:
		current.player.stream=load("res://assets/audio/ambience/"+id+".ogg").duplicate()
		current.player.stream.loop=true
	if not current.player.playing:
		current.player.volume_db=-80
		current.player.play(rng.randf_range(0,30))
func _process(delta: float) -> void:
	for id in voices:
		var entry: Dictionary=voices[id]
		entry.gain=move_toward(entry.gain,1.0 if id==location else 0.0,delta*.5)
		entry.player.volume_db=linear_to_db(maxf(.0001,entry.gain*volume)) if not muted else -80
		if entry.gain==0 and id!=location:
			entry.player.stop();entry.player.stream=null
	detail.volume_db=linear_to_db(maxf(.0001,volume)) - 15 if not muted else -80
	detail_wait-=delta
	if detail_wait<=0:
		detail_wait=rng.randf_range(16,33)
		if location in ["lake_pier","bell_park_pier"] and not muted and volume>0:
			detail.pitch_scale=rng.randf_range(.78,1.12) if location=="bell_park_pier" else rng.randf_range(.85,1.2)
			detail.play()
func set_volume(value: float) -> void:
	volume=clampf(value,0,1);save()
func set_muted(value: bool) -> void:
	muted=value;save()
func save() -> void:
	var cfg:=ConfigFile.new();cfg.set_value("ambience","volume",volume);cfg.set_value("ambience","muted",muted)
	var error:=cfg.save("user://sound.cfg")
	if error!=OK:push_warning("Cannot save sound settings: "+error_string(error))

func stop() -> void:
	set_process(false)
	for entry in voices.values():
		entry.player.stop();entry.player.stream=null
	voices.clear();detail.stop();detail.stream=null

func _exit_tree() -> void:
	stop()
