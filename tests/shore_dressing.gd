extends SceneTree
var failures:Array=[]
var checks:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize():run.call_deferred()
func run():
 var g=load("res://scenes/main.tscn").instantiate();root.add_child(g)
 await create_timer(.2).timeout
 g.set_process(false);g.motor.set_physics_process(false)
 var output:="res://test-results/shore-dressing"
 DirAccess.make_dir_recursive_absolute(output)
 for entry in g.Locations.CATALOG:
  g._select_location(entry.id,false)
  await physics_frame
  var dressing=g.foreground.get_node("ShoreDressing")
  check(dressing!=null,"Dressing exists "+entry.id)
  check(dressing.find_children("*","CollisionObject3D",true,false).is_empty(),"Props add no fishing barriers")
  check(dressing.get_child_count()<=4,"At most four added draw batches")
  for pos in dressing.get_meta("prop_bases"):
   check(absf(pos.x)>1.2,"Central movement and casting lane clear")
  var occupied:Array=load("res://scripts/shore_dressing.gd").plant_bounds(g.foreground)+load("res://scripts/shore_dressing.gd").fixture_bounds(entry.id)
  for key in ["prop_footprints","pebble_footprints"]:
   for area in dressing.get_meta(key,[]):
    var clear:=true
    for other in occupied:clear=clear and not area.intersects(other)
    check(clear,"Decorations have clearance "+entry.id+" "+key)
    occupied.append(area)
  var lilies:Array=[]
  for area in dressing.get_meta("lily_footprints",[]):
   var clear:=true
   for other in lilies:clear=clear and not area.intersects(other)
   check(clear,"Lily leaves do not intersect")
   lilies.append(area)
  for node in g.foreground.find_children("*","MeshInstance3D",true,false):
   if not node.visible:continue
   for surface in node.mesh.get_surface_count():
    var material:Material=node.mesh.surface_get_material(surface)
    if material and material.resource_name.begins_with("FG_rope"):
     var arrays=node.mesh.surface_get_arrays(surface)
     var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
     var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
     var clear:=true
     for index in indices:clear=clear and vertices[index].y>=.1
     check(clear,"Old floor coils removed")
  for node in dressing.get_children():
   check(node is MultiMeshInstance3D,"Props use instanced meshes")
   if node.name in ["MooringRope","Driftwood"]:
    var mesh:Mesh=node.multimesh.mesh
    var arrays=mesh.surface_get_arrays(0)
    check(arrays[Mesh.ARRAY_COLOR]!=null,"Baked vertex AO retained")
    check(arrays[Mesh.ARRAY_TANGENT]!=null,"Fibres have tangent basis")
    check(mesh.get_faces().size()/3<4200,"Per-prop triangle budget")
    if DisplayServer.get_name()!="headless":
     for i in node.multimesh.instance_count:
      var transform:Transform3D=node.multimesh.get_instance_transform(i)
      var bottom:Vector3=transform*Vector3(0,mesh.get_aabb().position.y,0)
      var ray:=PhysicsRayQueryParameters3D.create(bottom+Vector3.UP,bottom-Vector3.UP,1)
      var hit=g.get_world_3d().direct_space_state.intersect_ray(ray)
      check(not hit.is_empty() and absf(hit.position.y-bottom.y)<.06,"Prop contacts authored ground "+entry.id)
  if dressing.has_meta("lily_bases"):
   for at in dressing.get_meta("lily_bases"):
    var ray:=PhysicsRayQueryParameters3D.create(at+Vector3.UP*.7,at-Vector3.UP*.2,1)
    var hit=g.get_world_3d().direct_space_state.intersect_ray(ray)
    check(hit.is_empty() or hit.position.y<at.y-.005,"Lily patch stays off dry ground "+entry.id)
  if "--capture" in OS.get_cmdline_user_args():
   for item in [g.hud,g.rod,g.avatar,g.fish_guide,g.rod_status,g.bobber,g.aim_marker]:item.hide()
   g.line_mesh.clear_surfaces()
   var target:Vector3=dressing.get_meta("prop_bases")[0]
   g.head.global_position=target+Vector3(0,1.15,1.8)
   g.head.look_at(target+Vector3(0,.08,0))
   for frame in 12:await process_frame
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(output+"/"+entry.id+".png")
   if dressing.has_meta("lily_bases"):
    target=dressing.get_meta("lily_bases")[0]
    g.head.global_position=target+Vector3(0,1.2,1.7);g.head.look_at(target)
    for frame in 8:await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(output+"/"+entry.id+"-lilies.png")
 print("SHORE_DRESSING_RESULT ",checks," checks, ",failures)
 g.queue_free();await process_frame
 quit(0 if failures.is_empty() else 1)
