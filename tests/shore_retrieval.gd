extends SceneTree
var failures:Array=[]
func check(ok:bool,label:String)->void:
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func _initialize()->void:run.call_deferred()
func run()->void:
 var g=load("res://scenes/main.tscn").instantiate();root.add_child(g)
 await create_timer(.4).timeout
 g.set_process(false);g.motor.set_physics_process(false);g.fishing_feedback.set_process(false)
 # Avoid concurrent decoder teardown while rapidly replacing every ambience.
 for player in g.find_children("*","AudioStreamPlayer",true,false):player.stop()
 for entry in g.Locations.CATALOG:
  g.game.reset();g._select_location(entry.id,false)
  for player in g.find_children("*","AudioStreamPlayer",true,false):player.stop()
  await physics_frame;await physics_frame
  g.cast_anchor=Vector3(g.rod.global_position.x,g.water_level+.05,g.rod.global_position.z)
  g.cast_target=g.cast_anchor+Vector3.FORWARD*15
  g.game.state=g.Session.State.BITE;g.game.fish_index=11 if g.game.is_fly_fishing() else 0;g.game.strike()
  g.game.jumps_enabled=false;g.game.next_submerge=100;g.game.next_cue=100;g.game.phase=0;g.game.stamina=0;g.game.distance=15
  g.game.landing_distance=20 # Stale threshold from an earlier angled cast.
  g._process(.02)
  check(g.game.state==g.Session.State.FIGHT and g.game.landing_distance<g.game.distance-1.0,"Exhausted mid-water fish recomputes shoreline after its direction changes: "+entry.id)
  g.game.tick(.02,1,0,true)
  check(g.game.state==g.Session.State.FIGHT,"Winding cannot collect an exhausted fish out in the water: "+entry.id)
  g.game.distance=g.game.landing_distance
  g.game.tick(.02,0,0)
  check(g.game.state==g.Session.State.FIGHT,"A final retrieval is required: "+entry.id)
  g.game.tick(.02,1,0,true)
  check(g.game.state==g.Session.State.LANDED,"Shoreline retrieval lands the fish: "+entry.id)
 g.queue_free();await process_frame;await create_timer(.2).timeout
 print("SHORE_RETRIEVAL_RESULT ",failures);quit(0 if failures.is_empty() else 1)
