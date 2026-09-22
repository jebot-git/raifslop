extends Node
var host:Node3D
var panel:PanelContainer
var label:Label
var spatial:Label3D
var sound:AudioStreamPlayer
var remaining:=0.0
func setup(root:Node3D)->void:
	host=root
	var layer:=CanvasLayer.new();layer.layer=120;add_child(layer)
	panel=PanelContainer.new();layer.add_child(panel);panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP);panel.offset_left=-260;panel.offset_right=260;panel.offset_top=12;panel.offset_bottom=90;panel.custom_minimum_size=Vector2(520,78)
	panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var style:=StyleBoxFlat.new();style.bg_color=Color("112b28");style.set_corner_radius_all(12);style.content_margin_left=20;style.content_margin_right=20;style.content_margin_top=8;style.content_margin_bottom=8;panel.add_theme_stylebox_override("panel",style)
	label=Label.new();panel.add_child(label);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.add_theme_font_size_override("font_size",25);panel.hide()
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
	label.text=message;spatial.text=message
func show_turn(hole:int,away:bool)->void:
	set_context(hole,away);remaining=10;sound.play()
func _process(dt:float)->void:
	remaining=maxf(0,remaining-dt)
	if is_instance_valid(panel):panel.visible=remaining>0 and not host.xr
	if is_instance_valid(spatial):spatial.visible=remaining>0 and host.xr
func _exit_tree()->void:
	if is_instance_valid(spatial):spatial.queue_free()
