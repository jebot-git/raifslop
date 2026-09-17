extends SceneTree
var checks:=0
var failures:Array=[]
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize():run.call_deferred()
func run():
 var g=load("res://scenes/main.tscn").instantiate();root.add_child(g)
 await create_timer(.3).timeout
 g.set_process(false);g.motor.set_physics_process(false)
 g._select_location("lake_pier",false)
 var bridge_faces:=0;var apron_faces:=0
 for node in g.foreground.find_children("*","MeshInstance3D",true,false):
  if not node.visible:continue
  for surface in node.mesh.get_surface_count():
   var mat:Material=node.mesh.surface_get_material(surface)
   if not mat or not mat.resource_name.begins_with("FG_concrete"):continue
   var arrays=node.mesh.surface_get_arrays(surface)
   var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
   var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
   for i in range(0,indices.size(),3):
    var apron:=true;var bridge:=true
    for index in indices.slice(i,i+3):
     var p:Vector3=vertices[index]
     apron=apron and ((absf(p.y+.1)<.005 and p.z>=5.79) or (absf(p.y+1.25)<.005 and absf(p.z-4)<.005))
     bridge=bridge and p.x>=-2.11 and p.x<=.11 and p.z>=6.09 and p.z<=12.21 and absf(p.y)<.005
    if apron:apron_faces+=1
    if bridge:bridge_faces+=1
 check(apron_faces==0,"Old stretched harbour apron removed")
 check(bridge_faces>=2,"Connecting bridge deck retained")
 check(g.foreground.get_node("RearParallax").material_override.get_shader_parameter("rear_harbour_basin"),"Lower harbour projection yields to real water")
 var folder:="res://test-results/lake-pier-basin";DirAccess.make_dir_recursive_absolute(folder)
 var capture=preload("res://tests/xr_capture.gd").new()
 if g.xr:
  var compositor:=Compositor.new();compositor.compositor_effects=[capture];g.head.compositor=compositor
 if "--capture" in OS.get_cmdline_user_args():
  for item in [g.hud,g.rod,g.avatar,g.fish_guide,g.rod_status,g.bobber,g.aim_marker]:item.hide()
  g.line_mesh.clear_surfaces()
  for view in [["rear",Vector3(0,1.65,.65),PI],["rear_left",Vector3(0,1.65,.65),2.3],["bridge",Vector3(-1,1.65,6),2.7],["seated",Vector3(0,1.1,.65),2.3]]:
   if g.xr:
    g.origin.global_basis=Basis(Vector3.UP,view[2]-g.head.rotation.y)
    g.origin.global_position=view[1]-g.origin.global_basis*g.head.position
   else:
    g.head.global_position=view[1];g.head.rotation=Vector3(-.17,view[2],0)
   for i in 12:await process_frame
   if g.xr:
    capture.request_capture(view[0])
    for i in 120:
     await process_frame
     if capture.completed==view[0]:break
    check(capture.completed==view[0] and capture.results.size()==2,"Two-eye harbour capture "+view[0])
    for eye in capture.results.size():
     var frame:Image=capture.results[eye];frame.convert(Image.FORMAT_RGBA8);frame.linear_to_srgb()
     frame.save_png(folder+"/"+view[0]+"_eye%d.png"%eye)
   else:
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(folder+"/"+view[0]+".png")
 g._select_location("lakeside",false)
 check(not g.water_material.get_shader_parameter("replace_near_jetty"),"Harbour coverage clears on travel")
 print("LAKE_PIER_BASIN_RESULT ",checks," checks, ",failures)
 g.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
