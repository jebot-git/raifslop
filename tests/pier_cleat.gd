extends SceneTree
const Shore=preload("res://scripts/shore.gd")
var failures: Array=[]
func check(ok:bool,label:String)->void:
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func _initialize()->void:run.call_deferred()
func run()->void:
 var scene=load("res://assets/models/locations/lit/lake_pier.glb").instantiate()
 var node:MeshInstance3D=scene.find_child("lake_pier_BakedForeground",true,false)
 var original:ArrayMesh=node.mesh
 Shore.ground_pier_cleat(scene)
 var repaired:ArrayMesh=node.mesh
 var changed:=0
 var untouched:=true
 var uv_intact:=true
 for surface in original.get_surface_count():
  var a:Array=original.surface_get_arrays(surface)
  var b:Array=repaired.surface_get_arrays(surface)
  for slot in a.size():
   if slot in [Mesh.ARRAY_NORMAL,Mesh.ARRAY_TANGENT]:
    # Godot repacks normal/tangent directions into quantized vertex attributes.
    for i in a[slot].size():
     var error:float=a[slot][i].distance_to(b[slot][i]) if a[slot][i] is Vector3 else absf(a[slot][i]-b[slot][i])
     uv_intact=uv_intact and error<.0002
   elif slot!=Mesh.ARRAY_VERTEX:uv_intact=uv_intact and a[slot]==b[slot]
  for i in a[Mesh.ARRAY_VERTEX].size():
   var before:Vector3=a[Mesh.ARRAY_VERTEX][i]
   var after:Vector3=b[Mesh.ARRAY_VERTEX][i]
   if before==after:continue
   changed+=1
   untouched=untouched and absf(before.y-.06)<.001 and after.y==0 and before.x==after.x and before.z==after.z and absf(before.x-1.8)<.091 and absf(before.z+.9)<.051
 check(changed>=4 and untouched,"Only the floating cleat base extends down to the pier deck")
 check(uv_intact,"UVs and indices stay exact; normal/tangent changes remain below packing precision")
 Shore.ground_pier_cleat(scene)
 check(node.mesh==repaired,"Repair is idempotent for grounded assets")
 scene.free()
 if "--capture" in OS.get_cmdline_user_args():
  var g=load("res://scenes/main.tscn").instantiate();root.add_child(g)
  await create_timer(.4).timeout
  g.set_process(false);g.motor.set_physics_process(false);g.fishing_feedback.set_process(false)
  g._select_location("lake_pier",false);g.hud.hide();g.rod.hide();g.avatar.hide();g.fish_guide.hide()
  g.head.global_position=Vector3(1.2,.18,-.25);g.head.look_at(Vector3(1.8,.1,-.9))
  var target:MeshInstance3D=g.foreground.find_child("lake_pier_BakedForeground",true,false)
  for version in ["before","after"]:
   target.mesh=original if version=="before" else repaired
   for frame in 12:await process_frame
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://test-results/fishing-update/pier-cleat-"+version+".png")
  g.queue_free();await process_frame
 print("PIER_CLEAT_RESULT ",failures);quit(0 if failures.is_empty() else 1)
