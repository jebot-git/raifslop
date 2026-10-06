extends SceneTree
const Codec=preload("res://scripts/network/pose_codec.gd")
const Fixture=preload("res://tests/network_fixture.gd")
const Bounds=preload("res://scripts/avatar_rest_bounds.gd")
var failures: Array=[]
var rng:=RandomNumberGenerator.new()
func check(ok:bool,message:String):
	if not ok:
		if failures.size()<20:push_error(message)
		failures.append(message)
func reference_hit(faces:Array,start:Vector3,end:Vector3)->bool:
	for tri in faces:
		if Geometry3D.segment_intersects_triangle(start,end,tri[0],tri[1],tri[2])!=null:return true
	return false
func _initialize():run.call_deferred()
func run():
	rng.seed=92043
	check(Codec.native!=null,"Native library must actually load for native regressions")
	if Codec.native==null:quit(1);return
	for count in [0,4,10]:
		for iteration in 100:
			var input:=Fixture.player(count,iteration%2==0)
			input.location=Codec.location_table()[iteration%Codec.location_table().size()]
			input.curl=rng.randf();input.serial=rng.randi_range(0,2147483647)
			input.user_height=rng.randf_range(.6,2.3)
			for key in Codec.State.TRANSFORMS:
				input[key]=Transform3D(Basis.from_euler(Vector3(rng.randf_range(-PI,PI),rng.randf_range(-PI,PI),rng.randf_range(-PI,PI))),Vector3(rng.randf_range(-100,100),1.7,-10))
			var expected:=Codec.encode_reference(input)
			var actual:=Codec.encode(input)
			check(actual==expected,"Exact wire parity: %d/%d"%[count,iteration])
			var decoded:=Codec.decode(actual)
			var reference:=Codec.decode_reference(actual)
			check(not decoded.is_empty(),"Native round trip accepted")
			if decoded.is_empty():continue
			for key in Codec.State.TRANSFORMS:check(decoded[key].is_equal_approx(reference[key]),"Decoded transform parity "+key)
			check(Codec.encode(decoded)==Codec.encode_reference(decoded),"Native re-encoding parity")
	var valid:=Codec.encode(Fixture.player(10,true))
	for size in valid.size():check(Codec.decode(valid.slice(0,size)).is_empty(),"Truncation rejected")
	for i in 1500:
		var corrupt:=valid.duplicate()
		corrupt[rng.randi_range(0,corrupt.size()-1)]=rng.randi_range(0,255)
		check(Codec.decode(corrupt).is_empty()==Codec.decode_reference(corrupt).is_empty(),"Mutation acceptance parity")
	for i in 100:
		var invalid:=Fixture.player(10,true);invalid["curl"]=NAN if i%2 else -1
		check(Codec.encode(invalid).is_empty(),"Invalid input rejected")
	var native=preload("res://scripts/native/runtime.gd").create()
	var faces:Array=[]
	for i in 500:
		var at:=Vector3(rng.randf_range(-30,30),rng.randf_range(-3,3),rng.randf_range(-30,30))
		faces.append(PackedVector3Array([at,at+Vector3(2,0,0),at+Vector3(0,0,2)]))
	faces.append(PackedVector3Array([Vector3.ZERO,Vector3.ZERO,Vector3.ZERO]))
	check(native.set_faces(faces),"BVH accepts valid and degenerate triangles")
	for i in 1200:
		var start:=Vector3(rng.randf_range(-40,40),rng.randf_range(-5,5),rng.randf_range(-40,40))
		var end:=Vector3(rng.randf_range(-40,40),rng.randf_range(-5,5),rng.randf_range(-40,40))
		if i%4==0:end=start+Vector3.UP*10
		if i%10==0:end=start
		check(native.segment_obstructed(start,end)==reference_hit(faces,start,end),"BVH vs exhaustive triangles")
	native.set_faces([]);check(not native.segment_obstructed(Vector3.DOWN,Vector3.UP),"Rebuild clears old geometry")
	check(not native.set_faces([PackedVector3Array([Vector3.ZERO])]),"Malformed triangles rejected")
	var library=preload("res://scripts/avatar_library.gd").new()
	for path in library.DEFAULTS:
		var model=library.load_model(path)
		check(model!=null,"Avatar loads "+path)
		if not model:continue
		var accelerated:=Bounds.measure(model)
		var helper=Bounds.native;Bounds.native=null
		var reference:=Bounds.measure(model);Bounds.native=helper
		check(accelerated.is_equal_approx(reference),"Native skinned bounds match all surfaces: "+path)
		model.free()
	var palette:Array=[]
	for i in 8:palette.append(Transform3D(Basis.IDENTITY,Vector3(i,0,0)))
	var eight:Dictionary=native.surface_bounds(PackedVector3Array([Vector3(1,2,3),Vector3(2,2,3)]),PackedInt32Array([0,1,2,3,4,5,6,7,0,1,2,3,4,5,6,7]),PackedFloat32Array([.125,.125,.125,.125,.125,.125,.125,.125,.125,.125,.125,.125,.125,.125,.125,.125]),palette,Transform3D.IDENTITY,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*2),Vector3.ZERO))
	check(eight.ok and eight.bounds.is_equal_approx(AABB(Vector3(9,4,6),Vector3(2,0,0))),"Eight bone influences and skeleton scale preserved")
	var bad:Dictionary=native.surface_bounds(PackedVector3Array([Vector3.ZERO]),PackedInt32Array([8,0,0,0]),PackedFloat32Array([1,0,0,0]),[Transform3D.IDENTITY],Transform3D.IDENTITY,Transform3D.IDENTITY)
	check(not bad.ok,"Out-of-range skin palette rejected")
	print("NATIVE_KERNELS failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
