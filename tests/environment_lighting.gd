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
 for entry in g.Locations.CATALOG:
  g._select_location(entry.id,false)
  var meshes=g.foreground.find_children("*BakedForeground*","MeshInstance3D",true,false)
  check(meshes.size()==1,"Location loads its baked foreground: "+entry.id)
  if meshes.is_empty():continue
  var mesh: MeshInstance3D=meshes[0]
  var valid_uv:=true;var normals:=false
  for i in range(mesh.mesh.get_surface_count()):
   var arrays=mesh.mesh.surface_get_arrays(i)
   valid_uv=valid_uv and arrays[Mesh.ARRAY_TEX_UV2]!=null and arrays[Mesh.ARRAY_TEX_UV2].size()==arrays[Mesh.ARRAY_VERTEX].size()
   var mat=mesh.get_active_material(i)
   check(mat is ShaderMaterial and mat.get_shader_parameter("irradiance_tex")!=null and mat.get_shader_parameter("occlusion_tex")!=null,"Baked material atlases bound: "+entry.id+"/"+str(i))
   normals=normals or mat.get_shader_parameter("normal_tex")!=null
  check(valid_uv,"Atlas coordinates survive GLB import: "+entry.id)
  check(normals,"Photographed normal detail present: "+entry.id)
  var ao: Image=load("res://assets/textures/lighting/"+entry.id+"_ao.png").get_image()
  if ao.is_compressed():ao.decompress()
  var lo:=1.;var hi:=0.
  for y in range(0,ao.get_height(),8):
   for x in range(0,ao.get_width(),8):
    var v=ao.get_pixel(x,y).r;lo=minf(lo,v);hi=maxf(hi,v)
  check(lo<.8 and hi>.95,"Bake contains contact occlusion and open sky: "+entry.id)
  check(g.location_sun.light_energy<=.551 and g.location_sun.shadow_enabled==(g.shadow_policy.mode=="dynamic"),"Subdued sun follows shadow preference: "+entry.id)
 var prepared:=0
 for mesh in g.avatar.find_children("*","MeshInstance3D",true,false):
  for i in range(mesh.mesh.get_surface_count()):
   var mat=mesh.get_active_material(i)
   if mat and mat.has_meta("fishing_lighting_prepared"):prepared+=1
 check(prepared>0,"Default avatar uses FPSloppa lighting policy")
 check(g.avatar.mouth.binds.slice(0,5).all(func(b):return not b.is_empty()),"Lighting keeps vowel expression bindings")
 check(not g.avatar.eyes.binds[4].is_empty() and not g.avatar.eyes.binds[5].is_empty(),"Lighting keeps blink bindings")
 g.queue_free();await process_frame;await process_frame
 print("ENVIRONMENT_LIGHTING_RESULT ",failures);quit(0 if failures.is_empty() else 1)
