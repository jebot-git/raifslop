extends Node3D
## Bounded, positional fishing effects. Driven by actual accepted input and state.
const S=preload("res://scripts/fishing_session.gd")
var game_root: Node
var feeding_surfaces: Array[MeshInstance3D] = []
var reel_rate:=0.0
var haptics=preload("res://scripts/line_haptics.gd").new()
var previous:=S.State.READY
var cue_previous:=-1
var takeover_previous:=0
var jump_previous:=0
var jump_was_active:=false
var clock:=0.0
var feeding_clock:=0.0
var splash_wait:=0.0
var burst_age:=2.0
var takeover_burst_age:=2.0
var takeover_surface: MeshInstance3D
var takeover_fx: ShaderMaterial
var escape:=Vector3.ZERO
var reel_player: AudioStreamPlayer3D
var cast_player: AudioStreamPlayer3D
var ripple_player: AudioStreamPlayer3D
var submerge_previous := S.Submerge.NONE
var was_paused := false
var recovery_previous := 0
var stamina_previous := 1.0
var rest_previous := false
var running_previous := false
var fight_cue_player: AudioStreamPlayer3D
var fight_cue_kind := ""
var fight_cue_age := 2.0
var fight_surface: MeshInstance3D
var fight_water_fx: ShaderMaterial
var fight_cues:Dictionary={}

var splashes: Array[AudioStreamPlayer3D]=[]
var splash_slot:=0
var last_splash:=0
var splash_streams: Array[AudioStreamWAV]=[]
var surface: MeshInstance3D
var water_fx: ShaderMaterial
var events: Dictionary={"cast":0,"splash":0,"land":0,"ripple":0,"predator":0}
func setup(root: Node) -> void:
 game_root=root
 cast_player=player("cast");reel_player=player("reel")
 fight_cue_player=AudioStreamPlayer3D.new();add_child(fight_cue_player)
 fight_cue_player.unit_size=8.0;fight_cue_player.max_distance=65
 fight_cues={"tired":preload("res://assets/audio/fishing/ripple.wav"),"recovered":preload("res://assets/audio/fishing/splash_3.wav"),"action":preload("res://assets/audio/fishing/ripple.wav")}
 ripple_player=player("ripple");ripple_player.volume_db=-6;ripple_player.max_db=-8
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
 takeover_surface=MeshInstance3D.new();takeover_surface.mesh=plane
 takeover_fx=water_fx.duplicate();takeover_surface.material_override=takeover_fx
 takeover_surface.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 add_child(takeover_surface);takeover_surface.hide()
 fight_surface=MeshInstance3D.new();fight_surface.mesh=plane
 fight_water_fx=water_fx.duplicate();fight_surface.material_override=fight_water_fx
 fight_surface.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 add_child(fight_surface);fight_surface.hide()
func update_feeding_ripples() -> void:
 var g = game_root.game
 if feeding_surfaces.is_empty():
  for sector in S.Population.SECTOR_COUNT:
   var mesh := MeshInstance3D.new()
   var plane := PlaneMesh.new(); plane.size = Vector2(6.4, 6.4); mesh.mesh = plane
   var mat := ShaderMaterial.new(); mat.shader = water_fx.shader
   mesh.material_override = mat
   mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
   add_child(mesh); feeding_surfaces.append(mesh)
 for sector in feeding_surfaces.size():
  var mesh := feeding_surfaces[sector]
  var activity: float = g.feeding_activity(sector)
  mesh.visible = activity > .02 and g.state in [S.State.READY, S.State.CASTING, S.State.WAITING]
  mesh.global_position = g.population.center_for(g.location_id, sector, game_root.water_level + .025)
  var mat: ShaderMaterial = mesh.material_override
  # Small periodic rings, no icons or species labels, fading as stocks deplete.
  mat.set_shader_parameter("clock", fmod(feeding_clock + sector * 1.7, 4.5))
  mat.set_shader_parameter("burst", true)
  mat.set_shader_parameter("strength", activity * .22)

func player(kind: String) -> AudioStreamPlayer3D:
 var p:=AudioStreamPlayer3D.new();p.stream=load("res://assets/audio/fishing/"+kind+".wav");p.unit_size=5;p.max_distance=65;p.volume_db=-3;add_child(p);return p
func cast_swish() -> void:
 cast_player.global_position=game_root.tip.global_position;cast_player.play();events.cast+=1
func ripple(at: Vector3) -> void:
 ripple_player.global_position=at;ripple_player.play();events.ripple+=1
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
func fight_notice(kind:String) -> void:
 fight_cue_kind=kind;fight_cue_age=0.0
 fight_cue_player.stream=fight_cues[kind]
 fight_cue_player.volume_db=-6.0 if kind=="recovered" else -10.0
 fight_cue_player.max_db=fight_cue_player.volume_db
 fight_cue_player.pitch_scale=.85 if kind=="tired" else 1.05 if kind=="recovered" else 1.0
 fight_cue_player.global_position=game_root.bobber.global_position;fight_cue_player.play()
 fight_surface.global_position=game_root.bobber.global_position
 fight_surface.global_position.y=game_root.water_level+.065
 fight_water_fx.set_shader_parameter("burst",true)
 fight_water_fx.set_shader_parameter("organic_burst",true)
 fight_water_fx.set_shader_parameter("strength",.85 if kind=="recovered" else .28 if kind=="tired" else .5)
 fight_water_fx.set_shader_parameter("burst_speed",2.3 if kind=="recovered" else .85 if kind=="tired" else 1.7)
 fight_water_fx.set_shader_parameter("secondary_delay",.18 if kind=="recovered" else -1.0)
 events[kind]=events.get(kind,0)+1

func _process(delta: float) -> void:
 if not is_instance_valid(game_root):return
 var g=game_root.game
 # Ambient water life keeps moving while the Guide pauses fishing controls.
 feeding_clock+=delta
 update_feeding_ripples()
 var paused: bool=game_root.rod_holster.stowed or game_root.menu_open or game_root.fish_guide.held or game_root.avatar_loading or (game_root.xr and (not game_root.right.get_has_tracking_data() or not game_root.left.get_has_tracking_data() or not game_root.tracking_manager.focused))
 if paused:
  reel_player.stop();ripple_player.stop();fight_cue_player.stop();fight_surface.hide();haptics.pause()
  if not was_paused and game_root.xr:
   for hand in [game_root.right,game_root.left]:
    if hand.get_has_tracking_data(): hand.trigger_haptic_pulse("haptic",0.0,0.0,.01,0.0)
  was_paused=true
  return
 was_paused=false
 fight_cue_age+=delta
 if g.state==S.State.FIGHT and previous==S.State.FIGHT:
  if g.recovery_count!=recovery_previous:
   fight_notice("recovered")
  elif (g.stamina<=.35 and stamina_previous>.35) or (g.counter_rest>0 and not rest_previous):
   fight_notice("tired")
  elif (g.is_running() and not running_previous) or (g.cue>=0 and g.cue!=cue_previous) or (g.submerge!=S.Submerge.NONE and g.submerge!=submerge_previous):
   fight_notice("action")
 fight_surface.visible=g.state==S.State.FIGHT and fight_cue_age<1.8
 fight_water_fx.set_shader_parameter("clock",fight_cue_age)
 recovery_previous=g.recovery_count;stamina_previous=g.stamina;rest_previous=g.counter_rest>0;running_previous=g.is_running()
 var pulse:Dictionary=haptics.sample(g,delta)
 if not pulse.is_empty() and game_root.xr:
  game_root.right.trigger_haptic_pulse("haptic",0.0,pulse.strength,pulse.duration,0.0)
 var reel_pulse: Dictionary=haptics.sample_reel(g,reel_rate,delta)
 if not reel_pulse.is_empty() and game_root.xr:
  game_root.left.trigger_haptic_pulse("haptic",0.0,reel_pulse.strength,reel_pulse.duration,0.0)
 clock+=delta
 reel_player.global_position=game_root.crank.global_position
 if (g.state==S.State.FIGHT or (g.is_fly_fishing() and g.state==S.State.WAITING)) and reel_rate>.03:
  reel_player.pitch_scale=clampf(reel_rate,.4,2.0)
  if not reel_player.playing:reel_player.play()
 else:reel_player.stop()
 if g.state!=previous:
  if g.state==S.State.WAITING:
   splash(game_root.bobber.global_position,false,true);splash_wait=1.1
  elif g.state==S.State.BITE and g.is_fly_fishing():
   ripple(game_root.bobber.global_position)
  elif g.state==S.State.FIGHT:
   ripple(game_root.bobber.global_position);splash_wait=1.4
  elif g.state==S.State.LANDED:
   splash(surface.global_position,true);burst_age=0
  previous=g.state
 if g.jump_count!=jump_previous:
  ripple(game_root.bobber.global_position);jump_previous=g.jump_count
 if jump_was_active and g.jump_time<=0 and g.state==S.State.FIGHT:
  splash(game_root.bobber.global_position)
 jump_was_active=g.jump_time>0
 if g.takeover_count!=takeover_previous:
  if g.state==S.State.FIGHT:
   splash(game_root.bobber.global_position);ripple(game_root.bobber.global_position)
   var impact=splashes[(splash_slot+2)%splashes.size()]
   impact.volume_db=-1;impact.max_db=-1;impact.unit_size=7.0
   takeover_burst_age=0.0
   takeover_surface.global_position=game_root.bobber.global_position
   takeover_surface.global_position.y=game_root.water_level+.055
   takeover_fx.set_shader_parameter("burst",true)
   takeover_fx.set_shader_parameter("strength",1.8)
   splash_wait=2.5;events.predator+=1
  takeover_previous=g.takeover_count
 takeover_burst_age+=delta
 takeover_surface.visible=takeover_burst_age<1.8
 takeover_fx.set_shader_parameter("clock",takeover_burst_age)
 if g.state==S.State.FIGHT:
  surface.show();surface.global_position=game_root.bobber.global_position;surface.global_position.y=game_root.water_level+.045
  escape=game_root.fish_escape_direction()
  if g.submerge == S.Submerge.SLACK:
   escape = game_root.cast_anchor - game_root.bobber.global_position
   escape.y = 0.0
   escape = escape.normalized()
  water_fx.set_shader_parameter("heading",Vector2(escape.x,escape.z))
  water_fx.set_shader_parameter("directional",g.cue>=0 or g.submerge==S.Submerge.SLACK)
  water_fx.set_shader_parameter("burst",false)
  water_fx.set_shader_parameter("strength",.9 if g.submerge==S.Submerge.SLACK else .15 if g.submerge==S.Submerge.PULL else 1.0 if g.cue>=0 or g.is_running() else .4)
  water_fx.set_shader_parameter("clock",clock)
  splash_wait-=delta
  if (g.cue>=0 and g.cue!=cue_previous) or (g.submerge!=S.Submerge.NONE and g.submerge!=submerge_previous):
   splash_wait=1.1
  elif splash_wait<=0 and g.submerge==S.Submerge.NONE:
   splash(surface.global_position);splash_wait=randf_range(1.0,1.5) if g.is_running() or g.cue>=0 else randf_range(2.0,2.8)
 elif burst_age<1.8:
  burst_age+=delta;surface.show();water_fx.set_shader_parameter("burst",true);water_fx.set_shader_parameter("clock",burst_age);water_fx.set_shader_parameter("strength",1.0)
 else:surface.hide()
 cue_previous=g.cue
 submerge_previous=g.submerge
