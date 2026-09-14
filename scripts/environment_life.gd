extends Node3D
## Quiet cosmetic wildlife with real stereo depth. No lights, collision or networking.
var birds := MultiMeshInstance3D.new()
var insects := MultiMeshInstance3D.new()
var elapsed := 0.0
var location_seed := 0.0
var bird_count := 7
func configure(id: String) -> void:
	name = "EnvironmentalLife"
	location_seed = float(absi(id.hash()) % 1000) / 100.0
	bird_count = 5 if id == "gray_pier" else 7
	add_child(birds)
	add_child(insects)
	birds.multimesh = flock_mesh(bird_mesh(),bird_count)
	insects.multimesh = flock_mesh(bird_mesh(),4)
	birds.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	insects.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode cull_disabled;
uniform vec4 plumage : source_color = vec4(0.43,0.46,0.44,1.0);
void vertex() {
 float phase=TIME*(3.8+INSTANCE_CUSTOM.y*2.0)+INSTANCE_CUSTOM.x*6.28318;
 float glide=smoothstep(-0.3,0.4,sin(TIME*0.31+INSTANCE_CUSTOM.x*6.28318));
 VERTEX.y += abs(VERTEX.x)*UV.x*sin(phase)*0.62*glide;
}
void fragment() { ALBEDO=plumage.rgb*COLOR.rgb; ROUGHNESS=0.94; SPECULAR=0.08; }
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("plumage", Color("8b928c") if id in ["lake_pier","bell_park_pier"] else Color("48544e"))
	birds.material_override = mat
	var small := mat.duplicate()
	small.set_shader_parameter("plumage",Color("58766b"))
	insects.material_override = small
	update_positions()
func flock_mesh(mesh: Mesh, count: int) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = count
	for i in count: mm.set_instance_custom_data(i,Color(fposmod(i*.173+location_seed,.999),i*.11,0,1))
	return mm
func bird_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Tapered wings with a swept tip; UV.x distinguishes movable wings from body.
	for side in [-1.0,1.0]:
		var points := [Vector3(0,0,-.06),Vector3(side*.26,.025,-.10),Vector3(side*.53,.01,.16),Vector3(side*.27,0,.08),Vector3(0,0,.09)]
		for tri in [[0,1,3],[1,2,3],[0,3,4]]:
			for index in tri:
				st.set_uv(Vector2(1,0));st.set_color(Color(.55,.57,.55) if index == 2 else Color.WHITE)
				st.add_vertex(points[index])
	# Small volumetric body and head, not a flat V silhouette at closer distances.
	for ring in range(6):
		for j in range(8):
			for pair in [[ring,j],[ring+1,j],[ring+1,j+1],[ring,j],[ring+1,j+1],[ring,j+1]]:
				var t: float=float(pair[0])/6.0
				var angle: float=float(pair[1])/8.0*TAU
				var radius: float=sin(t*PI)*.045
				st.set_uv(Vector2.ZERO);st.set_color(Color.WHITE)
				st.add_vertex(Vector3(cos(angle)*radius,sin(angle)*radius,.18-t*.42))
	for v in [Vector3(0,0,.1),Vector3(-.075,0,.26),Vector3(.075,0,.26)]:
		st.set_uv(Vector2.ZERO);st.set_color(Color(.65,.65,.63));st.add_vertex(v)
	st.generate_normals()
	return st.commit()
func _process(delta: float) -> void:
	elapsed += delta
	update_positions()
func update_positions() -> void:
	for i in bird_count:
		var a := elapsed*.025+location_seed+i*.68
		var radius := 27.0+i*3.0
		var pos := Vector3(sin(a)*radius,10.0+i*1.8+sin(a*2.0),-52.0+cos(a)*17.0)
		var forward := Vector3(cos(a)*radius,0,-sin(a)*17.0).normalized()
		var basis := Basis.looking_at(forward,Vector3.UP).rotated(forward,sin(a)*.10)
		birds.multimesh.set_instance_transform(i,Transform3D(basis,pos))
	for i in 4:
		var a := elapsed*.6+i*1.7+location_seed
		var pos := Vector3(-7.0+i*4.0+sin(a)*1.8,.8+sin(a*1.8)*.3,-8.0-cos(a*.7)*2.0)
		insects.multimesh.set_instance_transform(i,Transform3D(Basis(Vector3.UP,-a).scaled(Vector3.ONE*.075),pos))
