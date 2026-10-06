extends SceneTree
class Mouth extends RefCounted:
	var binds: Array=[[],[],[],[],[]]
	var weights:=PackedFloat32Array([.5,0,0,0,0])
class Rig extends RefCounted:
	var mouth:=Mouth.new()
	var dead:=false
var failures:=0
func check(ok: bool,message: String):
	if not ok:failures+=1;push_error(message)
func _initialize():run.call_deferred()
func run():
	var eyes=preload("res://scripts/avatar_eyes.gd").new()
	eyes.rig=Rig.new()
	var mesh:=ArrayMesh.new()
	for name_here in ["shared","mouth","expression"]:mesh.add_blend_shape(name_here)
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3.ZERO,Vector3.RIGHT,Vector3.UP])
	var shapes: Array[Array]=[arrays.duplicate(true),arrays.duplicate(true),arrays.duplicate(true)]
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,shapes)
	var node:=MeshInstance3D.new();node.mesh=mesh;root.add_child(node)
	eyes.binds[4].append([node,0,.8])
	eyes.binds[7].append([node,0,.5])
	eyes.binds[10].append([node,2,1.0])
	eyes.rig.mouth.binds[0]=[[node,0,.6],[node,1,1.0]]
	eyes.morph_weights[4]=.5;eyes.morph_weights[7]=.4;eyes.morph_weights[10]=.6
	eyes.rebuild_morph_channels();eyes.apply_morphs()
	check(is_equal_approx(node.get_blend_shape_value(0),.9),"Shared blink/expression/speech sum is capped at .9")
	check(is_equal_approx(node.get_blend_shape_value(1),.5),"Mouth-only channel contributes speech")
	check(is_equal_approx(node.get_blend_shape_value(2),.6),"Fishing expression ordering is retained")
	eyes.rig.dead=true;eyes.apply_morphs()
	check(is_equal_approx(node.get_blend_shape_value(0),.6),"Dead avatar retains eyes and expression without speech")
	check(node.get_blend_shape_value(1)==0,"Dead avatar clears mouth-only channels")
	eyes.rig.dead=false;eyes.morph_weights.fill(0);eyes.rig.mouth.weights.fill(0);eyes.apply_morphs()
	for i in 3:check(node.get_blend_shape_value(i)==0,"Channels return to neutral")
	eyes.apply_morphs()
	node.free();eyes.apply_morphs() # Removed meshes must not crash cached writes.
	eyes.rig=null;eyes.free()
	print("PASS avatar_morph_cache" if failures==0 else "FAIL avatar_morph_cache")
	quit(1 if failures else 0)
