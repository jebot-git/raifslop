extends SceneTree
const Bounds=preload("res://scripts/avatar_rest_bounds.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var library=preload("res://scripts/avatar_library.gd").new()
	var rig=preload("res://scripts/avatar_rig.gd").new();root.add_child(rig)
	var model:Node3D=library.load_model("res://assets/avatars/vita.vrm");rig.add_child(model);rig.configure(model)
	rig.xr_pose={"head":Transform3D(Basis.IDENTITY,Vector3(0,1.2,0)),"left":Transform3D(Basis.IDENTITY,Vector3(-.3,.9,-.3)),"right":Transform3D(Basis.IDENTITY,Vector3(.3,.9,-.3)),"body":{"hips":Transform3D(Basis(Vector3.UP,.5),Vector3(0,.65,0))}}
	for i in 8: await process_frame
	rig.solver._process_modification_with_delta(.016)
	for i in rig.skeleton.get_bone_count():
		var rest:Transform3D=rig.skeleton.get_bone_rest(i)
		var pose:Transform3D=rig.skeleton.get_bone_pose(i)
		if not rest.is_equal_approx(pose): print("POSE_DIFF ",rig.skeleton.get_bone_name(i)," rest ",rest," pose ",pose)
	var transforms:Dictionary={};Bounds.collect(rig,Transform3D.IDENTITY,transforms)
	for node in transforms:
		if not node is MeshInstance3D or not node.mesh or not node.skin or not node.layers&4:continue
		var sk:Skeleton3D=node.get_node(node.skeleton)
		var rest_palette:Array[Transform3D]=[];var pose_palette:Array[Transform3D]=[];var names:Array=[]
		for bind in node.skin.get_bind_count():
			var bone:int=sk.find_bone(node.skin.get_bind_name(bind)) if not node.skin.get_bind_name(bind).is_empty() else node.skin.get_bind_bone(bind)
			names.append(sk.get_bone_name(bone))
			rest_palette.append(transforms[sk]*sk.get_bone_global_rest(bone)*node.skin.get_bind_pose(bind))
			pose_palette.append(transforms[sk]*sk.get_bone_global_pose(bone)*node.skin.get_bind_pose(bind))
		for surface in node.mesh.get_surface_count():
			var arrays:Array=node.mesh.surface_get_arrays(surface)
			var verts:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS];var bones:PackedInt32Array=arrays[Mesh.ARRAY_BONES]
			var count:int=bones.size()/verts.size()
			var rows:Array=[]
			for i in verts.size():
				var original:=Vector3.ZERO;var posed:=Vector3.ZERO;var influences:Dictionary={}
				for j in count:
					var idx:=i*count+j;var weight:=weights[idx]
					if weight<=.00001:continue
					original+=rest_palette[bones[idx]]*verts[i]*weight
					posed+=pose_palette[bones[idx]]*verts[i]*weight
					influences[names[bones[idx]]]=weight
				if original.y<.55  and posed.y>.20:
					# Calves should remain near the shin segment in this pose.
					var side: String="Left" if original.x<0 else "Right"
					var knee:Vector3=sk.to_global(sk.get_bone_global_pose(sk.find_bone(side+"LowerLeg")).origin)
					var ankle:Vector3=sk.to_global(sk.get_bone_global_pose(sk.find_bone(side+"Foot")).origin)
					var distance:=posed.distance_to(Geometry3D.get_closest_point_to_segment(posed,ankle,knee))
					if distance>.06:rows.append({"vertex":i,"rest":str(original),"posed":str(posed),"distance":distance,"weights":influences})
			rows.sort_custom(func(a,b):return a.distance>b.distance)
			print("ANKLE_SKIN ",node.name," surface ",surface," outliers ",rows.size()," worst ",JSON.stringify(rows.slice(0,8)))
	rig.free();await process_frame;quit()
