extends Node3D
## Eight tapered segments in one draw call; only the replaceable quiver tip bends.
var segments:=MultiMesh.new()
var end:=Vector3(0,0,-1.68)
func _init():
 var mesh:=CylinderMesh.new();mesh.top_radius=.9;mesh.bottom_radius=1;mesh.height=1;mesh.radial_segments=8;mesh.rings=1
 var material:=StandardMaterial3D.new();material.vertex_color_use_as_albedo=true;material.roughness=.6;mesh.material=material
 segments.transform_format=MultiMesh.TRANSFORM_3D;segments.use_colors=true;segments.mesh=mesh;segments.instance_count=8
 var node:=MultiMeshInstance3D.new();node.multimesh=segments;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(node)
 for i in 8:segments.set_instance_color(i,Color("e8cb70") if i%3 else Color("333c36"))
 bend(0)
func bend(amount:float):
 var a:=Vector3(0,0,-1.40)
 for i in 8:
  var t:float=(i+1)/8.0;var b:=Vector3(0,-amount*t*t,-1.40-.28*t)
  var radius:=lerpf(.002,.001,i/8.0)
  var basis:=Basis(Quaternion(Vector3.UP,(b-a).normalized())).scaled_local(Vector3(radius,a.distance_to(b),radius))
  segments.set_instance_transform(i,Transform3D(basis,(a+b)*.5));a=b
 end=a
