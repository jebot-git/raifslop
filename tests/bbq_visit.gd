extends SceneTree
const Sites=preload("res://scripts/bbq/sites.gd")
var failures:Array=[]
func _initialize() -> void:run.call_deferred()
func check(ok:bool,label:String) -> void:
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func run() -> void:
 var g=load("res://scenes/main.tscn").instantiate();root.add_child(g);await create_timer(.5).timeout
 g.set_process(false);g.motor.set_physics_process(false);g.fishing_feedback.set_process(false)
 g.game.reset();g._select_location("bell_park_pier",false);g.bbq.select_location()
 var before:Vector3=g.motor.global_position
 g.bbq.visit();await create_timer(.6).timeout
 check(g.bbq.visiting and not g.bbq.transitioning,"Visit completes its fade")
 check(g.rod_holster.stowed and g.game.state==g.Session.State.READY,"Visit leaves bait rearmed with rod safely stowed")
 check(g.motor.global_position.distance_to(Sites.arrival("bell_park_pier"))<.01,"Visit reaches the protected picnic deck")
 g.bbq.return_to_water();await create_timer(.6).timeout
 check(g.motor.global_position.distance_to(before)<.01 and not g.bbq.visiting,"Return restores fishing position")
 g.game.state=g.Session.State.WAITING;g.bbq.visit();await process_frame
 check(not g.bbq.visiting and g.game.state==g.Session.State.WAITING,"Visit cannot interrupt an active cast")
 g.game.reset();g._toggle_avatar_menu();g.avatar_menu.show_page("bbq")
 if "--capture" in OS.get_cmdline_user_args():
  for i in 8:await process_frame
  root.get_texture().get_image().save_png("res://test-results/bbq-menu.png")
 print("BBQ_VISIT_RESULT ",failures)
 for p in g.find_children("*","AudioStreamPlayer",true,false):p.stop()
 g.queue_free();await process_frame;await create_timer(.3).timeout;quit(0 if failures.is_empty() else 1)
