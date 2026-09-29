extends SceneTree
func _initialize()->void:run.call_deferred()
func run()->void:
 for id in preload("res://scripts/minigolf/catalog.gd").ALL:
  var scene=preload("res://scripts/shore.gd").create(id);root.add_child(scene)
  # Include modeled land even where fishing limits previously omitted collision.
  for mesh in scene.find_children("*","MeshInstance3D",true,false):
   if mesh.mesh and not mesh.mesh is PrimitiveMesh:mesh.create_trimesh_collision()
  await physics_frame;await physics_frame
  var hits:Array=[]
  for z in [15,26,40,60]:
   for x in [-20,0,20,28]:
    var query:=PhysicsRayQueryParameters3D.create(Vector3(x,25,z),Vector3(x,-10,z))
    var hit:Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(query)
    hits.append([x,z,snappedf(hit.position.y,.01) if not hit.is_empty() else null])
  print("GROUND ",id," ",JSON.stringify(hits))
  scene.queue_free();await process_frame
 quit()
