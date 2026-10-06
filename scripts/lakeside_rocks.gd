extends RefCounted
## Replace the 24 seven-sided shore kerbs with eight irregular scanned boulders.
static func apply(root:Node3D):
 if "--reference-lakeside-rocks" in OS.get_cmdline_user_args():return
 var removed:=0
 for node in root.find_children("*","MeshInstance3D",true,false):
  var rebuilt:=ArrayMesh.new()
  for surface in node.mesh.get_surface_count():
   var arrays:Array=node.mesh.surface_get_arrays(surface)
   var mat:Material=node.mesh.surface_get_material(surface)
   if mat and mat.resource_name.begins_with("FG_stone"):
    var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
    var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
    if indices.is_empty():
     for i in vertices.size():indices.append(i)
    # Weld position keys only for connectivity; retain original normals and UVs.
    var touching:Dictionary={};var keys:Array=[]
    for i in range(0,indices.size(),3):
     var triangle:Array=[]
     for j in 3:
      var p:Vector3=vertices[indices[i+j]]
      var key:=Vector3i(roundi(p.x*10000),roundi(p.y*10000),roundi(p.z*10000))
      triangle.append(key)
      if not touching.has(key):touching[key]=[]
      touching[key].append(i/3)
     keys.append(triangle)
    var seen:Dictionary={};var retired:Dictionary={}
    for seed in keys.size():
     if seen.has(seed):continue
     var queue:Array=[seed];seen[seed]=true;var cursor:=0
     var box:=AABB(vertices[indices[seed*3]],Vector3.ZERO)
     while cursor<queue.size():
      var current:int=queue[cursor];cursor+=1
      for j in 3:box=box.expand(vertices[indices[current*3+j]])
      for key in keys[current]:
       for neighbor in touching[key]:
        if not seen.has(neighbor):seen[neighbor]=true;queue.append(neighbor)
     if box.get_center().z < -2.15 and absf(box.get_center().x)<8.5:
      removed+=1
      for triangle in queue:retired[triangle]=true
    var kept:=PackedInt32Array()
    for i in range(0,indices.size(),3):
     if not retired.has(i/3):kept.append_array(indices.slice(i,i+3))
    if kept.is_empty():continue
    arrays[Mesh.ARRAY_INDEX]=kept
   rebuilt.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
   rebuilt.surface_set_material(rebuilt.get_surface_count()-1,mat)
  if rebuilt.get_surface_count()>0:node.mesh=rebuilt
  else:node.hide()
 root.set_meta("replaced_shore_rocks",removed)
 var source:Node3D=load("res://assets/environment/rivers/river_boulder.glb").instantiate()
 var original:MeshInstance3D=source.find_children("*","MeshInstance3D",true,false)[0]
 var mesh:Mesh=original.mesh
 var material:=ShaderMaterial.new();material.shader=load("res://assets/environment/rivers/rock.gdshader")
 material.set_shader_parameter("albedo_tex",original.get_active_material(0).albedo_texture)
 material.set_shader_parameter("occlusion_tex",load("res://assets/environment/rivers/rock_ao.png"))
 material.set_shader_parameter("normal_tex",load("res://assets/models/locations/lit/gray_pier_gravelly_sand_nor_gl.jpg"))
 source.free()
 var rocks:=Node3D.new();rocks.name="NaturalShoreBoulders";root.add_child(rocks)
 var xs:=[-7.0,-5.7,-3.8,-1.2,1.6,3.4,5.6,7.2]
 var rng:=RandomNumberGenerator.new();rng.seed=8347
 for i in xs.size():
  var rock:=MeshInstance3D.new();rock.name="ShoreBoulder"+str(i);rock.mesh=mesh;rock.material_override=material
  rocks.add_child(rock)
  rock.rotation=Vector3(rng.randf_range(-.12,.12),rng.randf_range(-PI,PI),rng.randf_range(-.1,.1))
  var width:float=rng.randf_range(.85,1.35)
  rock.scale=Vector3(width,rng.randf_range(.40,.64),rng.randf_range(.65,1.05)) / maxf(mesh.get_aabb().size.x,.01)
  var bounds: AABB=rock.transform*mesh.get_aabb()
  rock.position=Vector3(xs[i],-.20-bounds.position.y,-2.58+rng.randf_range(-.2,.08))
 # Existing continuous shore boundary remains, independent of decorative gaps.
