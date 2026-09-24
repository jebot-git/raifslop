extends SceneTree
var failures:Array=[]
var checks:=0
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);push_error(label)
func run():
 var bank:Node3D=load("res://scripts/river_foreground.gd").create("cedar_creek");root.add_child(bank)
 for frame in 3:await physics_frame
 var logs:=bank.get_node("CedarDeadwood")
 check(logs.get_child_count()==3,"All three Cedar log placements retained")
 var min_gap:=INF;var max_gap:=-INF
 for log in logs.get_children():
  check(log.material_override.shader.resource_path.ends_with("/fibres.gdshader"),"Shared shore wood finish")
  check(log.material_override.get_shader_parameter("timber")!=null,"Recorded wood texture present")
  var arrays:Array=log.mesh.surface_get_arrays(0)
  check(arrays[Mesh.ARRAY_COLOR]!=null and arrays[Mesh.ARRAY_TANGENT]!=null,"Vertex AO and normal-map tangent basis retained")
  var vertices:PackedVector3Array=log.mesh.get_faces()
  var bounds:AABB=log.mesh.get_aabb()
  # Independently raycast the lowest main-trunk geometry in longitudinal
  # slices against the actual physical bank, not the placement height helper.
  var contacts:=0
  for section in 12:
   var bottom:=INF;var support:=Vector3.ZERO
   for v in vertices:
    if absf(v.z)>.14 or int(clampf((v.x-bounds.position.x)/bounds.size.x*12,0,11))!=section:continue
    var point:Vector3=log.global_transform*v
    if point.y<bottom:bottom=point.y;support=point
   check(is_finite(bottom),"Trunk slice has geometry")
   var query:=PhysicsRayQueryParameters3D.create(support+Vector3.UP*2,support-Vector3.UP*2)
   var hit:=bank.get_world_3d().direct_space_state.intersect_ray(query)
   check(not hit.is_empty(),"Physical bank under trunk")
   if hit.is_empty():continue
   var gap:float=support.y-hit.position.y;min_gap=minf(min_gap,gap);max_gap=maxf(max_gap,gap)
   if gap<=.035:contacts+=1
   check(gap<=.20 and gap>=-.055,"Curved trunk clears bank without deep burial: gap %.4f m"%gap)
  check(contacts>=2,"Trunk has multiple grounded support sections")
 print("CEDAR_DEADWOOD_RESULT ",checks," checks, gap range ",[min_gap,max_gap]," failures ",failures)
 bank.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
