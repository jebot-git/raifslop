extends RefCounted
## Metre-scale Blender props and shared scan pebbles. Cosmetic, outside casting lanes.
const DIR="res://assets/environment/shore_details/authored/"
static var meshes:Dictionary={}
static func mesh_for(path:String)->Mesh:
 if meshes.has(path):return meshes[path]
 var source:Node3D=load(path).instantiate()
 var node:MeshInstance3D=source.find_children("*","MeshInstance3D",true,false)[0]
 var st:=SurfaceTool.new();st.create_from(node.mesh,0);st.generate_tangents()
 var mesh:=st.commit();meshes[path]=mesh;source.free();return mesh
static func ground(id:String,x:float,z:float,terrain:PackedVector3Array=PackedVector3Array())->float:
 var height:float=-INF
 for i in range(0,terrain.size(),3):
  var hit=Geometry3D.ray_intersects_triangle(Vector3(x,10,z),Vector3.DOWN,terrain[i],terrain[i+1],terrain[i+2])
  if hit is Vector3:height=maxf(height,hit.y)
 if is_finite(height):return height
 return load("res://scripts/river_foreground.gd").ground_height(x,z,false) if preload("res://scripts/fly_fishing.gd").river(id) else 0.0
static func ground_triangles(parent:Node3D)->PackedVector3Array:
 var terrain:=PackedVector3Array()
 for node in parent.find_children("*","MeshInstance3D",true,false):
  var transform:Transform3D=node.transform
  var ancestor:Node=node.get_parent()
  while ancestor!=parent and ancestor is Node3D:
   transform=ancestor.transform*transform;ancestor=ancestor.get_parent()
  for surface in node.mesh.get_surface_count():
   var mat:Material=node.mesh.surface_get_material(surface)
   if not mat or not mat.resource_name.begins_with("FG_sand"):continue
   var arrays:Array=node.mesh.surface_get_arrays(surface)
   var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
   var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
   if indices.is_empty():
    for p in vertices:terrain.append(transform*p)
   else:
    for index in indices:terrain.append(transform*vertices[index])
 return terrain
static func add_to(parent:Node3D,id:String)->void:
 var root:=Node3D.new();root.name="ShoreDressing";parent.add_child(root)
 var terrain:=ground_triangles(parent)
 var pier:bool=id in ["lake_pier","gray_pier","bell_park_pier","simons_town_rocks"]
 var sites:Array
 if pier:
  sites={"lake_pier":[Vector3(-1.45,0,-.45)],"gray_pier":[Vector3(1.45,0,-4.8)],"bell_park_pier":[Vector3(2.0,0,3.5)],"simons_town_rocks":[Vector3(3.0,0,-1.8)]}[id]
 else:
  var width:float=6.0 if id in ["blouberg_sunrise_2","fish_hoek_beach"] else 4.5
  sites=[Vector3(-width,0,1.8),Vector3(width,0,4.6)]
 var rng:=RandomNumberGenerator.new();rng.seed=abs(id.hash())+217
 var mat:=ShaderMaterial.new();mat.shader=load(DIR+"fibres.gdshader")
 mat.set_shader_parameter("timber",load("res://assets/models/locations/lit/secluded_beach_weathered_timber_Diffuse.jpg"));mat.set_shader_parameter("rope",pier)
 var mesh:=mesh_for(DIR+("MooringCoil.glb" if pier else "ForkedDriftwood.glb"))
 var multi:=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.mesh=mesh;multi.instance_count=sites.size()
 var shadows:=MultiMesh.new();shadows.transform_format=MultiMesh.TRANSFORM_3D
 var plane:=PlaneMesh.new();plane.size=Vector2.ONE;shadows.mesh=plane;shadows.instance_count=sites.size()
 var footprints:Array=[]
 var occupied:Array=plant_bounds(parent)+fixture_bounds(id)
 var exclusions:Array=[]
 for i in sites.size():
  var at:Vector3=sites[i];var size:float=.85 if pier else rng.randf_range(.7,1.15)
  var yaw:float=rng.randf_range(-.65,.65)
  var basis:=Basis(Vector3.UP,yaw).scaled_local(Vector3.ONE*size)
  var local_box:AABB=Transform3D(basis,Vector3.ZERO)*mesh.get_aabb()
  var area:=Rect2(Vector2(local_box.position.x,local_box.position.z),Vector2(local_box.size.x,local_box.size.z)).grow(.16)
  if not pier:
   at=find_clear_site(at,area,occupied)
   if not at.is_finite():
    multi.visible_instance_count=i;shadows.visible_instance_count=i;break
  var reserved:=Rect2(area.position+Vector2(at.x,at.z),area.size)
  occupied.append(reserved);exclusions.append(reserved)
  var surface:float=ground(id,at.x,at.z,terrain)
  at.y=surface-mesh.get_aabb().position.y*size-(.003 if pier else .018)
  multi.set_instance_transform(i,Transform3D(Basis(Vector3.UP,yaw).scaled_local(Vector3.ONE*size),at))
  shadows.set_instance_transform(i,Transform3D(Basis(Vector3.UP,yaw).scaled_local(Vector3(.95 if pier else 2.3,1,.95 if pier else .65)*size),Vector3(at.x,surface+.004,at.z)))
  footprints.append(at)
 batch(root,"MooringRope" if pier else "Driftwood",multi,mat)
 var shadow_mat:=ShaderMaterial.new();shadow_mat.shader=load(DIR+"contact.gdshader")
 batch(root,"ContactShadows",shadows,shadow_mat)
 root.set_meta("prop_bases",footprints)
 root.set_meta("prop_footprints",exclusions)
 if not pier:add_pebbles(root,id,rng,occupied,terrain)
 add_lilies(root,id,rng)
static func batch(root:Node3D,label:String,multi:MultiMesh,mat:Material):
 var visual:=MultiMeshInstance3D.new();visual.name=label;visual.multimesh=multi;visual.material_override=mat
 visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;root.add_child(visual)
static func add_pebbles(root:Node3D,id:String,rng:RandomNumberGenerator,occupied:Array,terrain:PackedVector3Array=PackedVector3Array()):
 var mesh:=mesh_for("res://assets/environment/rivers/river_boulder.glb")
 var mat:=ShaderMaterial.new();mat.shader=load("res://assets/environment/rivers/rock.gdshader")
 mat.set_shader_parameter("albedo_tex",load("res://assets/environment/rivers/river_boulder_coastal_granite_base.png"))
 mat.set_shader_parameter("albedo_gain",.55)
 mat.set_shader_parameter("occlusion_tex",load("res://assets/environment/rivers/rock_ao.png"))
 mat.set_shader_parameter("normal_tex",load("res://assets/models/locations/lit/gray_pier_gravelly_sand_nor_gl.jpg"))
 var multi:=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.mesh=mesh;multi.instance_count=72
 var bases:Array=[]
 var pebble_areas:Array=[]
 for i in multi.instance_count:
  var side:float=-1.0 if i%2==0 else 1.0
  var width:float=6.0 if id in ["blouberg_sunrise_2","fish_hoek_beach"] else 4.5
  # Drift deposits form uneven patches along the bank, independently of logs.
  var centre:=Vector3(side*(width+rng.randf_range(-.4,.4)),0,-.65 if i%5<3 else 6.1)
  if i%7==0:centre.z=rng.randf_range(.2,5.7)
  var size:=Vector3(rng.randf_range(.06,.23),rng.randf_range(.04,.10),rng.randf_range(.07,.20))
  var radius:float=maxf(mesh.get_aabb().size.x*size.x,mesh.get_aabb().size.z*size.z)*.6+.025
  var at:Vector3=centre
  var accepted:=false
  for attempt in 200:
   at=centre+Vector3(rng.randfn(0,.75),0,rng.randfn(0,1.0))
   var area:=Rect2(Vector2(at.x-radius,at.z-radius),Vector2.ONE*radius*2)
   if absf(at.x)<2.6 or overlaps(area,occupied):continue
   occupied.append(area);pebble_areas.append(area);accepted=true;break
  if not accepted:
   multi.visible_instance_count=i;break
  at.y=ground(id,at.x,at.z,terrain)-mesh.get_aabb().position.y*size.y-.012
  multi.set_instance_transform(i,Transform3D(Basis(Vector3.UP,rng.randf_range(-PI,PI)).scaled_local(size),at))
  bases.append(at)
 batch(root,"ShorePebbles",multi,mat);root.set_meta("pebble_bases",bases);root.set_meta("pebble_footprints",pebble_areas)
static func add_lilies(root:Node3D,id:String,rng:RandomNumberGenerator):
 if id not in ["lakeside","gray_pier","bell_park_pier"]:return
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 # A shallow cupped leaf with a geometric slit, not a transparent quad.
 for i in 22:
  var a:float=.22+i*(TAU-.44)/22.0;var b:float=.22+(i+1)*(TAU-.44)/22.0
  for vertex in [Vector3(0,.004,0),Vector3(cos(a)*.5,0,sin(a)*.46),Vector3(cos(b)*.5,0,sin(b)*.46)]:
   st.set_normal(Vector3.UP);st.set_uv(Vector2(vertex.x,vertex.z)+Vector2.ONE*.5);st.add_vertex(vertex)
 var multi:=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.use_custom_data=true;multi.mesh=st.commit();multi.instance_count=27
 var bases:Array=[];var areas:Array=[]
 for i in multi.instance_count:
  var centre:=Vector3(-4.5,-.333,-6.0) if id=="lakeside" else Vector3(3.8,-.333,-3.0) if id=="gray_pier" else Vector3(-4.6,-.333,-5.5)
  var size:float=rng.randf_range(.19,.36)
  var at:Vector3=centre;var accepted:=false
  for attempt in 200:
   var angle:float=rng.randf()*TAU;var radius:float=sqrt(rng.randf())*1.15
   at=centre+Vector3(cos(angle)*radius,0,sin(angle)*radius*.65)
   var area:=Rect2(Vector2(at.x,at.z)-Vector2.ONE*size*.55,Vector2.ONE*size*1.1)
   if overlaps(area,areas):continue
   areas.append(area);accepted=true;break
  if not accepted:
   multi.visible_instance_count=i;break
  multi.set_instance_transform(i,Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled_local(Vector3(size,1,size)),at))
  multi.set_instance_custom_data(i,Color(rng.randf_range(.2,.95),0,0,1));bases.append(at)
 root.set_meta("lily_footprints",areas)
 var mat:=ShaderMaterial.new();mat.shader=load(DIR+"lily.gdshader")
 batch(root,"WaterLilies",multi,mat);root.set_meta("lily_bases",bases)

static func plant_bounds(parent:Node3D)->Array:
 var areas:Array=[]
 # Ground-level wrack cutouts are existing decorations too, not free space.
 for node in parent.find_children("TideWrack*","MeshInstance3D",true,false):
  var transform:Transform3D=node.transform
  var ancestor:Node=node.get_parent()
  while ancestor!=parent and ancestor is Node3D:
   transform=ancestor.transform*transform;ancestor=ancestor.get_parent()
  var box:AABB=transform*node.mesh.get_aabb()
  areas.append(Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z)).grow(.06))
 for node in parent.find_children("*","Node3D",true,false):
  if not node.has_meta("plant_footprints"):continue
  for value in node.get_meta("plant_footprints"):
   if value is Rect2:areas.append(value)
   elif value is Dictionary:
    var at:Vector3=value.at;var radius:float=value.radius+.05
    areas.append(Rect2(Vector2(at.x-radius,at.z-radius),Vector2.ONE*radius*2))
 return areas
static func overlaps(area:Rect2,occupied:Array)->bool:
 for other in occupied:
  if area.intersects(other):return true
 return false
static func find_clear_site(at:Vector3,local_area:Rect2,occupied:Array)->Vector3:
 for offset_z in [0.0,1.2,2.4,3.6]:
  for offset_x in [0.0,-.3,.3,-.6,.6,-.9,.9,-1.2,1.2]:
   var candidate:=at+Vector3(offset_x,0,offset_z)
   var area:=Rect2(local_area.position+Vector2(candidate.x,candidate.z),local_area.size)
   if minf(absf(area.position.x),absf(area.end.x))<2.5:continue
   if not overlaps(area,occupied):return candidate
 push_error("No clear shore prop placement at "+str(at))
 return Vector3(INF,INF,INF)

static func fixture_bounds(id:String)->Array:
 var records=JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/locations/manifest.json"))
 var areas:Array=[]
 if not records.has(id):return areas
 for entry in records[id].colliders:
  if not entry.get("role","") in ["prop","seat","barrier"] or not entry.has("position"):continue
  var at:=Vector3(entry.position[0],entry.position[1],entry.position[2])
  var size:=Vector3(entry.size[0],entry.size[1],entry.size[2])
  if entry.role=="prop":size*=1.9
  var box:AABB=Transform3D(Basis(Vector3.UP,entry.get("yaw",0.0)),at)*AABB(-size*.5,size)
  areas.append(Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z)).grow(.08))
 return areas
