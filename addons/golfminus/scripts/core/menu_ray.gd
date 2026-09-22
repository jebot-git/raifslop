extends RefCounted
## Render from the fingertip, but aim from the runtime's stable pointer pose.
static func sample(game) -> Dictionary:
	if not game.xr or not game.focused: return {}
	var controller_valid: bool = game.right.get_has_tracking_data()
	var hand := XRServer.get_tracker("/user/hand_tracker/right") as XRHandTracker
	var tip: Variant = null
	var direction: Vector3 = -game.right.global_basis.z
	var source := "avatar"
	# Controller-inferred finger joints bend with trigger input; they are not aim.
	if hand and hand.has_tracking_data and hand.hand_tracking_source != XRHandTracker.HAND_TRACKING_SOURCE_CONTROLLER and (hand.hand_tracking_source == XRHandTracker.HAND_TRACKING_SOURCE_UNOBSTRUCTED or not controller_valid):
		var tip_joint := XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP
		var distal := XRHandTracker.HAND_JOINT_INDEX_FINGER_PHALANX_DISTAL
		var valid := XRHandTracker.HAND_JOINT_FLAG_POSITION_VALID
		if hand.get_hand_joint_flags(tip_joint) & valid and hand.get_hand_joint_flags(distal) & valid:
			var point: Vector3 = hand.get_hand_joint_transform(tip_joint).origin
			var base: Vector3 = hand.get_hand_joint_transform(distal).origin
			if point.is_finite() and base.is_finite() and point.distance_to(base) > .003:
				tip = game.origin.to_global(point * XRServer.world_scale)
				direction = (game.origin.global_basis * (point-base)).normalized()
				source = "native"
	if tip == null:
		if not controller_valid: return {}
		var avatar = game.host_game.avatar if is_instance_valid(game.host_game) else null
		tip = avatar.index_touch_position() if is_instance_valid(avatar) else null
		if not tip is Vector3 or not tip.is_finite():
			tip = game.right.to_global(Vector3(.02,.01,-.085))
			source = "estimated"
	var aim_origin: Vector3 = tip if source == "native" else game.right.global_position
	var tracker := XRServer.get_tracker(game.right.tracker) as XRPositionalTracker
	if tracker and tracker.has_pose("aim"):
		var aim := tracker.get_pose("aim")
		if aim.has_tracking_data:
			var pose: Transform3D = game.origin.global_transform * aim.get_adjusted_transform()
			aim_origin = pose.origin
			direction = -pose.basis.z
	elif source != "native":
		aim_origin = game.right.global_position
	return {"origin":tip,"aim_origin":aim_origin,"direction":direction.normalized(),"source":source}
