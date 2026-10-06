extends SceneTree
class Mouth extends RefCounted:
	var binds: Array=[[],[],[],[],[]]
	var weights:=PackedFloat32Array([.2,.3,.4,.1,.5])
class Rig extends RefCounted:
	var mouth:=Mouth.new()
	var dead:=false
func _initialize():run.call_deferred()
func run():
	GDExtensionManager.load_extension("res://native.gdextension")
	assert(ClassDB.class_exists("FPSPose"))
	var eyes=load("res://cached.gd").new()
	eyes.rig=Rig.new()
	var mesh:=ArrayMesh.new()
	for i in 12:mesh.add_blend_shape(str(i))
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3.ZERO,Vector3.RIGHT,Vector3.UP])
	var shapes: Array[Array]=[]
	for i in 12:shapes.append(arrays.duplicate(true))
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,shapes)
	var node:=MeshInstance3D.new();node.mesh=mesh;root.add_child(node)
	for i in 12:
		eyes.binds[i].append([node,i,.7])
		eyes.binds[i].append([node,(i+1)%12,.3])
	for i in 5:eyes.rig.mouth.binds[i].append([node,i+5,.8])
	var deployed=load("res://deployed.gd").new()
	deployed.rig=eyes.rig;deployed.binds=eyes.binds;deployed.morph_weights=eyes.morph_weights
	deployed.rebuild_morph_channels()
	eyes.rebuild_bindings()
	var native=ClassDB.instantiate("FPSPose");native.configure_morphs(eyes.channels)
	var error:=0.0
	for i in 120:
		eyes.rig.dead=i%3==0
		for j in 12:eyes.morph_weights[j]=sin(i*.1+j)*.5+.5
		eyes.apply_morphs()
		var expected: Array=[]
		for j in 12:expected.append(node.get_blend_shape_value(j))
		deployed.apply_morphs()
		for j in 12:error=maxf(error,absf(expected[j]-node.get_blend_shape_value(j)))
		for c in eyes.channels:c[4]=NAN
		eyes.compose_cached_reference()
		for j in 12:error=maxf(error,absf(expected[j]-node.get_blend_shape_value(j)))
		for c in eyes.channels:c[4]=NAN
		native.compose_morphs(eyes.morph_weights,eyes.rig.mouth.weights,eyes.rig.dead)
		for j in 12:error=maxf(error,absf(expected[j]-node.get_blend_shape_value(j)))
	assert(error<.00001)
	var results: Array=[]
	for mode in ["current","cached","deployed","native","native","deployed","cached","current"]:
		var batches: Array=[]
		for batch in 11:
			var started:=Time.get_ticks_usec()
			for i in 10000:
				eyes.morph_weights[0]=float(i%100)/100
				if mode=="current":eyes.apply_morphs()
				elif mode=="cached":eyes.compose_cached_reference()
				elif mode=="deployed":deployed.apply_morphs()
				else:native.compose_morphs(eyes.morph_weights,eyes.rig.mouth.weights,eyes.rig.dead)
			if batch>0:batches.append((Time.get_ticks_usec()-started)/10000.0)
		batches.sort();results.append({"mode":mode,"median_usec_per_call":batches[5]})
	print("REUSE_PROBE ",JSON.stringify({"engine":Engine.get_version_info().string,"max_error":error,"results":results,"scope":"Headless Linux synthetic single mesh, 12 morph channels, 29 bindings; changing one weight per call; includes GDExtension call; no rendering, XR or whole-game frame timing"}))
	deployed.rig=null;deployed.free();eyes.rig=null;eyes.free();node.free();quit()
