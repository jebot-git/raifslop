## Live IK regression adapted from FPSloppa 28a719a.
extends SceneTree
var failures: Array=[]
func check(value: bool,label: String) -> void:
	print("PASS " if value else "FAIL ",label)
	if not value: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var library=load("res://scripts/avatar_library.gd").new()
	library.initialize()
	var body:=Node3D.new()
	root.add_child(body)
	for entry in library.entries:
		var avatar=preload("res://scripts/avatar_rig.gd").new()
		body.add_child(avatar)
		var model: Node3D=library.load_model(entry.path)
		avatar.add_child(model)
		check(avatar.configure(model),"Configure "+entry.title)
		for index in avatar.skeleton.get_bone_count():
			check(avatar.skeleton.get_bone_pose(index).is_equal_approx(avatar.skeleton.get_bone_rest(index)),entry.title+" initialized retargeted pose "+avatar.skeleton.get_bone_name(index))
		var pose={"head":Transform3D(Basis.IDENTITY,Vector3(0,1.65,0)),"left":Transform3D(Basis.IDENTITY,Vector3(-.3,1.1,-.3)),"right":Transform3D(Basis.IDENTITY,Vector3(.3,1.1,-.3))}
		pose.head.origin.y=1.3
		pose.left.origin=Vector3(-.3,.95,-.3)
		pose.right.origin=Vector3(.3,.95,-.3)
		pose.weapon=pose.right
		avatar.xr_pose=pose
		await process_frame
		await process_frame
		avatar.solver._process_modification_with_delta(.016)
		for index in avatar.skeleton.get_bone_count():
			if avatar.skeleton.get_bone_name(index)=="Hips":continue
			check(avatar.skeleton.get_bone_pose_position(index).is_equal_approx(avatar.skeleton.get_bone_rest(index).origin),entry.title+" preserves retargeted offset "+avatar.skeleton.get_bone_name(index))
		for side in ["Left","Right"]:
			var bone: int=avatar.skeleton.find_bone(side+"Hand")
			var pos: Vector3=avatar.skeleton.to_global(avatar.skeleton.get_bone_global_pose(bone).origin)
			check(pos.distance_to(pose[side.to_lower()].origin)<.17,entry.title+" crouched "+side+" tracking IK")
		check(avatar.secondary_nodes.all(func(secondary): return secondary.local_body_disabled), "Local VRM springs cannot override tracked limbs")
		pose.left.basis=Basis.from_euler(Vector3(.3,.6,.4));pose.right.basis=pose.left.basis
		avatar.xr_pose=pose
		avatar.solver._process_modification_with_delta(.016)
		for side in ["Left","Right"]:
			var sk:Skeleton3D=avatar.skeleton
			var wrist:int=sk.find_bone(side+"Hand")
			var actual:Basis=sk.global_basis.orthonormalized()*sk.get_bone_global_pose(wrist).basis.orthonormalized()
			var grip:Basis=pose[side.to_lower()].basis
			check(actual.y.dot(-grip.y)>.99 and actual.z.dot(grip.x*(1 if side=="Left" else -1))>.99,"Controller grip axes orient "+side+" palm correctly")
			var finger:int=sk.find_bone(side+"IndexIntermediate")
			var curl:Quaternion=sk.get_bone_rest(finger).basis.get_rotation_quaternion().inverse()*sk.get_bone_pose_rotation(finger)
			check(absf(curl.get_axis().dot(Vector3.RIGHT))>.999 and curl.get_angle()>.1 and curl.get_angle()<1.4,"Rotated "+side+" wrist keeps anatomically bounded local finger bend")
			var metacarpal: int=sk.find_bone(side+"ThumbMetacarpal")
			check(not sk.get_bone_pose_rotation(metacarpal).is_equal_approx(sk.get_bone_rest(metacarpal).basis.get_rotation_quaternion()),"Thumb base participates in grasp")
			var lower: int=sk.find_bone(side+"LowerArm")
			var rest_hand: Basis=sk.get_bone_global_rest(wrist).basis
			var rest_lower: Basis=sk.get_bone_global_rest(lower).basis
			var expected_hand: Basis=sk.get_bone_global_pose(lower).basis*rest_lower.inverse()*rest_hand
			var residual: Quaternion=expected_hand.get_rotation_quaternion().inverse()*sk.get_bone_global_pose(wrist).basis.get_rotation_quaternion()
			var axis: Vector3=rest_hand.inverse()*(sk.get_bone_global_rest(wrist).origin-sk.get_bone_global_rest(lower).origin).normalized()
			check(absf(Vector3(residual.x,residual.y,residual.z).dot(axis))<.001,"Forearm carries "+side+" pronation without wrist axial twist")
		pose.body={"left_hand":Transform3D(Basis.from_euler(Vector3(.2,-.4,.7)),pose.left.origin)}
		avatar.xr_pose=pose;avatar.solver._process_modification_with_delta(.016)
		var optical:Basis=avatar.skeleton.global_basis.orthonormalized()*avatar.skeleton.get_bone_global_pose(avatar.skeleton.find_bone("LeftHand")).basis.orthonormalized()
		check(optical.is_equal_approx(pose.body.left_hand.basis),"Native optical wrist keeps humanoid bone axes")
		for angle in [0.0,PI/2,-PI/2]:
			var yaw:=Basis(Vector3.UP,angle)
			pose.body={"hips":Transform3D(yaw,Vector3(0,.72,0)),"left_foot":Transform3D(yaw,yaw*Vector3(-.15,.08,0)),"right_foot":Transform3D(yaw,yaw*Vector3(.15,.08,0))}
			avatar.xr_pose=pose;avatar.solver._process_modification_with_delta(.016)
			for side in ["Left","Right"]:
				var sk:Skeleton3D=avatar.skeleton
				var hip:Vector3=sk.to_global(sk.get_bone_global_pose(sk.find_bone(side+"UpperLeg")).origin)
				var knee:Vector3=sk.to_global(sk.get_bone_global_pose(sk.find_bone(side+"LowerLeg")).origin)
				check((knee-hip).dot(-yaw.z)>-.015,entry.title+" "+side+" knee bends toward pelvis forward at yaw "+str(angle))
		# Native knee positions can jitter across the hip-to-ankle line while
		# standing. Both sides must retain the forward bend plane and skin roll.
		var previous:Dictionary={}
		for jitter in [-.003,0.0,.003]:
			pose.head=Transform3D(Basis.IDENTITY,Vector3(0,1.65,0))
			pose.body={"hips":Transform3D(Basis.IDENTITY,Vector3(0,.92,0)),"left_foot":Transform3D(Basis.IDENTITY,Vector3(-.13,.08,0)),"right_foot":Transform3D(Basis.IDENTITY,Vector3(.13,.08,0)),"left_knee":Transform3D(Basis.IDENTITY,Vector3(-.13,.5,jitter)),"right_knee":Transform3D(Basis.IDENTITY,Vector3(.13,.5,jitter))}
			avatar.xr_pose=pose;avatar.solver._process_modification_with_delta(.016)
			for side in ["Left","Right"]:
				for part in ["UpperLeg","LowerLeg"]:
					var name_here:String=side+part
					var actual:Quaternion=avatar.skeleton.get_bone_global_pose(avatar.skeleton.find_bone(name_here)).basis.orthonormalized().get_rotation_quaternion()
					if previous.has(name_here):check(previous[name_here].angle_to(actual)<deg_to_rad(10),entry.title+" "+name_here+" does not twist as a straight tracked knee jitters")
					previous[name_here]=actual
		avatar.free()
	body.free()

	print("VR_IK_RESULT ",JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
