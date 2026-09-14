extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var library=preload("res://scripts/avatar_library.gd").new()
	for path in library.DEFAULTS:
		var rig=preload("res://scripts/avatar_rig.gd").new();root.add_child(rig)
		var model: Node3D=library.load_model(path);rig.add_child(model);rig.configure(model)
		var sk: Skeleton3D=rig.skeleton
		print("MODEL ",path," transform ",sk.global_transform)
		for side in ["Left","Right"]:
			for ending in ["Shoulder","UpperArm","LowerArm","Hand","ThumbMetacarpal","ThumbProximal","ThumbDistal","IndexProximal","IndexIntermediate","IndexDistal","UpperLeg","LowerLeg","Foot","Toes"]:
				var index:=sk.find_bone(side+ending)
				if index<0:continue
				var rest:=sk.get_bone_global_rest(index)
				var next:=sk.get_bone_children(index)
				var dirs:Dictionary={}
				for child in next:
					dirs[sk.get_bone_name(child)]=str(rest.basis.inverse()*(sk.get_bone_global_rest(child).origin-rest.origin))
				print(side+ending," parent ",sk.get_bone_name(sk.get_bone_parent(index))," global basis ",rest.basis," rotation ",sk.get_bone_rest(index).basis.get_euler()," children local ",dirs)
		rig.free()
	quit()
