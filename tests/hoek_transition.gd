extends SceneTree
var checks:=0
var failures:Array=[]
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize():run.call_deferred()
func sand_arrays(root:Node3D)->Array:
 for node in root.find_children("*","MeshInstance3D",true,false):
  for surface in node.mesh.get_surface_count():
   var mat:Material=node.mesh.surface_get_material(surface)
   if mat and mat.resource_name.begins_with("FG_sand"):return node.mesh.surface_get_arrays(surface)
 return []
func run():
 var g=load("res://scenes/main.tscn").instantiate();root.add_child(g)
 await create_timer(.3).timeout
 g.set_process(false);g.motor.set_physics_process(false)
 g._select_location("fish_hoek_beach",false)
 var opaque_blend:=false
 for node in g.foreground.find_children("*BakedForeground*","MeshInstance3D",true,false):
  for surface in node.mesh.get_surface_count():
   var source:Material=node.mesh.surface_get_material(surface)
   if source and source.resource_name.begins_with("FG_sand"):
    var mat:ShaderMaterial=node.get_active_material(surface)
    opaque_blend=mat.next_pass==null and mat.get_shader_parameter("ground_projection")==true
 check(opaque_blend,"Sand photo blend writes opaque depth before water")
 var raw=load("res://assets/models/locations/lit/fish_hoek_beach.glb").instantiate()
 var before:Array=sand_arrays(raw);var after:Array=sand_arrays(g.foreground)
 check(before[Mesh.ARRAY_TEX_UV]==after[Mesh.ARRAY_TEX_UV] and before[Mesh.ARRAY_TEX_UV2]==after[Mesh.ARRAY_TEX_UV2],"Sand albedo and lightmap UVs retained")
 var original:PackedVector3Array=before[Mesh.ARRAY_VERTEX];var updated:PackedVector3Array=after[Mesh.ARRAY_VERTEX]
 var moved:=0;var protected:=true;var continuous:=true
 for i in original.size():
  if original[i].x>=-10.0:protected=protected and original[i].is_equal_approx(updated[i])
  if original[i].z>=10.0:protected=protected and original[i].is_equal_approx(updated[i])
  if not original[i].is_equal_approx(updated[i]):moved+=1
  continuous=continuous and is_equal_approx(original[i].x,updated[i].x) and is_equal_approx(original[i].y,updated[i].y)
 check(moved>0 and protected,"Only the outer left sand apron extends")
 check(continuous,"Sand extension retains elevations and a continuous mesh")
 check(g.water_material.get_shader_parameter("align_beach_projection"),"Hoek water and ground share photographic anchor")
 var rear=g.foreground.get_node("RearParallax")
 check(rear.get_meta("azimuth_range_degrees").x==-125.0,"Parallax wraps around the left seawall")
 raw.free()
 var folder:="res://test-results/hoek-transition";DirAccess.make_dir_recursive_absolute(folder)
 var capture=preload("res://tests/xr_capture.gd").new()
 if g.xr:
  var compositor:=Compositor.new();compositor.compositor_effects=[capture];g.head.compositor=compositor
 if "--capture" in OS.get_cmdline_user_args():
  for item in [g.hud,g.rod,g.avatar,g.fish_guide,g.rod_status,g.bobber,g.aim_marker]:item.hide()
  g.line_mesh.clear_surfaces()
  for view in [["left",Vector3(0,1.65,.65),1.15],["left_edge",Vector3(-6,1.65,.65),1.15],["left_seated",Vector3(-3,1.1,.65),1.15],["rear_left",Vector3(-6,1.65,5),2.1]]:
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
    check(capture.completed==view[0] and capture.results.size()==2,"Two-eye Hoek capture "+view[0])
    for eye in capture.results.size():
     var frame:Image=capture.results[eye];frame.convert(Image.FORMAT_RGBA8);frame.linear_to_srgb()
     frame.save_png(folder+"/"+view[0]+"_eye%d.png"%eye)
   else:
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(folder+"/"+view[0]+".png")
 g._select_location("lakeside",false)
 check(not g.water_material.get_shader_parameter("align_beach_projection"),"Hoek projection mode clears on travel")
 print("HOEK_TRANSITION_RESULT ",checks," checks, ",failures)
 g.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
