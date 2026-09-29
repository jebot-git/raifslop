extends SceneTree
func _initialize()->void:run.call_deferred()
func run()->void:
 for id in OS.get_cmdline_user_args():
  var uvfile:="res://source/minigolf/lighting/"+id+"-uv2.json"
  var records:Array=JSON.parse_string(FileAccess.get_file_as_string(uvfile))
  var world=preload("res://scripts/minigolf/world.gd").new();world.set_meta("skip_lightmap",true);root.add_child(world);world.setup(id)
  var data=preload("res://scripts/minigolf/lightmap_data.gd").new()
  var geometry=preload("res://scripts/minigolf/lightmaps.gd").nodes(world)
  var paths:Array=[];var mapping:Dictionary={}
  for record in records:
   if not mapping.has(record.path):paths.append(record.path);mapping[record.path]={}
   mapping[record.path][int(record.surface)]=record.uv2
  assert(paths.size()==geometry.size(),"Bake mesh count mismatch")
  for i in geometry.size():
   var node:MeshInstance3D=geometry[i];var mesh:=ArrayMesh.new()
   data.signatures.append(preload("res://scripts/minigolf/lightmaps.gd").signature(world,node))
   for surface in node.mesh.get_surface_count():
    var original:Array=node.mesh.surface_get_arrays(surface)
    var indices:PackedInt32Array=original[Mesh.ARRAY_INDEX] if original[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
    if indices.is_empty():
     for index in original[Mesh.ARRAY_VERTEX].size():indices.append(index)
    var uv:Array=mapping[paths[i]][surface];assert(uv.size()==indices.size(),"Bake triangle count mismatch")
    var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX)
    for slot in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_COLOR,Mesh.ARRAY_TEX_UV]:
     if original[slot]==null:continue
     var expanded=original[slot].duplicate();expanded.resize(0)
     for index in indices:expanded.append(original[slot][index])
     arrays[slot]=expanded
    if original[Mesh.ARRAY_TANGENT]!=null and not original[Mesh.ARRAY_TANGENT].is_empty():
     var tangents:=PackedFloat32Array()
     for index in indices:
      for component in 4:tangents.append(original[Mesh.ARRAY_TANGENT][index*4+component])
     arrays[Mesh.ARRAY_TANGENT]=tangents
    var coords:=PackedVector2Array()
    for value in uv:coords.append(Vector2(value[0],value[1]))
    arrays[Mesh.ARRAY_TEX_UV2]=coords
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
    mesh.surface_set_material(surface,node.mesh.surface_get_material(surface))
   data.meshes.append(mesh)
  data.irradiance=load("res://assets/minigolf/lighting/"+id+"_irradiance.exr")
  data.occlusion=load("res://assets/minigolf/lighting/"+id+"_ao.png")
  assert(data.irradiance!=null and data.occlusion!=null)
  assert(ResourceSaver.save(data,"res://assets/minigolf/lighting/"+id+".res",ResourceSaver.FLAG_COMPRESS)==OK)
  print("MINIGOLF_LIGHTMAP_COMPILED ",id," meshes=",data.meshes.size());world.free();await process_frame
 quit()
