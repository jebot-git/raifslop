extends SceneTree
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func run():
 var g=load("res://scenes/main.tscn").instantiate();root.add_child(g)
 await create_timer(.4).timeout
 g.set_process(false);g.motor.set_physics_process(false)
 var policy=g.shadow_policy
 for entry in g.Locations.CATALOG:
  g._select_location(entry.id,false)
  g.avatar.global_position=g.motor.safe_spawn
  for i in range(4):await physics_frame
  await physics_frame;await physics_frame
  check(not g.location_sun.shadow_enabled,"Blob mode disables real-time shadow maps: "+entry.id)
  check(policy.blobs.has(g.avatar) and policy.blobs[g.avatar].visible,"Blob projects onto location floor: "+entry.id)
  if policy.blobs.has(g.avatar) and policy.blobs[g.avatar].visible:
   var at:Vector3=policy.blobs[g.avatar].global_position
   var ground:Dictionary=g.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*.1,at-Vector3.UP*.1,1))
   check(not ground.is_empty() and absf(at.y-ground.position.y-.012)<.01,"Blob sits on actual surface: "+entry.id)
 g.avatar.global_position=Vector3(0,0,-15)
 await physics_frame;await physics_frame
 check(not policy.blobs[g.avatar].visible,"No blob floats over open water")
 g.avatar.global_position=g.motor.safe_spawn;g.avatar.hide()
 await physics_frame;await physics_frame
 check(not policy.blobs[g.avatar].visible,"Hidden or remote-location avatars have no blob")
 check(not policy.has_method("set_mode") and not g.avatar_menu.has_method("attach_shadow_controls"),"Dynamic shadow preference and menu control removed")
 g.queue_free();await process_frame;await process_frame
 print("BLOB_SHADOW_RESULT ",failures);quit(0 if failures.is_empty() else 1)
