extends RefCounted
## Remove superseded decorative triangles while retaining collider and atlas data.
static func apply(root:Node3D,id:String):
 var removed:=0
 for node in root.find_children("*","MeshInstance3D",true,false):
  var rebuilt:=ArrayMesh.new()
  for surface in node.mesh.get_surface_count():
   var mat:Material=node.mesh.surface_get_material(surface)
   var label:String=mat.resource_name if mat else ""
   var arrays:Array=node.mesh.surface_get_arrays(surface)
   var candidate:bool=(id=="lake_pier" and label.begins_with("FG_concrete")) or label.begins_with("FG_rope") or (id=="lakeside" and (label.begins_with("FG_grass") or label.begins_with("FG_reed") or label.begins_with("FG_wood_end"))) or (id=="fish_hoek_beach" and label.begins_with("FG_weathered"))
   if not candidate:
    rebuilt.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
    rebuilt.surface_set_material(rebuilt.get_surface_count()-1,mat)
    continue
   var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
   var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
   if indices.is_empty():
    for i in vertices.size():indices.append(i)
   var kept:=PackedInt32Array()
   for i in range(0,indices.size(),3):
    var a:Vector3=vertices[indices[i]];var b:Vector3=vertices[indices[i+1]];var c:Vector3=vertices[indices[i+2]]
    var retire:bool=label.begins_with("FG_rope") and maxf(a.y,maxf(b.y,c.y))<.1
    retire=retire or (id=="lakeside" and (label.begins_with("FG_grass") or label.begins_with("FG_reed")))
    # The old seed heads share a material with below-deck support timbers.
    retire=retire or (id=="lakeside" and label.begins_with("FG_wood_end") and minf(a.y,minf(b.y,c.y))>.05)
    # Primitive inland Tidal Strand trunks, beyond the rear rope boundary.
    retire=retire or (id=="fish_hoek_beach" and label.begins_with("FG_weathered") and minf(a.z,minf(b.z,c.z))>11.0)
    # The old flat mainland apron fills the harbour basin beside the bridge.
    # Its regular grid has unique elevations; keep all authored quay/bridge faces.
    if id=="lake_pier" and label.begins_with("FG_concrete"):
     var apron:=true
     for p in [a,b,c]:
      apron=apron and ((absf(p.y+.1)<.005 and p.z>=5.79) or (absf(p.y+1.25)<.005 and absf(p.z-4.0)<.005))
     retire=retire or apron
    if retire:removed+=1
    else:kept.append_array(indices.slice(i,i+3))
   if kept.is_empty():continue
   arrays[Mesh.ARRAY_INDEX]=kept
   rebuilt.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
   rebuilt.surface_set_material(rebuilt.get_surface_count()-1,mat)
  if rebuilt.get_surface_count()>0:node.mesh=rebuilt
  else:node.hide()
 root.set_meta("retired_detail_triangles",removed)
