extends Node3D
## Bounded, positional fishing effects. Driven by actual accepted input and state.
const S=preload("res://scripts/fishing_session.gd")
var game_root: Node
var reel_rate:=0.0
var haptics=preload("res://scripts/line_haptics.gd").new()
var previous:=S.State.READY
var cue_previous:=-1
var clock:=0.0
var splash_wait:=0.0
var burst_age:=2.0
var escape:=Vector3.ZERO
var reel_player: AudioStreamPlayer3D
var cast_player: AudioStreamPlayer3D
var splashes: Array[AudioStreamPlayer3D]=[]
var splash_slot:=0
var last_splash:=0
var splash_streams: Array[AudioStreamWAV]=[]
var surface: MeshInstance3D
var water_fx: ShaderMaterial
var events: Dictionary={"cast":0,"splash":0,"land":0}
func setup(root: Node) -> void:
 game_root=root
 cast_player=player("cast");reel_player=player("reel")
 cast_player.unit_size=1.5;cast_player.volume_db=-8;cast_player.max_db=-8
 for file in ["splash","splash_2","splash_3"]:
  splash_streams.append(load("res://assets/audio/fishing/"+file+".wav"))
 reel_player.stream=reel_player.stream.duplicate()
 reel_player.stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
 reel_player.stream.loop_end=reel_player.stream.data.size()/2
 for i in range(3):splashes.append(player("splash"))
 surface=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(8,8);surface.mesh=plane
 water_fx=ShaderMaterial.new();water_fx.shader=load("res://assets/environment/fish_wake.gdshader")
 surface.material_override=water_fx;surface.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(surface);surface.hide()
func player(kind: String) -> AudioStreamPlayer3D:
 var p:=AudioStreamPlayer3D.new();p.stream=load("res://assets/audio/fishing/"+kind+".wav");p.unit_size=5;p.max_distance=65;p.volume_db=-3;add_child(p);return p
func cast_swish() -> void:
 cast_player.global_position=game_root.tip.global_position;cast_player.play();events.cast+=1
func splash(at: Vector3, landing:=false, impact:=false) -> void:
 var p:=splashes[splash_slot];splash_slot=(splash_slot+1)%splashes.size()
 if landing or impact:
  p.stream=load("res://assets/audio/fishing/land.wav" if landing else "res://assets/audio/fishing/impact.wav")
 else:
  last_splash=(last_splash+randi_range(1,splash_streams.size()-1))%splash_streams.size()
  p.stream=splash_streams[last_splash]
 p.unit_size=2.0;p.volume_db=-8.0;p.max_db=-8.0
 p.global_position=at;p.pitch_scale=1.0 if landing or impact else randf_range(.98,1.02);p.play()
 events["land" if landing else "splash"]+=1
func _process(delta: float) -> void:
 if not is_instance_valid(game_root):return
 var g=game_root.game
 var paused: bool=game_root.rod_holster.stowed or game_root.menu_open or game_root.fish_guide.held or game_root.avatar_loading or (game_root.xr and (not game_root.right.get_has_tracking_data() or not game_root.left.get_has_tracking_data() or not game_root.tracking_manager.focused))
 if paused:
  reel_player.stop();return
 var pulse:Dictionary=haptics.sample(g,delta)
 if not pulse.is_empty() and game_root.xr:
  game_root.right.trigger_haptic_pulse("haptic",0.0,pulse.strength,pulse.duration,0.0)
 clock+=delta
 reel_player.global_position=game_root.crank.global_position
 if g.state==S.State.FIGHT and reel_rate>.03:
  reel_player.pitch_scale=clampf(reel_rate,.4,2.0)
  if not reel_player.playing:reel_player.play()
 else:reel_player.stop()
 if g.state!=previous:
  if g.state in [S.State.WAITING,S.State.FIGHT]:
   splash(game_root.bobber.global_position,false,g.state==S.State.WAITING);splash_wait=1.1
  elif g.state==S.State.LANDED:
   splash(surface.global_position,true);burst_age=0
  previous=g.state
 if g.state==S.State.FIGHT:
  surface.show();surface.global_position=game_root.bobber.global_position;surface.global_position.y=-.305
  escape=game_root.fish_escape_direction()
  water_fx.set_shader_parameter("heading",Vector2(escape.x,escape.z))
  water_fx.set_shader_parameter("directional",g.cue>=0)
  water_fx.set_shader_parameter("burst",false)
  water_fx.set_shader_parameter("strength",1.0 if g.cue>=0 or g.is_running() else .4)
  water_fx.set_shader_parameter("clock",clock)
  splash_wait-=delta
  if (g.cue>=0 and g.cue!=cue_previous) or splash_wait<=0:
   splash(surface.global_position);splash_wait=randf_range(1.0,1.5) if g.is_running() or g.cue>=0 else randf_range(2.0,2.8)
 elif burst_age<1.8:
  burst_age+=delta;surface.show();water_fx.set_shader_parameter("burst",true);water_fx.set_shader_parameter("clock",burst_age);water_fx.set_shader_parameter("strength",1.0)
 else:surface.hide()
 cue_previous=g.cue
