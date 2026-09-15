extends RefCounted
## Small grounded transitions at natural waters. Paths, sightlines and collision stay clear.
const SHADER=preload("res://assets/environment/rivers/vegetation.gdshader")
static func crossed_mesh(centered:bool=false,sections:int=3)->ArrayMesh:
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for slice in sections:
  var yaw:float=slice*PI/sections
  var points=[Vector3(-.5,0,0),Vector3(.5,0,0),Vector3(-.5,1,0),Vector3(.5,1,0)]
  var uv=[Vector2(0,1),Vector2(1,1),Vector2(0,0),Vector2(1,0)]
  for i in [0,2,1,1,2,3]:
   st.set_normal(Vector3.BACK.rotated(Vector3.UP,yaw));st.set_uv(uv[i]);st.add_vertex((points[i]-Vector3.UP*(.5 if centered else 0.0)).rotated(Vector3.UP,yaw))
 return st.commit()
static func create(id:String)->Node3D:
 if id=="simons_town_rocks":return preload("res://scripts/simons_rear_details.gd").create()
 if id not in ["lakeside","gray_pier"]:return null
 var root:=Node3D.new();root.name="ShoreTransitionDetails"
 var locations:Array[Vector3]=[]
 if id=="lakeside":
  for side in [-1.0,1.0]:
   for z in [-1.25,1.5,4.1,6.8,9.4,11.8]:locations.append(Vector3(side*6.6,-.045,z))
  for x in [-4.5,-2.0,2.0,4.5]:locations.append(Vector3(x,-.045,12.2))
 else:
  for side in [-1.0,1.0]:
   for z in [-2.0,.2,2.4,4.5]:locations.append(Vector3(side*2.25,-.43,z))
   for z in [7.0,8.3,9.4]:locations.append(Vector3(side*3.4,-.045,z))
 var texture_path:="res://assets/environment/rivers/river_shrubs.png" if id=="lakeside" else "res://assets/environment/shore_details/lakeshore_reeds.png"
 if not ResourceLoader.exists(texture_path):return root
 var multi:=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.use_custom_data=true;multi.mesh=crossed_mesh();multi.instance_count=locations.size()
 var rng:=RandomNumberGenerator.new();rng.seed=116 if id=="lakeside" else 218
 var placements:Array=[]
 for i in locations.size():
  var height:=rng.randf_range(.5,.85) if id=="lakeside" else rng.randf_range(.9,1.35)
  var width:=height*1.65 if id=="lakeside" else height*.9
  var at:Vector3=locations[i]+Vector3(rng.randf_range(-.15,.15),0,rng.randf_range(-.15,.15))
  multi.set_instance_transform(i,Transform3D(Basis(Vector3.UP,rng.randf_range(-PI,PI)).scaled_local(Vector3(width,height,width)),at))
  multi.set_instance_custom_data(i,Color(rng.randf_range(.82,.95),0,0,1))
  placements.append(at)
 var plants:=MultiMeshInstance3D.new();plants.name="CrossedShorePlants";plants.multimesh=multi
 var mat:=ShaderMaterial.new();mat.shader=SHADER;mat.set_shader_parameter("foliage",load(texture_path));mat.set_shader_parameter("sway",.012);mat.set_shader_parameter("exposure",.25 if id=="gray_pier" else .45)
 plants.material_override=mat;root.add_child(plants)
 root.set_meta("plant_bases",placements);root.set_meta("cross_sections",3)
 for at in locations:
  if at.y<-.2:continue
  var patch:=MeshInstance3D.new();patch.name="SoftGroundCover"
  var plane:=PlaneMesh.new();plane.size=Vector2(2.1,1.8);patch.mesh=plane;patch.position=Vector3(at.x,.012,at.z)
  var ground:=ShaderMaterial.new();ground.shader=preload("res://assets/environment/shore_details/ground_cover.gdshader")
  ground.set_shader_parameter("cover",load("res://assets/environment/rivers/river_bank.png"));ground.set_shader_parameter("strength",.45 if id=="gray_pier" else .6)
  patch.material_override=ground;patch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;root.add_child(patch)
 return root

static func remove_old_seed_heads(node:MeshInstance3D):
 # Gray Pier's old reed heads share wood material with underwater pier supports.
 # Keep that structure; only the reed heads use this material above ground.
 var mesh:=ArrayMesh.new()
 for surface in node.mesh.get_surface_count():
  var arrays:=node.mesh.surface_get_arrays(surface)
  var mat:=node.mesh.surface_get_material(surface)
  if mat and mat.resource_name.begins_with("FG_wood_end"):
   var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
   var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
   var kept:=PackedInt32Array()
   for i in range(0,indices.size(),3):
    if vertices[indices[i]].y>.05 and vertices[indices[i+1]].y>.05 and vertices[indices[i+2]].y>.05:continue
    kept.append_array(indices.slice(i,i+3))
   if kept.is_empty():continue
   arrays[Mesh.ARRAY_INDEX]=kept
  mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  mesh.surface_set_material(mesh.get_surface_count()-1,mat)
 node.mesh=mesh
