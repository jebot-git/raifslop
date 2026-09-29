extends SceneTree
## Exact static course geometry for UV2 irradiance baking; no gameplay changes.
const Catalog=preload("res://scripts/minigolf/catalog.gd")
func _initialize()->void:run.call_deferred()
func run()->void:
 DirAccess.make_dir_recursive_absolute("res://source/minigolf/lighting")
 for id in Catalog.ALL:
  var world=preload("res://scripts/minigolf/world.gd").new();root.add_child(world);world.setup(id)
  var records:Array=[]
  for node in world.find_children("*","MeshInstance3D",true,false):
   if node in world.lost_balls or node.name=="CourseBankExtension":continue
   var transform:Transform3D=world.global_transform.affine_inverse()*node.global_transform
   for surface in node.mesh.get_surface_count():
    var arrays:Array=node.mesh.surface_get_arrays(surface)
    var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
    var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
    if indices.is_empty():
     for i in vertices.size():indices.append(i)
    var mat:Material=node.get_active_material(surface)
    var color:=Color(.4,.4,.4)
    if mat is StandardMaterial3D:color=mat.albedo_color
    elif mat==world.green:color=Color(world.course.turf)
    elif mat==world.wood:color=Color(world.palette.deck)
    var points:Array=[];var faces:Array=[]
    for vertex in vertices:
     var p:Vector3=transform*vertex;points.append([p.x,-p.z,p.y])
    for i in range(0,indices.size(),3):faces.append([indices[i+2],indices[i+1],indices[i]])
    records.append({"path":str(world.get_path_to(node)),"surface":surface,"vertices":points,"faces":faces,"color":[color.r,color.g,color.b,1]})
  var file=FileAccess.open("res://source/minigolf/lighting/"+id+"-geometry.json",FileAccess.WRITE);file.store_string(JSON.stringify(records));file.close()
  print("MINIGOLF_BAKE_GEOMETRY ",id," ",records.size());world.free();await process_frame
 quit()
