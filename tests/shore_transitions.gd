extends SceneTree
const Details=preload("res://scripts/shore_details.gd")
var failures:Array=[]
func check(ok:bool,label:String):
 if not ok:failures.append(label);push_error(label)
func _initialize():run.call_deferred()
func run():
 var g=load("res://scenes/main.tscn").instantiate();root.add_child(g)
 await create_timer(.4).timeout
 g.set_process(false);g.motor.set_physics_process(false);g.line_mesh.clear_surfaces()
 for item in [g.hud,g.rod,g.avatar,g.fish_guide,g.rod_status,g.bobber]:item.hide()
 var camera:=Camera3D.new();g.add_child(camera);camera.current=true
 for id in ["lakeside","gray_pier","meadow_bend","boulder_run"]:
  g.game.reset();check(g._select_location(id,false),"Travel "+id);await physics_frame
  if id in ["lakeside","gray_pier"]:
   var details=g.foreground.get_node("ShoreTransitionDetails")
   check(details.get_meta("cross_sections")==3,"Three crossed planes per shoreline clump")
   check(details.find_children("*","StaticBody3D",true,false).is_empty(),"Decorations do not obstruct casting or walking")
   for at in details.get_meta("plant_bases"):
    if at.y>-.2:
     var hit=g.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP,at-Vector3.UP,1))
     check(not hit.is_empty(),"Plant base has supporting ground: "+str(at))
   check(details.get_node("CrossedShorePlants").multimesh.mesh.get_surface_count()==1,"Crossed clumps batch into one vegetation surface")
   if id=="gray_pier":
    # Include the whole crossed card footprint plus sway, not just its root.
    var bench:=Rect2(Vector2(-3.83,8.15),Vector2(1.86,.7)).grow(.1)
    for footprint in details.get_meta("plant_footprints"):
     check(not footprint.intersects(bench),"Reed leaves clear the Gray Pier bench")
  else:
   for group_name in ["LayeredRiverShrubs","RiverAlders"]:
    var group=g.foreground.get_node(group_name)
    var sections:int=3 if group_name=="LayeredRiverShrubs" else 2
    check(group.get_meta("cross_sections")==sections,"River cross sections: "+group_name)
    var mesh:Mesh=group.get_child(0).multimesh.mesh
    check(mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()==sections*6,"Crossed geometry actually present")
    check(mesh.get_aabb().size.z>.8,"Crossed geometry has depth")
    if group_name=="LayeredRiverShrubs":
     for plant in group.get_meta("plant_footprints"):
      for i in 16:
       var at:Vector3=plant.at+Vector3(cos(i*TAU/16),0,sin(i*TAU/16))*plant.radius
       var hit=g.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*10,at-Vector3.UP*10,1))
       check(not hit.is_empty(),"Shrub footprint has bank support")
       if not hit.is_empty():check(plant.at.y<=hit.position.y+.01,"Shrub base buried across its full footprint")
  if "--capture" in OS.get_cmdline_user_args():
   var target:=Vector3(6.6,.4,5) if id=="lakeside" else Vector3(3.4,.6,8) if id=="gray_pier" else Vector3(8,.8,-1)
   var at:=Vector3(2,1.7,1) if id=="lakeside" else Vector3(0,1.7,4) if id=="gray_pier" else Vector3(3,1.7,1)
   for view in ["standing","seated","side"]:
    camera.global_position=at+(Vector3(-2,0,7) if view=="side" else Vector3(0,-.55,0) if view=="seated" else Vector3.ZERO)
    camera.look_at(target)
    for i in 12:await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://test-results/transition-"+id+"-"+view+".png")
 g.queue_free();await process_frame;await create_timer(.3).timeout
 print("SHORE_TRANSITIONS_RESULT ",failures);quit(0 if failures.is_empty() else 1)
