extends SceneTree
const S=preload("res://scripts/fishing_session.gd")
var failures:Array=[]
func check(ok:bool,label:String):
 if not ok:failures.append(label);push_error(label)
func _initialize():run.call_deferred()
func run():
 for fps in [30,72,90]:
  for correct in [true,false]:
   var s=S.new();s.fish_index=10;s.state=S.State.BITE;s.strike();s.stamina=.65
   s._start_jump(0)
   var scored:=false
   for i in fps*3:
    if s.jump_time<=0:break
    s.tug(0 if correct else 1);s.reel_rate=0;s._jump_tick(1.0/fps)
    if s.jump_resolved:scored=true
   check(is_equal_approx(s.stamina,.37 if correct else .90),"Jump pays stamina exactly once at "+str(fps))
   check(scored==correct and s.cue==-1 and s.counter_rest>0,"Jump resolves and grants recovery")
 var input=preload("res://scripts/fight_input.gd").new()
 check(input.sample_tug(1,0,Vector3.ZERO,.02,Basis.IDENTITY)==-1,"Tug requires a fresh tracked displacement")
 check(input.sample_tug(1,0,Vector3(-.12,0,0),.06,Basis.IDENTITY)==0,"Fast 12 cm sideways movement counts")
 check(input.sample_tug(1,0,Vector3(-.12,0,0),.06,Basis.IDENTITY)==-1,"Holding displaced rod cannot count again")
 input.reset();input.sample_tug(2,0,Vector3.ZERO,.02,Basis.IDENTITY)
 check(input.sample_tug(2,0,Vector3(-.02,0,0),.06,Basis.IDENTITY)==-1,"Slow rod drift does not count")
 var held=S.new();held.state=S.State.FIGHT;held.stamina=.65;held._start_jump(0)
 for i in 100:
  if held.jump_time<=0:break
  held.gesture(0);held.reel_rate=0;held._jump_tick(.02)
 check(is_equal_approx(held.stamina,.9),"A directional hold without a tug fails the jump")
 var winding=S.new();winding.state=S.State.FIGHT;winding.stamina=.65;winding._start_jump(1)
 for i in 200:
  if winding.jump_time<=0:break
  winding.tug(1);winding.reel_rate=1;winding._jump_tick(.02)
 check(is_equal_approx(winding.stamina,.9),"Correct rod direction with continued reeling fails")
 for index in [0,1,4,26,27]:
  var s=S.new();s.state=S.State.FIGHT;s.fish_index=index;s.next_jump=0
  check(not s._try_jump(),"Non-jumping species cannot leap")
 var tired=S.new();tired.state=S.State.FIGHT;tired.fish_index=10;tired.stamina=.4;tired.next_jump=0
 check(not tired._try_jump(),"Tired trout cannot jump")
 tired._start_jump(0);tired.reset();check(tired.jump_time==0,"Reset clears leap")
 var natural_jumps:=0
 for seed_value in 40:
  var sim=S.new();sim.rng.seed=seed_value;sim.fish_index=10;sim.state=S.State.BITE;sim.strike();sim.distance=20
  for frame in 1800:
   if sim.state!=S.State.FIGHT:break
   if sim.cue>=0:sim.gesture(sim.cue)
   var rate:=0.0 if sim.is_running() or sim.tension>.7 or sim.jump_time>0 else 1.0
   if sim.submerge==S.Submerge.PULL:rate=0
   elif sim.submerge==S.Submerge.SLACK:rate=1.8
   sim.tick(.02,rate,0)
  natural_jumps+=sim.jump_count
 check(natural_jumps>0,"Jumps occur naturally between ordinary fight moves")
 var g=load("res://scenes/main.tscn").instantiate();root.add_child(g)
 await create_timer(.3).timeout
 g.set_process(false);g.motor.set_physics_process(false);g.fishing_feedback.set_process(false)
 g.game.fish_index=10;g.game.state=S.State.FIGHT;g.game.distance=3;g.game.stamina=.4
 g.cast_anchor=Vector3(0,g.water_level,-6);g.cast_target=Vector3(0,g.water_level,-18)
 g._update_line()
 check(g.hooked_fish.visible and g.hooked_fish.global_position.y<g.water_level,"Close fish visible beneath actual water level")
 check(absf(g.hooked_fish.measured.size.x-.42)<.01,"Reused fish model has correct metre scale")
 check(absf(g.hooked_fish.global_basis.x.y)<.001,"Swimming fish stays horizontal")
 for movement in [Vector3.LEFT,Vector3.RIGHT,Vector3.FORWARD,Vector3.BACK]:
  var before:Vector3=g.hooked_fish.global_position
  g.escape_offset+=movement*.12;g._update_line()
  var actual:Vector3=g.hooked_fish.global_position-before
  check(actual.length()>.01 and g.hooked_fish.global_basis.x.dot(actual.normalized())>.999,"Fish faces actual sideways/run/retrieve movement")
  var facing:Basis=g.hooked_fish.global_basis
  g._update_line()
  check(g.hooked_fish.global_basis.is_equal_approx(facing),"Repeated render without movement keeps heading")
 g.hooked_fish.update(.035)
 check(g.hooked_fish.twitch.meshes.size()>0,"Swimming model uses twitch deformation")
 g.game.distance=12;g._update_line();check(not g.hooked_fish.visible,"Distant submerged fish hidden")
 g.game._start_jump(0);g.game.jump_time=S.JUMP_AIR*.5;g._update_line()
 check(g.hooked_fish.visible and g.hooked_fish.global_position.y>g.water_level,"Jump makes distant fish emerge above water")
 if "--capture" in OS.get_cmdline_user_args():
  var camera=Camera3D.new();g.add_child(camera);camera.current=true
  g.hud.hide()
  camera.global_position=g.hooked_fish.global_position+Vector3(1,.8,2);camera.look_at(g.hooked_fish.global_position)
  for i in 12:await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://test-results/fish-jump.png")
  g.game.jump_time=0;g.game.cue=-1;g.game.distance=3;g._update_line()
  camera.global_position=g.hooked_fish.global_position+Vector3(1,1.5,2);camera.look_at(g.hooked_fish.global_position)
  for i in 12:await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://test-results/hooked-fish.png")
 g.game.state=S.State.LOST;g._update_line()
 check(not g.hooked_fish.visible and g.water_material.get_shader_parameter("hooked_visibility")==0,"Loss removes underwater model and visibility patch")
 g.queue_free();await process_frame;await create_timer(.3).timeout
 print("FISH_JUMPS_RESULT ",failures);quit(0 if failures.is_empty() else 1)
