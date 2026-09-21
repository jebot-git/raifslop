extends SceneTree
const S=preload("res://scripts/fishing_session.gd")
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func run():
 var root_game=load("res://scenes/main.tscn").instantiate();root.add_child(root_game)
 await create_timer(.3).timeout
 root_game.set_process(false);root_game.motor.set_physics_process(false)
 var f=root_game.fishing_feedback;f.set_process(false)
 root_game._cast(12)
 check(f.events.cast==1 and f.cast_player.playing,"Accepted cast produces positional swish")
 root_game._cast(12);check(f.events.cast==1,"Rejected repeated cast does not repeat swish")
 var g=root_game.game
 g.tick(1,0,0);root_game._update_line();f._process(.02)
 check(f.events.splash==1,"Float impact produces splash")
 check(f.splashes[0].stream.resource_path.ends_with("impact.wav"),"Float entry uses the small river plop recording")
 check(f.cast_player.max_db<=-8 and f.splashes[0].max_db<=-8,"Close-range gain cannot amplify quiet foley")
 f.splash(root_game.bobber.global_position);var variant=f.last_splash
 f.splash(root_game.bobber.global_position)
 check(f.last_splash!=variant and f.splash_streams.size()==3,"Recorded fight splashes avoid immediate repeats")
 g.state=S.State.BITE;g.strike();root_game._update_line();f.reel_rate=1;f._process(.02)
 check(f.events.ripple==1 and f.ripple_player.playing,"Hooked fish starts with a subtle recorded ripple")
 check(f.ripple_player.global_position.is_equal_approx(root_game.bobber.global_position) and f.ripple_player.max_db<=-8,"Fight-start ripple is quiet and located at the fish")
 check(f.reel_player.playing,"Accepted reeling runs ratchet loop")
 f.reel_rate=1.7;f._process(.02);check(is_equal_approx(f.reel_player.pitch_scale,1.7),"Reeling speed changes ratchet speed")
 f.reel_rate=0;f._process(.02);check(not f.reel_player.playing,"Stopped crank stops sound")
 check(f.events.ripple==1,"Fight-start ripple does not repeat every frame")
 g.location_id="lakeside";g.fish_index=3;g._takeover(S.WELS)
 var ripples: int=f.events.ripple
 f._process(.02)
 check(f.events.predator==1 and f.events.ripple==ripples+1,"Predator takeover has a positional splash and ripple")
 check(f.splashes[(f.splash_slot+2)%3].max_db==-1,"Takeover splash is louder than ordinary fight splashes")
 check(f.takeover_surface.visible and f.takeover_fx.get_shader_parameter("burst"),"Takeover displays a dedicated expanding water burst")
 var burst_position:Vector3=f.takeover_surface.global_position
 root_game.bobber.position.x+=1
 f._process(.02)
 check(f.takeover_surface.global_position==burst_position,"Takeover burst remains at impact while predator swims away")
 f._process(.02)
 check(f.events.predator==1 and f.events.ripple==ripples+1,"Takeover audio never repeats each frame")
 root_game.origin.rotation.y=.8
 for cue in range(3):
  g.cue=cue;f._process(.02)
  var d=root_game.fish_escape_direction()
  var expected=root_game.origin.global_basis.x * (1 if cue==0 else -1) if cue<2 else (root_game.cast_target-root_game.cast_anchor).normalized()
  check(d.dot(expected)>.99,"Wake opposes counter after player turns: "+str(cue))
  check(f.surface.visible and f.water_fx.get_shader_parameter("directional"),"Fight cue shows directional surface wake: "+str(cue))
 f.reel_rate=1;root_game.menu_open=true;f._process(.02);check(not f.reel_player.playing,"Menu pauses reel audio")
 root_game.menu_open=false
 g.cue=-1;g.submerge=S.Submerge.PULL;g.submerge_time=2
 f._process(.02)
 check(f.water_fx.get_shader_parameter("strength")<.4 and is_equal_approx(f.surface.global_position.y,root_game.water_level+.045),"Submerged fish leaves a quieter wake on the actual water surface")
 g.submerge=S.Submerge.NONE
 g.at_ground_boundary=true;g.jump_time=0
 var distance_before:float=g.distance
 root_game.time=.10;root_game._update_line()
 var bobber_before:Vector3=root_game.bobber.position
 var rotation_before:Vector3=root_game.bobber.rotation
 root_game.time=.23;root_game._update_line()
 check(absf(root_game.bobber.position.y-bobber_before.y)>.01 and root_game.bobber.rotation.distance_to(rotation_before)>.05,"Blocked fighting fish keeps float hopping and shaking")
 check(g.distance==distance_before and g.state==S.State.FIGHT,"Shore float animation does not move fish or finish fight")
 g.at_ground_boundary=false;root_game._update_line()
 check(root_game.bobber.rotation.is_zero_approx(),"Float shake stops when fish leaves boundary")
 g.tension=0;root_game._update_line();var slack_color=root_game.line_material.albedo_color
 g.tension=1;root_game._update_line();var tight_color=root_game.line_material.albedo_color
 check(slack_color.b>slack_color.r and tight_color.r>tight_color.b,"Line shows blue slack and red high tension")
 var at=f.surface.global_position;g.state=S.State.LANDED;f._process(.02)
 check(f.events.land==1,"Lifting caught fish produces landing splash")
 check(f.splashes[(f.splash_slot+2)%3].global_position.is_equal_approx(at),"Landing splash stays at last water position")
 f._process(.02);check(f.events.land==1,"Held catch never repeats landing splash")
 f._process(2);f._process(.02);check(not f.surface.visible,"Landing rings expire")
 check(f.splashes.size()==3,"Splash voice pool stays bounded")
 # Exercise the actual tension failure paths, not just formulas.
 for high in [true,false]:
  var sim=S.new();sim.state=S.State.FIGHT;sim.distance=100;sim.tension=1.0 if high else 0.0;sim.next_cue=100
  for i in range(200):
   sim.tick(.02,2 if high else 0,0)
   if sim.state!=S.State.FIGHT:break
  check(sim.state==S.State.LOST and ("snapped" in sim.message if high else "slipped" in sim.message),"High tension snaps / slack slips: "+str(high))
 var calm=S.new();calm.state=S.State.FIGHT;calm.next_cue=100;var run=S.new();run.state=S.State.FIGHT;run.phase=6;run.next_cue=100
 calm.tick(.1,1,0);run.tick(.1,1,0);check(run.tension>calm.tension,"Reeling during runs adds more tension")
 run.cue=0;var before=run.tension
 var without=S.new();without.state=S.State.FIGHT;without.phase=run.phase;without.cue=0;without.tension=before;without.stamina=run.stamina
 run.gesture(0);run.tick(.05,0,0);without.tick(.05,0,0)
 check(run.tension<without.tension,"Sustained counter reduces load compared with no counter")
 root_game.queue_free();await process_frame;await create_timer(.3).timeout
 print("FISHING_FEEDBACK_RESULT ",failures);quit(0 if failures.is_empty() else 1)
