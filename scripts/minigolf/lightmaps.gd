extends RefCounted
static func nodes(world:Node3D)->Array[MeshInstance3D]:
 var result:Array[MeshInstance3D]=[]
 for node in world.find_children("*","MeshInstance3D",true,false):
  if node in world.lost_balls or node.name=="CourseBankExtension" or node.get_meta("skip_lightmap",false):continue
  result.append(node)
 return result
static func signature(world:Node3D,node:MeshInstance3D)->int:
 return hash([world.global_transform.affine_inverse()*node.global_transform,node.mesh.get_faces()])
static func apply(world:Node3D)->void:
 if world.get_meta("skip_lightmap",false):return
 var path:="res://assets/minigolf/lighting/"+str(world.course.id)+".res"
 if not ResourceLoader.exists(path):return
 var data=load(path)
 var geometry:=nodes(world)
 if geometry.size()!=data.meshes.size():push_warning("Minigolf bake geometry changed: "+str(world.course.id));return
 for i in geometry.size():
  if signature(world,geometry[i])!=data.signatures[i]:push_warning("Minigolf bake is stale: "+str(world.course.id));return
 var materials:Dictionary={}
 for i in geometry.size():
  var node:MeshInstance3D=geometry[i]
  var originals:Array[Material]=[]
  for surface in node.mesh.get_surface_count():originals.append(node.get_active_material(surface))
  node.mesh=data.meshes[i]
  for surface in originals.size():
   var original:Material=originals[surface]
   # Subpixel leaf/stalk islands cannot carry a stable atlas sample. Keep
   # thin foliage on the scene lighting; it still casts into the static bake.
   if original is StandardMaterial3D:
    var name:String=original.resource_name.to_lower()
    if "grass" in name or "leaves" in name or "petals" in name or "reed" in name or "seed heads" in name:
     node.set_surface_override_material(surface,original);continue
   if not materials.has(original):
    var mat:ShaderMaterial
    if original==world.green or original==world.wood:
     mat=original.duplicate();mat.set_shader_parameter("has_lightmap",true)
    elif original is StandardMaterial3D:
     mat=ShaderMaterial.new();mat.shader=preload("res://shaders/minigolf_baked.gdshader")
     mat.set_shader_parameter("base_color",original.albedo_color)
     mat.set_shader_parameter("color_texture",original.albedo_texture)
     mat.set_shader_parameter("has_color_texture",original.albedo_texture!=null)
     mat.set_shader_parameter("triplanar",original.uv1_triplanar)
     mat.set_shader_parameter("texture_scale",original.uv1_scale)
     mat.set_shader_parameter("texture_offset",original.uv1_offset)
    else:continue
    mat.set_shader_parameter("irradiance",data.irradiance);mat.set_shader_parameter("occlusion",data.occlusion)
    materials[original]=mat
   node.set_surface_override_material(surface,materials[original])
 world.set_meta("lightmap_applied",true)
