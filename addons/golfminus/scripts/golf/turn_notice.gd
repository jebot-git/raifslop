extends Node
var host:Node3D
var spatial:Label3D
var sound:AudioStreamPlayer
var remaining:=0.0
func setup(root:Node3D)->void:
	host=root
	spatial=Label3D.new();spatial.font_size=40;spatial.pixel_size=.0007;spatial.position=Vector3(0,.22,-.85);spatial.no_depth_test=true;host.head.add_child(spatial);spatial.hide()
	sound=AudioStreamPlayer.new();sound.volume_db=-12;add_child(sound)
	var wav:=AudioStreamWAV.new();wav.format=AudioStreamWAV.FORMAT_16_BITS;wav.mix_rate=22050
	var pcm:=PackedByteArray();pcm.resize(13230*2)
	for i in 13230:
		var t:=i/22050.0;var envelope:=sin(PI*fmod(t,.3)/.3)
		pcm.encode_s16(i*2,int(sin(TAU*(660 if t<.3 else 880)*t)*envelope*16000))
	wav.data=pcm;sound.stream=wav
func set_context(hole:int,away:bool)->void:
	var message:="Your turn · Hole %02d\n%s"%[hole+1,"Return to golf within 5 minutes" if away else "Club ready"]
	spatial.text=message
func show_turn(hole:int,away:bool)->void:
	set_context(hole,away);remaining=10;sound.play()
func _process(dt:float)->void:
	remaining=maxf(0,remaining-dt)
	if is_instance_valid(spatial):spatial.visible=remaining>0
func _exit_tree()->void:
	if is_instance_valid(spatial):spatial.queue_free()
