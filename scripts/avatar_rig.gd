extends Node3D
signal right_grip_updated(pose: Transform3D)
const Scale = preload("res://scripts/avatar_scale.gd")
const IK = preload("res://scripts/avatar_ik.gd")
const RestBounds = preload("res://scripts/avatar_rest_bounds.gd")
var gait = preload("res://scripts/avatar_gait.gd").new()
var neutral_hip_height := 0.92
var neutral_foot_heights: Dictionary = {"left": 0.08, "right": 0.08}
var grounded := true
var collider_height := 1.65
var aim_pitch := 0.0
var tracked_leg_animation := false
var secondary_nodes: Array[Node] = []
var render_frame := Transform3D.IDENTITY
var right_index_tip: Variant = null
var right_index_tip_frame := -10
var index_tip_bone := -1
var index_tip_offset := Vector3.ZERO
var right_hand_bone := -1
var left_grip: Variant = null
var left_hand_bone := -1
var right_grip: Variant = null
var right_grip_frame := -10
var skeleton: Skeleton3D
var model: Node3D
var solver: SkeletonModifier3D
var head: Camera3D
var left_target: Node3D
var right_target: Node3D
var standing_height := Scale.HEAD_HEIGHT
var walk_phase := 0.0
var walk_speed := 0.0
var left_curl := 0.0
var pose_frame := Transform3D.IDENTITY
var xr_pose: Dictionary={}
var body: Dictionary={}
var face: Dictionary={}
var mouth: Node
var eyes: SkeletonModifier3D
var first_person := true:
	set(value):
		first_person = value
		for secondary in secondary_nodes: secondary.set_local_body(value)
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
	var diagnostic_started:=Time.get_ticks_usec()
	model = root
	skeleton = find_skeleton(root)
	if not skeleton: return false
	for bone in ["Hips", "Head", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot"]:
		if skeleton.find_bone(bone) < 0: return false
	root.rotation.y += PI
	# FPSloppa: measure skinned vertices in rest pose, including nested transforms.
	# Raw mesh bounds and head-bone height do not describe a VRM's actual size.
	var local_bounds: AABB = root.get_meta(RestBounds.CACHE_KEY) if root.has_meta(RestBounds.CACHE_KEY) else RestBounds.measure(root)
	var bounds: AABB = root.transform * local_bounds
	if not bounds.size.is_finite() or bounds.size.y < 0.05 or bounds.size.y > 1000: return false
	var factor := Scale.BODY_HEIGHT / bounds.size.y
	root.scale *= factor
	root.position *= factor
	root.position.y -= bounds.position.y * factor
	var transforms: Dictionary = {}
	RestBounds.collect(root, root.transform, transforms)
	var skeleton_transform: Transform3D = transforms[skeleton]
	neutral_hip_height = (skeleton_transform * skeleton.get_bone_global_rest(skeleton.find_bone("Hips")).origin).y
	for side in ["Left", "Right"]:
		neutral_foot_heights[side.to_lower()] = (skeleton_transform * skeleton.get_bone_global_rest(skeleton.find_bone(side+"Foot")).origin).y
	mouth=preload("res://scripts/avatar_mouth.gd").new(); add_child(mouth); mouth.setup(root)
	eyes=preload("res://scripts/avatar_eyes.gd").new(); eyes.rig=self
	# Capture the VRM expression bindings before stripping imported animation players.
	eyes.setup(root)
	mouth.external_mixer = true
	mouth.mixer = eyes.apply_morphs
	strip_extras(root)
	# generate_scene can restore pre-retarget glTF local poses after the VRM
	# extension has changed the rest frames. IK only overwrites humanoid limbs;
	# stale toes and skin helper offsets otherwise tear vertices out of the mesh.
	skeleton.reset_bone_poses()
	solver = IK.new()
	skeleton.add_child(solver)
	solver.setup(self)
	_setup_index_tip()
	right_hand_bone = skeleton.find_bone("RightHand")
	left_hand_bone = skeleton.find_bone("LeftHand")
	solver.modification_processed.connect(_capture_hand_attachments)
	skeleton.add_child(eyes)
	add_to_group("fishing_avatar_rigs")
	preload("res://scripts/client_diagnostics.gd").stage("avatar_rig",diagnostic_started)
	return true

func strip_extras(node: Node) -> void:
	if node is VRMSecondary:
		secondary_nodes.append(node)
		node.set_local_body(first_person)
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
	# One frame owns skeleton placement and all tracked targets. Rebase body samples
	# from the capsule frame before applying the player's heading (also remotely).
	var yaw := atan2(head.global_basis.z.x, head.global_basis.z.z)
	render_frame = Transform3D(Basis(Vector3.UP, yaw), Vector3(pose_frame.origin.x, feet_y, pose_frame.origin.z))
	global_transform = render_frame
	walk_speed = Vector2(motion.x, motion.z).length()
	walk_phase += delta * walk_speed * 4.0
	speed=walk_speed; movement=global_basis.inverse()*motion; phase=walk_phase/TAU
	var inverse := render_frame.affine_inverse()
	var local_body: Dictionary = {}
	for key in body:
		local_body[key] = inverse * pose_frame * body[key] if body[key] is Transform3D else body[key]
	xr_pose={"head":inverse*head.global_transform,"left":inverse*left_hand.global_transform,"right":inverse*right_hand.global_transform,"body":local_body,"face":face}
	collider_height = head.global_position.y - feet_y
	gait.update(delta, movement, "crouch" if collider_height < standing_height * 0.75 else "stand", grounded, local_body, tracked_leg_animation)
	if face.has("mouth"): mouth.speak(face.mouth)


func apply_tracking(frame: Transform3D, body_data: Dictionary, face_data: Dictionary) -> void:
	pose_frame=frame; body=body_data; face=face_data

func tracking_transform() -> Transform3D:
	return render_frame

func fit_tracked_hips(pose: Transform3D) -> Transform3D:
	pose.origin.y += neutral_hip_height - Scale.HIP_HEIGHT
	return pose

func fit_tracked_foot(side: String, pose: Transform3D) -> Transform3D:
	pose.origin.y += float(neutral_foot_heights.get(side, Scale.ANKLE_HEIGHT)) - Scale.ANKLE_HEIGHT
	return pose

func mesh_bounds(node: Node3D, parent_transform: Transform3D) -> AABB:
	return parent_transform * node.transform * RestBounds.measure(node)

func _setup_index_tip() -> void:
	index_tip_bone = skeleton.find_bone("RightIndexDistal")
	if index_tip_bone < 0: return
	var rest := skeleton.get_bone_global_rest(index_tip_bone)
	for child in skeleton.get_bone_children(index_tip_bone):
		var offset := rest.affine_inverse() * skeleton.get_bone_global_rest(child).origin
		if offset.length() > .001:
			index_tip_offset = offset
			return
	# VRMs may omit the terminal marker; estimate the final phalanx from its neighbour.
	var parent := skeleton.get_bone_parent(index_tip_bone)
	var length := rest.origin.distance_to(skeleton.get_bone_global_rest(parent).origin) * .75
	index_tip_offset = Vector3.UP * length

func _capture_hand_attachments() -> void:
	# Read while modifiers are applied. Godot restores raw poses after this signal.
	if left_hand_bone >= 0 and not xr_pose.is_empty():
		var wrist := skeleton.global_transform * skeleton.get_bone_global_pose(left_hand_bone)
		var grip_basis := wrist.basis.orthonormalized() * IK.controller_hand_basis(true).inverse()
		left_grip = Transform3D(grip_basis, wrist.origin - grip_basis.y * .06)
	if right_hand_bone >= 0 and not xr_pose.is_empty():
		var wrist := skeleton.global_transform * skeleton.get_bone_global_pose(right_hand_bone)
		# Undo the controller-to-humanoid axes and wrist offset used by IK.
		# Strip model scale so the rod keeps its physical size on every VRM.
		var grip_basis := wrist.basis.orthonormalized() * IK.controller_hand_basis(false).inverse()
		right_grip = Transform3D(grip_basis, wrist.origin - grip_basis.y * .06)
		right_grip_frame = Engine.get_process_frames()
		right_grip_updated.emit(right_grip)
	if index_tip_bone >= 0:
		right_index_tip = skeleton.to_global(skeleton.get_bone_global_pose(index_tip_bone) * index_tip_offset)
		right_index_tip_frame = Engine.get_process_frames()

func hand_grip_pose(left_hand := false) -> Variant:
	return (left_grip if left_hand else right_grip) if Engine.get_process_frames() - right_grip_frame <= 2 else null

func index_touch_position() -> Variant:
	return right_index_tip if Engine.get_process_frames() - right_index_tip_frame <= 2 else null
