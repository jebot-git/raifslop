extends SceneTree
const S=preload("res://scripts/fishing_session.gd")
var failures:Array=[]
func check(ok:bool,label:String):
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func fight():
 var s=S.new();s.state=S.State.FIGHT;s.distance=100;s.next_cue=100;s.next_submerge=100;s.jumps_enabled=false;s.predator_encounters_enabled=false
 s.tension=.96;s.danger_side=1;s.danger_time=2.35
 return s
func _initialize():run.call_deferred()
func run():
 var eased=fight();eased.recover_strength(.18)
 var held=fight();held.recover_strength(.18)
 for i in 60:
  eased.tick(.01,0,0);held.tick(.01,2,0)
 check(eased.state==S.State.FIGHT and held.state==S.State.FIGHT,"Recovery gives both players a brief reaction interval")
 check(eased.tension<.9 and eased.danger_time<held.danger_time,"Releasing within 0.6 seconds actually relieves tension and strain")
 for i in 30:held.tick(.01,2,0)
 check(held.state==S.State.LOST and held.message.contains("snapped"),"Ignoring recovery warning still snaps an already strained line within one second")
 var repeat=fight();repeat.recover_strength();repeat.recovery_time=.2;repeat.recover_strength(.1)
 check(repeat.recovery_time==.2,"Repeated recovery cannot extend an active grace window")
 var bad=fight();bad.danger_time=3.0;bad.recover_strength();bad.tick(.01,2,0)
 check(bad.state==S.State.LOST,"Recovery cannot rescue a line already beyond its failure budget")
 var slack=fight();slack.tension=.01;slack.danger_side=-1;slack.danger_time=1.79;slack.recover_strength();slack.tick(.02,0,0)
 check(slack.state==S.State.LOST and slack.message.contains("slipped"),"Recovery grace never forgives slack")
 var missed=fight();missed.tension=.6;missed.danger_time=0;missed.cue=0;missed.cue_time=.01;missed.stamina=.2;missed.tick(.02,0,0)
 check(missed.recovery_count==1 and missed.recovery_time>0 and missed.stamina>.35,"Missed counter exposes recovered strength immediately")
 var rest=fight();rest.tension=.6;rest.danger_time=0;rest.counter_rest=.01;rest.tick(.02,0,0)
 check(rest.recovery_count==1 and not rest.reel_instruction().contains("RECOVERED"),"End of tired phase opens hidden reaction window")
 var g=load("res://scenes/main.tscn").instantiate();root.add_child(g);await create_timer(.3).timeout
 g.set_process(false);g.motor.set_physics_process(false);var fx=g.fishing_feedback;fx.set_process(false)
 g.game.state=S.State.FIGHT;g.game.next_cue=100;fx._process(.02)
 var label_before:String=g.rod_status.label.text
 g.game.stamina=.3;fx._process(.02)
 check(fx.events.get("tired",0)==1 and fx.fight_cue_player.playing and fx.fight_surface.visible and g.rod_status.label.text==label_before,"Exhaustion uses positional sound and water rings without a UI notice")
 fx._process(.02);check(fx.events.get("tired",0)==1,"Exhaustion cue never repeats every frame")
 g.game.recover_strength(.18);fx._process(.02)
 check(fx.events.get("recovered",0)==1 and fx.fight_cue_player.stream.resource_path.ends_with("splash_3.wav") and fx.fight_water_fx.get_shader_parameter("secondary_delay")>0 and g.rod_status.label.text==label_before,"Recovery uses a splash and double water pulse without UI")
 g.menu_open=true;fx._process(.02);check(not fx.fight_cue_player.playing,"Menu pauses fight cues")
 g.ambience.stop();await create_timer(.3).timeout;g.queue_free();await process_frame;await create_timer(.3).timeout
 quit(0 if failures.is_empty() else 1)
