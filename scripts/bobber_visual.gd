extends MeshInstance3D
## Shared lathed float: lacquered balsa body, contrasting sight bands, brass
## collars and a graphite keel. One cached mesh/material for local and peers.
static var shared_mesh: ArrayMesh
static var shared_material: ShaderMaterial
const SEGMENTS := 24
const PROFILE := [Vector2(-.09,0),Vector2(-.086,.002),Vector2(-.038,.002),
	Vector2(-.035,.005),Vector2(-.026,.013),Vector2(-.008,.021),
	Vector2(.008,.022),Vector2(.014,.021),Vector2(.022,.019),
	Vector2(.036,.013),Vector2(.046,.006),Vector2(.050,.004),
	Vector2(.055,.004),Vector2(.056,.0025),Vector2(.079,.0025),
	Vector2(.091,.0025),Vector2(.101,.0025),Vector2(.128,.0025),Vector2(.131,0)]

func _init() -> void:
	name="LacqueredFloat"
	if shared_mesh==null:
		shared_mesh=build_mesh()
		shared_material=ShaderMaterial.new()
		shared_material.shader=preload("res://assets/environment/bobber.gdshader")
	mesh=shared_mesh
	material_override=shared_material
	cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func build_mesh() -> ArrayMesh:
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for band in range(PROFILE.size()-1):
		var lo:Vector2=PROFILE[band];var hi:Vector2=PROFILE[band+1]
		var height:float=(lo.x+hi.x)*.5
		var graphite:bool=height<-.035 or (height>.055 and height<.079) or (height>.091 and height<.101)
		var brass:bool=height>=.046 and height<=.055
		var red:bool=(height>.014 and height<.036) or height>.101
		var paint:=Color("29343b") if graphite else Color("bc9450") if brass else Color("ed4c22") if red else Color("eee6cd")
		paint=paint.srgb_to_linear()
		paint.a=.38 if graphite else .25 if brass else .28
		for side in SEGMENTS:
			for corner in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]:
				var angle:float=TAU*(side+corner.x)/SEGMENTS
				var ring:Vector2=lo if corner.y==0 else hi
				var ring_index:int=band+corner.y
				var previous:Vector2=PROFILE[maxi(0,ring_index-1)]
				var next:Vector2=PROFILE[mini(PROFILE.size()-1,ring_index+1)]
				var normal:=Vector3(cos(angle),-(next.y-previous.y)/(next.x-previous.x),sin(angle)).normalized()
				surface.set_normal(normal);surface.set_color(paint)
				surface.set_uv(Vector2(.72 if brass else .12 if graphite else 0.0,(ring.x+.09)/.221))
				surface.add_vertex(Vector3(cos(angle)*ring.y,ring.x,sin(angle)*ring.y))
	return surface.commit()
