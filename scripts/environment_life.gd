extends Node3D
## Per-water cosmetic wildlife: real stereo depth, no collision or networking.
const PROFILES = {
	"lakeside":{"bird":"swallow","birds":8,"insect":"fly","insects":2,"plumage":Color("344958"),"insect_color":Color("696b65"),"span":.55,"tail":.32,"height":4.0,"radius":18.0,"speed":.22,"flap":12.0,"glide":.3},
	"lake_pier":{"bird":"gull","birds":4,"insect":"none","insects":0,"plumage":Color("d1d7d9"),"insect_color":Color.WHITE,"span":1.25,"tail":.20,"height":14.0,"radius":32.0,"speed":.065,"flap":3.8,"glide":.85},
	"gray_pier":{"bird":"swift","birds":5,"insect":"midge","insects":3,"plumage":Color("3d403b"),"insect_color":Color("837a60"),"span":.7,"tail":.24,"height":3.0,"radius":13.0,"speed":.30,"flap":17.0,"glide":.2},
	"simons_town_rocks":{"bird":"gull","birds":6,"insect":"none","insects":0,"plumage":Color("e2e2d9"),"insect_color":Color.WHITE,"span":1.35,"tail":.22,"height":12.0,"radius":30.0,"speed":.09,"flap":3.8,"glide":.85},
	"blouberg_sunrise_2":{"bird":"tern","birds":5,"insect":"none","insects":0,"plumage":Color("d0d5dc"),"insect_color":Color.WHITE,"span":.9,"tail":.4,"height":8.0,"radius":27.0,"speed":.16,"flap":6.5,"glide":.65},
	"bell_park_pier":{"bird":"tern","birds":3,"insect":"dragonfly","insects":2,"plumage":Color("bdc6cb"),"insect_color":Color("43a9ac"),"span":.95,"tail":.38,"height":7.0,"radius":23.0,"speed":.13,"flap":6.5,"glide":.6},
	"secluded_beach":{"bird":"gull","birds":4,"insect":"none","insects":0,"plumage":Color("dfddd2"),"insect_color":Color.WHITE,"span":1.2,"tail":.22,"height":11.0,"radius":25.0,"speed":.08,"flap":3.6,"glide":.88},
	"fish_hoek_beach":{"bird":"tern","birds":7,"insect":"none","insects":0,"plumage":Color("d5dbe0"),"insect_color":Color.WHITE,"span":.85,"tail":.4,"height":8.5,"radius":32.0,"speed":.14,"flap":6.2,"glide":.7},
}
var birds := MultiMeshInstance3D.new()
var insects := MultiMeshInstance3D.new()
var elapsed := 0.0
var location_seed := 0.0
var bird_count := 0
var insect_count := 0
var profile: Dictionary={}
func configure(id: String) -> void:
	name = "EnvironmentalLife"
	profile=PROFILES.get(id,PROFILES.lakeside)
	location_seed = float(absi(id.hash()) % 1000) / 100.0
	bird_count=profile.birds;insect_count=profile.insects
	add_child(birds);add_child(insects)
	birds.multimesh=flock_mesh(bird_mesh(),bird_count)
	insects.multimesh=flock_mesh(insect_mesh(),insect_count)
	birds.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	insects.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shader:=Shader.new()
	shader.code="""shader_type spatial;
render_mode cull_disabled;
uniform vec4 plumage : source_color = vec4(0.43,0.46,0.44,1.0);
uniform float flap_rate = 4.0;
uniform float glide_amount = 0.5;
uniform float amplitude = 0.62;
void vertex() {
	float phase=TIME*flap_rate*(1.0+INSTANCE_CUSTOM.y*.15)+INSTANCE_CUSTOM.x*6.28318;
	float glide=mix(1.0,smoothstep(-0.3,0.4,sin(TIME*0.31+INSTANCE_CUSTOM.x*6.28318)),glide_amount);
	VERTEX.y += abs(VERTEX.x)*UV.x*sin(phase)*amplitude*glide;
}
void fragment() { ALBEDO=plumage.rgb*COLOR.rgb; ROUGHNESS=0.94; SPECULAR=0.08; }
"""
	var mat:=ShaderMaterial.new();mat.shader=shader
	mat.set_shader_parameter("plumage",profile.plumage)
	mat.set_shader_parameter("flap_rate",profile.flap);mat.set_shader_parameter("glide_amount",profile.glide)
	birds.material_override=mat
	var small:=mat.duplicate()
	small.set_shader_parameter("plumage",profile.insect_color)
	small.set_shader_parameter("flap_rate",55.0)
	small.set_shader_parameter("amplitude",.22)
	small.set_shader_parameter("glide_amount",0.0)
	insects.material_override=small;insects.visible=insect_count>0
	update_positions()
func flock_mesh(mesh: Mesh,count: int) -> MultiMesh:
	var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_custom_data=true
	mm.mesh=mesh;mm.instance_count=count
	for i in count:mm.set_instance_custom_data(i,Color(fposmod(i*.173+location_seed,.999),i*.11,0,1))
	return mm
func bird_mesh() -> ArrayMesh:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0,1.0]:
		var sweep: float=.27 if profile.bird=="swift" else .16
		var points: Array=[Vector3(0,0,-.06),Vector3(side*.26,.025,-.10),Vector3(side*.53,.01,sweep),Vector3(side*.27,0,.08),Vector3(0,0,.09)]
		for tri in [[0,1,3],[1,2,3],[0,3,4]]:
			for index in tri:
				st.set_uv(Vector2(1,0));st.set_color(Color(.35,.38,.4) if index==2 else Color.WHITE)
				var v: Vector3=points[index];v.x*=profile.span;st.add_vertex(v)
	for ring in range(6):
		for j in range(8):
			for pair in [[ring,j],[ring+1,j],[ring+1,j+1],[ring,j],[ring+1,j+1],[ring,j+1]]:
				var t: float=float(pair[0])/6.0;var angle: float=float(pair[1])/8.0*TAU
				var radius: float=sin(t*PI)*.045
				st.set_uv(Vector2.ZERO);st.set_color(Color.WHITE)
				st.add_vertex(Vector3(cos(angle)*radius,sin(angle)*radius,.18-t*.42))
	for side in [-1.0,1.0]:
		for v in [Vector3(0,0,.1),Vector3(side*.085,0,profile.tail),Vector3(side*.018,0,.18)]:
			st.set_uv(Vector2.ZERO);st.set_color(Color(.65,.65,.63));st.add_vertex(v)
	st.generate_normals();return st.commit()
func insect_mesh() -> ArrayMesh:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Flies and midges have one small wing pair; dragonflies retain two narrow pairs.
	var dragonfly: bool=profile.insect=="dragonfly"
	var span: float=.052 if dragonfly else .006
	var chord: float=.009 if dragonfly else .003
	for side in [-1.0,1.0]:
		for z in ([-1.0,1.0] if dragonfly else [0.0]):
			for v in [Vector3(0,0,z*.008),Vector3(side*span,0,z*.008-chord),Vector3(side*span*.75,0,z*.008+chord)]:
				st.set_uv(Vector2(1,0));st.set_color(Color(.75,.9,.9));st.add_vertex(v)
	var length: float=.045 if dragonfly else .0035
	var width: float=.003 if dragonfly else .0012
	for v in [Vector3(0,width,-length),Vector3(-width,0,length),Vector3(width,0,length)]:
		st.set_uv(Vector2.ZERO);st.set_color(Color(.22,.3,.25));st.add_vertex(v)
	st.generate_normals();return st.commit()
func _process(delta: float) -> void:
	elapsed+=delta;update_positions()
func bird_transform(i: int) -> Transform3D:
	var a: float=elapsed*profile.speed+location_seed+i*1.73
	var radius: float=profile.radius+i*1.8
	var swoop: float=pow(maxf(0,sin(a*1.7)),6)*4.0 if profile.bird=="tern" else sin(a*2)*.65
	var pos:=Vector3(sin(a)*radius,profile.height+i*.7-swoop,-26.0+cos(a)*radius*.55)
	var forward:=Vector3(cos(a)*radius,0,-sin(a)*radius*.55).normalized()
	var basis:=Basis.looking_at(forward,Vector3.UP).rotated(forward,sin(a)*.18)
	return Transform3D(basis,pos)
func insect_transform(i: int) -> Transform3D:
	var small_fly: bool=profile.insect in ["fly","midge"]
	var a:=elapsed*(2.8 if small_fly else .9)+i*1.7+location_seed
	var center:=Vector3(-6.0+float(i%3)*6.0,1.1,-4.5)
	var radius:=.32 if small_fly else 1.5
	if profile.insect=="dragonfly":center=Vector3(-5+float(i%2)*10,.65,-7)
	var pos:=center+Vector3(sin(a)*radius,sin(a*1.8)*.25,cos(a*.7)*radius)
	return Transform3D(Basis(Vector3.UP,-a),pos)
func update_positions() -> void:
	for i in bird_count:birds.multimesh.set_instance_transform(i,bird_transform(i))
	for i in insect_count:insects.multimesh.set_instance_transform(i,insect_transform(i))
