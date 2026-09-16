extends SceneTree
const Sites=preload("res://scripts/bbq/sites.gd")
var failures:Array=[]
var g
func _initialize() -> void:run.call_deferred()
func check(ok:bool,message:String) -> void:
 if not ok:failures.append(message);push_error(message)
func run() -> void:
 g=load("res://scenes/main.tscn").instantiate();root.add_child(g)
 await create_timer(.7).timeout
 g.set_process(false);g.motor.set_physics_process(false);g.fishing_feedback.set_process(false)
 var baseline:Dictionary={"journal":g.game.journal.duplicate(true),"catches":g.game.catches,"bait":g.game.bait}
 var report:Dictionary={}
 for location in Sites.SITES:
  for player in g.find_children("*","AudioStreamPlayer",true,false):player.stop()
  check(g._select_location(location,false),"Travel "+location)
  g.bbq.select_location();g.bbq.service.request("start");g.bbq.refresh()
  await physics_frame;await process_frame
  check(is_instance_valid(g.bbq.station),"Station exists "+location)
  var site:=Sites.pose(location)
  var arrival:=Sites.arrival(location)
  var space:PhysicsDirectSpaceState3D=g.get_world_3d().direct_space_state
  var ground:=space.intersect_ray(PhysicsRayQueryParameters3D.create(site.origin+Vector3.UP*3,site.origin-Vector3.UP*3,1))
  for seat in 8:
   var spot:=Sites.arrival(location,seat)
   var support:=space.intersect_ray(PhysicsRayQueryParameters3D.create(spot+Vector3.UP*2,spot-Vector3.UP*2,1))
   check(not support.is_empty() and absf(support.position.y-spot.y)<.18,"Visitor %d has ground at %s" % [seat,location])
  var landing:=space.intersect_ray(PhysicsRayQueryParameters3D.create(arrival+Vector3.UP*3,arrival-Vector3.UP*3,1))
  check(not ground.is_empty(),"Grill has supporting mesh "+location)
  check(not landing.is_empty(),"Arrival has supporting mesh "+location)
  if not ground.is_empty():check(absf(ground.position.y-site.origin.y)<.16,"Grill is grounded "+location)
  report[location]={"site":str(site.origin),"floor":str(ground.get("position",Vector3.INF)),"arrival_floor":str(landing.get("position",Vector3.INF))}
  if "--capture" in OS.get_cmdline_user_args():
   g.head.top_level=true;g.head.global_position=site*Vector3(2.3,2.15,3.2);g.head.look_at(site*Vector3(0,.65,0));g.hud.hide();g.avatar.hide();g.rod.hide()
   for i in 6:await process_frame
   var im=root.get_texture().get_image();im.save_png("res://test-results/bbq-"+location+".png")
  for player in g.find_children("*","AudioStreamPlayer",true,false):player.stop()
 g.head.top_level=false
 check(g.game.journal==baseline.journal and g.game.catches==baseline.catches and g.game.bait==baseline.bait,"BBQ does not change fishing rewards or bait")
 var f:=FileAccess.open("res://test-results/bbq-sites.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "))
 print("BBQ_SCENE ",JSON.stringify({"failures":failures}))
 for player in g.find_children("*","AudioStreamPlayer",true,false):player.stop()
 g.queue_free();await process_frame;await create_timer(.3).timeout;quit(0 if failures.is_empty() else 1)
