extends Node3D
const IK = preload("res://scripts/avatar_ik.gd")
var skeleton: Skeleton3D
var model: Node3D
var solver: SkeletonModifier3D
var head: Camera3D
var left_target: Node3D
var right_target: Node3D
var standing_height := 1.65
var walk_phase := 0.0
var walk_speed := 0.0
var left_curl := 0.0
var pose_frame := Transform3D.IDENTITY
var xr_pose: Dictionary={}
var body: Dictionary={}
var face: Dictionary={}
var mouth: Node
var eyes: SkeletonModifier3D
var first_person := true
var dead := false
var preview_mode := -1
var speed := 0.0
var movement := Vector3.ZERO
var phase := 0.0


static func find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D and node.find_bone("Hips") >= 0: return node
	for child in node.get_children():
		var found := find_skeleton(child)
		if found: return found
	return null

func configure(root: Node3D) -> bool:
	model = root
	skeleton = find_skeleton(root)
	if not skeleton: return false
	for bone in ["Hips", "Head", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot"]:
		if skeleton.find_bone(bone) < 0: return false
	var rest_head := skeleton.get_bone_global_rest(skeleton.find_bone("Head")).origin
	var eye_height := (root.transform * skeleton.transform * rest_head).y + 0.10
	if not is_finite(eye_height) or eye_height < 0.2 or eye_height > 5.0: return false
	root.scale *= standing_height / eye_height
	root.rotation.y += PI
	mouth=preload("res://scripts/avatar_mouth.gd").new(); add_child(mouth); mouth.setup(root)
	eyes=preload("res://scripts/avatar_eyes.gd").new(); eyes.rig=self
	# Capture the VRM expression bindings before stripping imported animation players.
	eyes.setup(root)
	strip_extras(root)
	solver = IK.new()
	skeleton.add_child(solver)
	solver.setup(self)
	skeleton.add_child(eyes)
	add_to_group("fishing_avatar_rigs")
	return true

func strip_extras(node: Node) -> void:
	for child in node.get_children():
		if child is Camera3D or child is Light3D or child is CollisionObject3D or child is AudioStreamPlayer3D or child is AnimationPlayer:
			child.free()
		else: strip_extras(child)
	if node is MeshInstance3D:
		# Keep the VRM first-/third-person layer separation intact.
		if node.layers & 1: node.layers = (node.layers & ~1) | 6
		for i in range(node.mesh.get_surface_count()):
			var mat: Material = node.get_active_material(i)
			if mat:
				preload("res://scripts/avatar_lighting.gd").prepare(mat)
				mat.next_pass = null

func update_targets(camera: Camera3D, left_hand: Node3D, right_hand: Node3D, feet_y: float, motion: Vector3, delta: float) -> void:
	head = camera
	left_target = left_hand
	right_target = right_hand
	global_position = Vector3(head.global_position.x, feet_y, head.global_position.z)
	var yaw := atan2(head.global_basis.z.x, head.global_basis.z.z)
	rotation.y = lerp_angle(rotation.y, yaw, minf(1.0, delta * 6.0))
	walk_speed = Vector2(motion.x, motion.z).length()
	walk_phase += delta * walk_speed * 4.0
	speed=walk_speed; movement=global_basis.inverse()*motion; phase=walk_phase/TAU
	var inverse:=pose_frame.affine_inverse()
	xr_pose={"head":inverse*head.global_transform,"left":inverse*left_hand.global_transform,"right":inverse*right_hand.global_transform,"body":body,"face":face}
	if face.has("mouth"): mouth.speak(face.mouth)
	mouth.express(face.get("expressions",PackedFloat32Array([0,0,0,0,0])))


func apply_tracking(frame: Transform3D, body_data: Dictionary, face_data: Dictionary) -> void:
	pose_frame=frame; body=body_data; face=face_data
