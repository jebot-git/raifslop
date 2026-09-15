extends RefCounted
## Low photographic rock formations outside the rear rope, embedded in the mainland.
static func create()->Node3D:
 var root:=Node3D.new();root.name="RearRockTransitions"
 var path:="res://assets/environment/shore_details/simons_granite.png"
 if not ResourceLoader.exists(path):return root
 # A shallow convex strip gives modest depth without intersecting opaque rock faces.
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for segment in 8:
  var u0:float=segment/8.0;var u1:float=(segment+1)/8.0
  for uv in [Vector2(u0,1),Vector2(u0,0),Vector2(u1,1),Vector2(u1,1),Vector2(u0,0),Vector2(u1,0)]:
   st.set_uv(uv);st.set_normal(Vector3.FORWARD)
   st.add_vertex(Vector3(uv.x-.5,1.0-uv.y,-sin(uv.x*PI)*.12))
 # Stagger three real depth tiers, with gaps revealing the next formation.
 # Buried bases keep the silhouettes attached to the rising mainland.
 var placements=[Vector3(-3.5,-.45,10.3),Vector3(3.0,-.45,10.8),
  Vector3(-6.1,-1.0,15.5),Vector3(6.5,-1.0,16.8),
  Vector3(-10.0,-1.1,23.0),Vector3(10.5,-1.1,24.5)]
 var widths=[4.6,4.2,6.5,5.8,8.4,7.6];var heights=[2.0,2.3,2.4,2.6,3.2,3.3]
 var angles=[-.12,.06,.18,-.13,.09,-.18]
 var multi:=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.use_custom_data=true;multi.mesh=st.commit();multi.instance_count=placements.size()
 for i in placements.size():
  var basis:=Basis(Vector3.UP,angles[i]).scaled_local(Vector3(widths[i],heights[i],widths[i]))
  if i%2==1:basis=basis.scaled_local(Vector3(-1,1,1))
  multi.set_instance_transform(i,Transform3D(basis,placements[i]));multi.set_instance_custom_data(i,Color(.92 if i%2==0 else 1.0,0,0,1))
 var rocks:=MultiMeshInstance3D.new();rocks.name="CurvedRockCards";rocks.multimesh=multi
 var mat:=ShaderMaterial.new();mat.shader=preload("res://assets/environment/rivers/vegetation.gdshader")
 mat.set_shader_parameter("foliage",load(path));mat.set_shader_parameter("sway",0.0);mat.set_shader_parameter("exposure",.32)
 rocks.material_override=mat;rocks.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 root.add_child(rocks);root.set_meta("bases",placements);root.set_meta("depth_layers",3)
 return root
