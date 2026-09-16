extends SceneTree
var failures:Array[String]=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
 if not ok:failures.append(label);push_error(label)
func run():
 var g=load("res://scenes/main.tscn").instantiate();root.add_child(g)
 await create_timer(.5).timeout
 g.set_process(false);g.motor.set_physics_process(false)
 for item in [g.hud,g.rod,g.avatar,g.fish_guide,g.rod_status,g.bobber]:item.hide()
 var output="res://test-results/rear-scenery/"+("before" if "--before" in OS.get_cmdline_user_args() else "after")
 DirAccess.make_dir_recursive_absolute(output)
 for id in ["lake_pier","simons_town_rocks"]:
  if not g._select_location(id,false):
   push_error("Cannot load "+id);quit(1);return
  var parallax:MeshInstance3D=g.foreground.get_node("RearParallax")
  var bands:Array=parallax.get_meta("depth_bands")
  check(bands.size()>=5,"Rear panorama separates foreground and skyline depth")
  # Near-horizon photograph detail previously covered a long, almost flat apron.
  # Require less than half its metres per angular degree at -2 degrees elevation.
  var angular_scale:float=0
  for i in bands.size()-1:
   check(bands[i+1].x>bands[i].x and bands[i+1].y>bands[i].y,"Continuous ordered depth bands")
   if bands[i].x<=-2 and bands[i+1].x>=-2:
    angular_scale=(bands[i+1].y-bands[i].y)/(bands[i+1].x-bands[i].x)
  var flat_scale:float=1.75/pow(sin(deg_to_rad(2)),2)*PI/180
  check(angular_scale<flat_scale*.5,"Near-horizon projection stretching reduced")
  if "--before" in OS.get_cmdline_user_args():parallax.hide()
  if id=="lake_pier":
   var bridge_vertices:=0
   var poster:=false
   for node in g.foreground.find_children("*BakedForeground*","MeshInstance3D",true,false):
    for surface in node.mesh.get_surface_count():
     var source:Material=node.mesh.surface_get_material(surface)
     var mat:Material=node.get_active_material(surface)
     if source.resource_name.begins_with("FG_billboard_print"):
      poster=true
      var artwork:String=FileAccess.get_file_as_string("res://assets/environment/shore_details/fishing_plan_poster.svg")
      check(artwork.contains("낚시계획 만세!") and not artwork.contains("<text"),"Korean block lettering is outlined for every renderer")
      check(mat.get_shader_parameter("albedo_tex")!=null,"Printed face uses artwork with baked lighting")
      check(mat.next_pass==null,"Photographic ground never covers the billboard")
     var arrays:Array=node.mesh.surface_get_arrays(surface)
     check(arrays[Mesh.ARRAY_TEX_UV2].size()==arrays[Mesh.ARRAY_VERTEX].size(),"Authored surfaces retain bake UVs")
     for v in arrays[Mesh.ARRAY_VERTEX]:
      var p:Vector3=node.global_transform*v
      if source.resource_name.begins_with("FG_billboard_print"):
       check(p.x>2.6 and p.x<3.1 and p.z<3.3,"Billboard moved forward while staying outside the fence")
      if p.z>7 and p.z<12.3 and p.x>=-2.2 and p.x<=.2 and absf(p.y)<.02:bridge_vertices+=1
   check(poster and bridge_vertices>0,"Baked bridge and printed face exist in game model")
  check(not g.location_sun.shadow_enabled,"Scenery retains static lighting without dynamic shadow maps")
  if "--capture" in OS.get_cmdline_user_args():
   for view in [["rear",Vector3(0,1.65,.65),Vector3(-.15,PI,0)], ["rear_left",Vector3(-1.8,1.65,2.5),Vector3(-.15,PI+.3,0)], ["rear_right",Vector3(1.8,1.65,2.5),Vector3(-.15,PI-.3,0)], ["poster",Vector3(0,1.65,1.6),Vector3(0,-PI/2,0)], ["front",Vector3(0,1.65,.65),Vector3(-.15,0,0)]]:
    g.head.global_position=view[1];g.head.rotation=view[2]
    for comparison in (["before","after"] if "--compare" in OS.get_cmdline_user_args() else [output.get_file()]):
     parallax.visible=comparison!="before"
     var target:String="res://test-results/rear-scenery/"+comparison
     DirAccess.make_dir_recursive_absolute(target)
     for i in 10:await process_frame
     await RenderingServer.frame_post_draw
     root.get_texture().get_image().save_png(target+"/"+id+"_"+view[0]+".png")
 # The dynamic sun must point at the same world-space lobe used by Cycles.
 var records:Dictionary=g.Locations.measured_lighting
 for entry in g.Locations.CATALOG:
  var source:String={"meadow_bend":"lakeside","boulder_run":"bell_park_pier"}.get(entry.id,entry.id)
  check(records.has(source),"Every panorama has measured lighting: "+entry.id)
  if not records.has(source):continue
  var light:Dictionary=records[source]
  var d:Array=light.sun_direction
  var direction:=Vector3(d[0],d[1],d[2])
  var rotation:Vector3=entry.sun_rotation*PI/180
  check(Basis.from_euler(rotation).z.dot(direction)>.9999,"Godot sun agrees with HDR/Cycles axes: "+entry.id)
  check(entry.sun_energy>0 and is_finite(entry.sun_energy),"Finite measured sun energy")
 g.queue_free();await process_frame
 print("REAR_SCENERY_RESULT ",failures)
 quit(0 if failures.is_empty() else 1)
