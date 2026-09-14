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
  policy.set_mode("blob",false);await physics_frame;await physics_frame
  check(not g.location_sun.shadow_enabled,"Blob mode disables real-time shadow maps: "+entry.id)
  check(policy.blobs.has(g.avatar) and policy.blobs[g.avatar].visible,"Blob projects onto location floor: "+entry.id)
  if policy.blobs.has(g.avatar):check(absf(policy.blobs[g.avatar].global_position.y-.012)<.03,"Blob sits on surface: "+entry.id)
  policy.set_mode("dynamic",false);await physics_frame
  check(g.location_sun.shadow_enabled and not policy.blobs[g.avatar].visible,"Dynamic option restores shadows and hides blob: "+entry.id)
 policy.set_mode("blob",false)
 g.avatar.global_position=Vector3(0,0,-15)
 await physics_frame;await physics_frame
 check(not policy.blobs[g.avatar].visible,"No blob floats over open water")
 g.avatar.global_position=g.motor.safe_spawn;g.avatar.hide()
 await physics_frame;await physics_frame
 check(not policy.blobs[g.avatar].visible,"Hidden or remote-location avatars have no blob")
 policy.set_mode("dynamic");var config:=ConfigFile.new();config.load("user://graphics.cfg")
 check(config.get_value("shadows","mode","")=="dynamic","Shadow preference persists")
 g.queue_free();await process_frame;await process_frame
 print("BLOB_SHADOW_RESULT ",failures);quit(0 if failures.is_empty() else 1)
