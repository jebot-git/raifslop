extends SceneTree
func _initialize():run.call_deferred()
func run():
 var shore:=preload("res://scripts/shore.gd").create("lakeside")
 root.add_child(shore)
 var rocks:=shore.find_child("NaturalShoreBoulders",true,false)
 var records:Array=[]
 for node in rocks.get_children():
  for surface in node.mesh.get_surface_count():
   var arrays:Array=node.mesh.surface_get_arrays(surface)
   var points:Array=[];var uvs:Array=[];var faces:Array=[]
   var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
   var coords:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
   var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
   if indices.is_empty():
    for i in vertices.size():indices.append(i)
   for i in vertices.size():
    var p:Vector3=node.global_transform*vertices[i]
    points.append([p.x,-p.z,p.y]);uvs.append([coords[i].x,1.0-coords[i].y])
   for i in range(0,indices.size(),3):faces.append([indices[i+2],indices[i+1],indices[i]])
   records.append({"name":node.name,"vertices":points,"uv":uvs,"faces":faces})
 var file:=FileAccess.open("res://source/lakeside_shore_rocks.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(records));file.close()
 print("SHORE_ROCK_EXPORT ",records.size()," meshes; ",rocks.get_parent().get_meta("replaced_shore_rocks")," old rocks removed")
 shore.free();quit()
