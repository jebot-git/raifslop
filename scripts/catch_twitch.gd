extends RefCounted
## Short, irregular muscle twitches. All skin and fins share one deformation;
## the head stays still so the existing mouth attachment remains exact.
var meshes: Array[MeshInstance3D] = []
var elapsed := 0.0
var next_twitch := 1.0
var burst_start := -1.0
var rng := RandomNumberGenerator.new()
const BURST_SECONDS := .42
const MAX_BEND := .018

static func bend(x: float, mouth_x: float, length_m: float) -> float:
	var tail := clampf(((mouth_x-x)/length_m-.18)/.82,0.0,1.0)
	return length_m*MAX_BEND*tail*tail*sin(tail*4.0)

func configure(container: Node3D, measured: AABB, seed_value: int) -> void:
	meshes.clear();elapsed=0.0;burst_start=-1.0
	rng.seed=seed_value;next_twitch=rng.randf_range(.8,1.6)
	for node in container.find_children("*","MeshInstance3D",true,false):
		var source: Mesh=node.mesh
		if source==null or source.get_surface_count()==0: continue
		var into_fish: Transform3D=container.global_transform.affine_inverse()*node.global_transform
		var from_fish := into_fish.affine_inverse()
		var normal_into := into_fish.basis.inverse().transposed()
		var normal_back := into_fish.basis.transposed()
		var animated := ArrayMesh.new()
		animated.blend_shape_mode=Mesh.BLEND_SHAPE_MODE_NORMALIZED
		animated.add_blend_shape("TwitchLeft");animated.add_blend_shape("TwitchRight")
		for surface in source.get_surface_count():
			var arrays: Array=source.surface_get_arrays(surface)
			var shapes: Array[Array]=[]
			for sign_value in [-1.0,1.0]:
				var shape: Array=[];shape.resize(Mesh.ARRAY_MAX)
				var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX].duplicate()
				var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL].duplicate()
				var tangents: PackedFloat32Array=arrays[Mesh.ARRAY_TANGENT].duplicate() if arrays[Mesh.ARRAY_TANGENT]!=null else PackedFloat32Array()
				for i in vertices.size():
					var point := into_fish*vertices[i]
					var epsilon := measured.size.x*.0001
					var slope: float=sign_value*(bend(point.x+epsilon,measured.end.x,measured.size.x)-bend(point.x-epsilon,measured.end.x,measured.size.x))/(2.0*epsilon)
					point.z+=sign_value*bend(point.x,measured.end.x,measured.size.x)
					vertices[i]=from_fish*point
					if not normals.is_empty():
						var normal := normal_into*normals[i]
						normal.x-=slope*normal.z
						normals[i]=(normal_back*normal).normalized()
					if not tangents.is_empty():
						var tangent := into_fish.basis*Vector3(tangents[i*4],tangents[i*4+1],tangents[i*4+2])
						tangent.z+=slope*tangent.x
						tangent=(from_fish.basis*tangent).normalized()
						for axis in 3: tangents[i*4+axis]=tangent[axis]
				shape[Mesh.ARRAY_VERTEX]=vertices
				if not normals.is_empty(): shape[Mesh.ARRAY_NORMAL]=normals
				if not tangents.is_empty(): shape[Mesh.ARRAY_TANGENT]=tangents
				shapes.append(shape)
			var flags: int=source.surface_get_format(surface) & ~Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES
			animated.add_surface_from_arrays(source.surface_get_primitive_type(surface),arrays,shapes,{},flags)
			animated.surface_set_material(surface,source.surface_get_material(surface))
		node.mesh=animated
		meshes.append(node)
	set_amount(0.0)

func set_amount(amount: float) -> void:
	for mesh in meshes:
		if not is_instance_valid(mesh): continue
		mesh.set_blend_shape_value(0,maxf(0.0,-amount))
		mesh.set_blend_shape_value(1,maxf(0.0,amount))

func tick(delta: float) -> void:
	elapsed+=maxf(delta,0.0)
	if elapsed>=next_twitch:
		burst_start=elapsed
		next_twitch=elapsed+rng.randf_range(2.8,5.2)
	var age := elapsed-burst_start
	var amount := 0.0
	if burst_start>=0.0 and age<BURST_SECONDS:
		var envelope := pow(sin(age/BURST_SECONDS*PI),2.0)
		amount=sin(age*TAU*7.0)*envelope
	set_amount(amount)
