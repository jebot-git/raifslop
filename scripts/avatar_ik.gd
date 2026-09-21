## Adapted from FPSloppa 28a719a84454ef94ac6683f11b709735948e12b9; fishing supplies hand targets.
extends SkeletonModifier3D
## Analytical two-bone IK. Targets are in arena metres, solved in skeleton space.
var rig
var rest: Dictionary = {}
var bone_ids: Dictionary={}
var floor_tick:=0.0
var solve_tick:=0.0
var cached_poses: Dictionary={}
var floor_heights: Dictionary={}
func bone(sk: Skeleton3D, name_here: String) -> int:
	if not bone_ids.has(name_here): bone_ids[name_here]=sk.find_bone(name_here)
	return bone_ids[name_here]

func _process_modification_with_delta(_delta: float) -> void:
	var sk := get_skeleton()
	if not sk or not rig:return
	floor_tick-=_delta
	var sample_floor:=floor_tick<=0
	if sample_floor: floor_tick=.08
	var camera:=get_viewport().get_camera_3d()
	var distance: float=rig.global_position.distance_to(camera.global_position) if camera else 0.0
	solve_tick-=_delta
	if not rig.first_person and solve_tick>0 and not cached_poses.is_empty():
		for index in cached_poses:
			sk.set_bone_pose_rotation(index,cached_poses[index][0])
			sk.set_bone_pose_position(index,cached_poses[index][1])
		return
	solve_tick=0.0 if rig.first_person else 1.0/15.0 if distance>18 else 1.0/30.0 if distance>6 else 0.0
	if rest.is_empty():
		for i in range(sk.get_bone_count()): rest[i] = sk.get_bone_global_rest(i)
	# AnimationPlayer owns hip breathing / gait bob. Reset solved bones each frame.
	for name in ["Hips","LeftUpperLeg","LeftLowerLeg","LeftFoot","RightUpperLeg","RightLowerLeg","RightFoot","LeftShoulder","RightShoulder","LeftUpperArm","LeftLowerArm","RightUpperArm","RightLowerArm","LeftHand","RightHand","Head","Chest","UpperChest"]:
		var index := bone(sk,name)
		if index>=0:
			sk.set_bone_pose_rotation(index,sk.get_bone_rest(index).basis.get_rotation_quaternion())
			sk.set_bone_pose_position(index,sk.get_bone_rest(index).origin)
	var body: Dictionary=rig.xr_pose.get("body",{}) if not rig.dead else {}
	var hips:=bone(sk,"Hips")
	var offset:=Vector3.ZERO
	if not rig.xr_pose.is_empty():
		offset=rig.xr_pose.head.origin-Vector3(0,rig.standing_height,0)
		offset=Vector3(offset.x*.45,clampf(offset.y,-.90,.1),offset.z*.45)
	else:
		offset.y=rig.collider_height-rig.standing_height
	if rig.gait.prone_blend>0:
		offset=offset.lerp(Vector3(0,.30-rig.neutral_hip_height,.35),rig.gait.prone_blend)
	if not body.has("hips"):
		offset.y+=rig.gait.bob-rig.gait.landing*.5
		var local_offset: Vector3=sk.global_basis.inverse()*rig.global_basis*offset
		sk.set_bone_pose_position(hips,sk.get_bone_rest(hips).origin+local_offset)
		if rig.gait.prone_blend>0:
			orient(sk,hips,rig.global_basis*Basis(Vector3.RIGHT,-PI*.43*rig.gait.prone_blend)*reference_basis(sk,hips))
	if body.has("hips"):
		var target: Transform3D=rig.tracking_transform()*rig.fit_tracked_hips(body.hips)
		var parent:=sk.get_bone_parent(hips)
		var local: Vector3=sk.to_local(target.origin)
		if parent>=0: local=sk.get_bone_global_pose(parent).affine_inverse()*local
		sk.set_bone_pose_position(hips,local)
		orient(sk,hips,target.basis*reference_basis(sk,hips))
	if body.has("chest"):
		orient(sk,bone(sk,"Chest"),rig.tracking_transform().basis*body.chest.basis*reference_basis(sk,bone(sk,"Chest")))
	if not rig.xr_pose.is_empty():
		var head_index:=bone(sk,"Head")
		var head_target:Transform3D=rig.tracking_transform()*rig.xr_pose.head
		orient(sk,head_index,head_target.basis*reference_basis(sk,head_index))
		# Estimated bodies follow the eyes. With FBT, the pelvis and torso belong
		# to the body trackers: translating Chest to fit the eyes stretches or
		# collapses the seated torso and moves both shoulder roots. Fit only the
		# head in that case; never change the tracking origin or tracked pelvis.
		var anchor:=head_index if body.has("hips") else hips
		var correction:Vector3=sk.global_basis.inverse()*(head_target.origin-rig.viewpoint_position())
		var anchor_parent:=sk.get_bone_parent(anchor)
		if anchor_parent>=0:correction=sk.get_bone_global_pose(anchor_parent).basis.inverse()*correction
		sk.set_bone_pose_position(anchor,sk.get_bone_pose_position(anchor)+correction)
	for side in ["Left","Right"]:
		var sign_x := -1.0 if side=="Left" else 1.0
		var foot_idx := bone(sk,side+"Foot")
		if foot_idx<0 or bone(sk,side+"UpperLeg")<0:continue
		var neutral: Vector3 = rig.to_local(sk.to_global(rest[foot_idx].origin))
		var foot: Vector3=Vector3(sign_x*.13,neutral.y,neutral.z)+rig.gait.offsets[side.to_lower()]
		if rig.preview_mode<0 and rig.is_inside_tree() and sample_floor and rig.grounded:
			var world_foot: Vector3 = rig.to_global(foot)
			var query := PhysicsRayQueryParameters3D.create(world_foot+Vector3.UP*.4,world_foot-Vector3.UP*.5,1)
			var hit: Dictionary = rig.get_world_3d().direct_space_state.intersect_ray(query)
			floor_heights[side]=rig.to_local(hit.position).y+neutral.y if not hit.is_empty() else neutral.y
		if rig.grounded and floor_heights.has(side): foot.y=maxf(foot.y,floor_heights[side])
		var foot_world: Vector3=rig.to_global(foot)
		var hip_world:Vector3=sk.to_global(sk.get_bone_global_pose(bone(sk,side+"UpperLeg")).origin)
		var knee_world: Vector3=hip_world+rig.tracking_transform().basis*Vector3(sign_x*.08,0,-.65)
		if body.has(side.to_lower()+"_foot"):
			foot_world=(rig.tracking_transform()*rig.fit_tracked_foot(side.to_lower(),body[side.to_lower()+"_foot"])).origin
			foot_world+=rig.global_basis*rig.gait.offsets[side.to_lower()]*rig.gait.assist_weight*.6
		elif rig.gait.prone_blend>.5:
			knee_world=hip_world+rig.global_basis*Vector3(sign_x*.25,-.3,.45)
		if body.has("hips") and not body.has(side.to_lower()+"_knee"):
			knee_world=leg_pole(body,side.to_lower(),hip_world,rig.tracking_transform())
		if body.has(side.to_lower()+"_knee"):
			knee_world=(rig.tracking_transform()*body[side.to_lower()+"_knee"]).origin
			knee_world+=rig.global_basis*rig.gait.offsets[side.to_lower()]*rig.gait.assist_weight*.5
		solve(sk,side+"UpperLeg",side+"LowerLeg",side+"Foot",foot_world,knee_world)
		var foot_parent := sk.get_bone_parent(foot_idx)
		sk.set_bone_pose_rotation(foot_idx,((sk.get_bone_global_pose(foot_parent).basis.inverse() if foot_parent>=0 else Basis.IDENTITY)*rest[foot_idx].basis).get_rotation_quaternion())
		if body.has(side.to_lower()+"_foot"):
			orient(sk,foot_idx,rig.tracking_transform().basis*body[side.to_lower()+"_foot"].basis*reference_basis(sk,foot_idx))
		var hand := bone(sk,side+"Hand")
		if hand<0:continue
		if not rig.xr_pose.is_empty():
			var target: Transform3D=rig.tracking_transform()*rig.xr_pose[side.to_lower()]
			var optical:=body.has(side.to_lower()+"_hand")
			if optical: target=rig.tracking_transform()*body[side.to_lower()+"_hand"]
			else: target.origin+=target.basis.y*.06 # Grip is at the palm, IK ends at the wrist.
			var shoulder:Vector3=sk.to_global(sk.get_bone_global_pose(bone(sk,side+"UpperArm")).origin)
			var elbow: Vector3=shoulder+rig.global_basis*Vector3(sign_x*.35,-.45,.10)
			if body.has(side.to_lower()+"_elbow"): elbow=(rig.tracking_transform()*body[side.to_lower()+"_elbow"]).origin
			move_shoulder(sk, side, target.origin)
			solve(sk,side+"UpperArm",side+"LowerArm",side+"Hand",target.origin,elbow)
			var parent:=sk.get_bone_parent(hand)
			# OpenXR grip -Z runs little-finger to thumb; it is not the aim/finger axis.
			# Humanoid hands use +Y along fingers and +Z toward the palm.
			var palm_basis: Basis=target.basis if optical else target.basis*controller_hand_basis(side=="Left")
			align_forearm(sk, side, palm_basis)
			var desired: Basis=sk.global_basis.orthonormalized().inverse()*palm_basis
			sk.set_bone_pose_rotation(hand,((sk.get_bone_global_pose(parent).basis.orthonormalized().inverse() if parent>=0 else Basis.IDENTITY)*desired).get_rotation_quaternion())
		pose_fingers(sk, side, body)

	var head := bone(sk,"Head")
	if head>=0:
		var q := sk.get_bone_rest(head).basis.get_rotation_quaternion()
		if rig.xr_pose.is_empty():
			if rig.gait.prone_blend>.01:orient(sk,head,rig.global_basis*Basis(Vector3.RIGHT,rig.aim_pitch*.55)*reference_basis(sk,head))
			else:sk.set_bone_pose_rotation(head,q*Quaternion(Vector3.RIGHT,rig.aim_pitch*.55))
		else:
			var target: Basis=rig.tracking_transform().basis*rig.xr_pose.head.basis*reference_basis(sk,head)
			var parent:=sk.get_bone_parent(head)
			sk.set_bone_pose_rotation(head,((sk.get_bone_global_pose(parent).basis.orthonormalized().inverse() if parent>=0 else Basis.IDENTITY)*sk.global_basis.orthonormalized().inverse()*target).get_rotation_quaternion())

	for index in bone_ids.values():
		if index>=0: cached_poses[index]=[sk.get_bone_pose_rotation(index),sk.get_bone_pose_position(index)]

func solve(sk: Skeleton3D, upper: String, lower: String, end: String, target_world: Vector3, pole_world: Vector3) -> void:
	var a := bone(sk,upper)
	var b := bone(sk,lower)
	var c := bone(sk,end)
	if a<0 or b<0 or c<0: return
	var origin := sk.get_bone_global_pose(a).origin
	var middle := sk.get_bone_global_pose(b).origin
	var tip := sk.get_bone_global_pose(c).origin
	var l1 := origin.distance_to(middle)
	var l2 := middle.distance_to(tip)
	if minf(l1,l2)<.0001: return
	var target := sk.to_local(target_world)
	var direction := (target-origin).normalized()
	if direction.length()<.5: return
	var distance := clampf(origin.distance_to(target),absf(l1-l2)+.001,l1+l2-.001)
	var elbow := elbow_position(origin,target,sk.to_local(pole_world),l1,l2)
	# A shortest-arc swing only reaches the target; it leaves roll unconstrained.
	# Use the elbow/knee plane for both segments and preserve the retargeted
	# axes (Humanoid upper/lower limbs do not share the same local axes).
	var endpoint := origin + direction * distance
	var normal := (elbow-origin).cross(endpoint-elbow).normalized()
	var rest_hinge := sk.get_bone_global_rest(b).basis.x
	align_segment(sk, a, sk.get_bone_global_rest(b).origin-rest[a].origin, rest_hinge, elbow-origin, normal)
	middle = sk.get_bone_global_pose(b).origin
	align_segment(sk, b, sk.get_bone_global_rest(c).origin-rest[b].origin, rest_hinge, endpoint-middle, normal)

func align_segment(sk: Skeleton3D, index: int, rest_direction: Vector3, rest_hinge: Vector3, direction: Vector3, hinge: Vector3) -> void:
	var source := segment_frame(rest_direction, rest_hinge)
	var target := segment_frame(direction, hinge)
	var desired: Basis = target * source.inverse() * rest[index].basis.orthonormalized()
	orient(sk, index, sk.global_basis.orthonormalized() * desired)

static func segment_frame(direction: Vector3, hinge: Vector3) -> Basis:
	var y := direction.normalized()
	var x := (hinge-y*hinge.dot(y)).normalized()
	if x.length_squared() < .5:
		x = y.cross(Vector3.FORWARD).normalized()
		if x.length_squared() < .5: x = y.cross(Vector3.RIGHT).normalized()
	return Basis(x, y, x.cross(y)).orthonormalized()

func move_shoulder(sk: Skeleton3D, side: String, target: Vector3) -> void:
	var shoulder := bone(sk, side+"Shoulder")
	var arm := bone(sk, side+"UpperArm")
	if shoulder < 0 or arm < 0: return
	var base := sk.get_bone_global_pose(shoulder).origin
	var outward := sk.get_bone_global_pose(arm).origin-base
	var reach := sk.to_local(target)-base
	if reach.length_squared() < .001: return
	var swing := Quaternion(outward.normalized(), reach.normalized())
	var angle := swing.get_angle()
	if angle > .001:
		var amount := minf(.3, deg_to_rad(25)/angle)
		rotate_bone_toward(sk, shoulder, outward, Quaternion.IDENTITY.slerp(swing, amount)*outward)

func align_forearm(sk: Skeleton3D, side: String, palm: Basis) -> void:
	# Carry pronation through the forearm instead of twisting only the wrist's
	# ring of skin vertices. Swing back onto the solved segment to keep its end.
	var lower := bone(sk, side+"LowerArm")
	var hand := bone(sk, side+"Hand")
	var delta := sk.get_bone_global_pose(hand).origin-sk.get_bone_global_pose(lower).origin
	var desired: Basis = sk.global_basis.orthonormalized().inverse()*palm*rest[hand].basis.inverse()*rest[lower].basis
	var child_axis: Vector3 = rest[lower].basis.inverse()*(rest[hand].origin-rest[lower].origin)
	var swing := Quaternion((desired*child_axis).normalized(), delta.normalized())
	orient(sk, lower, sk.global_basis.orthonormalized()*Basis(swing)*desired)

func pose_fingers(sk: Skeleton3D, side: String, body: Dictionary) -> void:
	var native: Dictionary = body.get(side.to_lower()+"_finger_rotations", {})
	var hand := bone(sk, side+"Hand")
	var palm := sk.global_basis.orthonormalized()*sk.get_bone_global_pose(hand).basis.orthonormalized()
	for f in 5:
		var finger: String = ["Thumb","Index","Middle","Ring","Little"][f]
		var joints: Array = ["Metacarpal","Proximal","Distal"] if f == 0 else ["Proximal","Intermediate","Distal"]
		for j in 3:
			var ending: String = finger+joints[j]
			var index := bone(sk, side+ending)
			if index < 0: continue
			if native.has(ending):
				orient(sk, index, palm*native[ending])
			else:
				var curl: float = body.get(side.to_lower()+"_curls", PackedFloat32Array([.4,.4,.4,.4,.4]))[f]
				var angles: Array = [.35,.65,.55] if f == 0 else [1.1,1.35,.85]
				sk.set_bone_pose_rotation(index,sk.get_bone_rest(index).basis.get_rotation_quaternion()*Quaternion(Vector3.RIGHT,clampf(curl,0,1)*angles[j]))

func rotate_bone_toward(sk: Skeleton3D, index: int, source: Vector3, destination: Vector3) -> void:
	if source.length_squared()<.000001 or destination.length_squared()<.000001: return
	var global_basis := sk.get_bone_global_pose(index).basis.orthonormalized()
	var change := Quaternion(source.normalized(),destination.normalized())
	var parent := sk.get_bone_parent(index)
	var parent_basis := sk.get_bone_global_pose(parent).basis.orthonormalized() if parent>=0 else Basis.IDENTITY
	sk.set_bone_pose_rotation(index,(parent_basis.inverse()*Basis(change)*global_basis).get_rotation_quaternion())

func orient(sk: Skeleton3D,index: int,world_basis: Basis) -> void:
	if index<0: return
	var parent:=sk.get_bone_parent(index)
	var parent_basis:=sk.get_bone_global_pose(parent).basis.orthonormalized() if parent>=0 else Basis.IDENTITY
	sk.set_bone_pose_rotation(index,(parent_basis.inverse()*sk.global_basis.orthonormalized().inverse()*world_basis.orthonormalized()).get_rotation_quaternion())

func reference_basis(sk: Skeleton3D,index: int) -> Basis:
	# Preserve each retargeted bone's authored axis convention (feet differ from hips).
	# Optional humanoid bones (notably Chest) can be absent from a valid VRM.
	if index<0 or index>=sk.get_bone_count():return Basis.IDENTITY
	var frame:Basis=rig.global_basis if rig.dead else rig.tracking_transform().basis
	return frame.orthonormalized().inverse()*sk.global_basis.orthonormalized()*sk.get_bone_global_rest(index).basis.orthonormalized()

static func controller_hand_basis(left_hand: bool) -> Basis:
	var sign_side:=1.0 if left_hand else -1.0
	return Basis(Vector3.BACK*sign_side,Vector3.DOWN,Vector3.RIGHT*sign_side)

static func leg_pole(body: Dictionary,side: String,hip: Vector3,frame: Transform3D) -> Vector3:
	var pelvis:Basis=frame.basis*body.hips.basis
	var forward:Vector3=-pelvis.z;forward.y=0
	if forward.length()<.1:forward=-frame.basis.z;forward.y=0
	forward=forward.normalized()
	var foot=body.get(side+"_foot")
	if foot is Transform3D:
		var toe:Vector3=-(frame.basis*foot.basis).z;toe.y=0
		if toe.length()>.1:
			var angle:=forward.signed_angle_to(toe.normalized(),Vector3.UP)
			forward=forward.rotated(Vector3.UP,clampf(angle,-PI/6,PI/6)*.5)
	return hip+forward*.65+forward.cross(Vector3.UP)*(-.06 if side=="left" else .06)

func setup(avatar: Node3D) -> void:
	rig=avatar

static func elbow_position(a: Vector3, target: Vector3, pole: Vector3, upper: float, lower: float) -> Vector3:
	var offset := target - a
	var axis := offset.normalized() if offset.length() > 0.0001 else Vector3.DOWN
	var distance := clampf(offset.length(), absf(upper - lower) + 0.001, upper + lower - 0.001)
	var along := (upper * upper - lower * lower + distance * distance) / (2.0 * distance)
	var height := sqrt(maxf(0.0, upper * upper - along * along))
	var bend := pole - a
	bend -= axis * bend.dot(axis)
	if bend.length_squared() < 0.0001:
		bend = axis.cross(Vector3.RIGHT)
		if bend.length_squared() < 0.0001: bend = axis.cross(Vector3.UP)
	return a + axis * along + bend.normalized() * height
