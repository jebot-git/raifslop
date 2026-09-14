extends RefCounted
## UI aim starts at the finger; rod transforms never participate.
static func sample(game) -> Dictionary:
	if not game.xr or not game.tracking_manager.focused: return {}
	var hand := XRServer.get_tracker("/user/hand_tracker/right") as XRHandTracker
	if hand and hand.has_tracking_data:
		var tip_joint := XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP
		var distal := XRHandTracker.HAND_JOINT_INDEX_FINGER_PHALANX_DISTAL
		var valid := XRHandTracker.HAND_JOINT_FLAG_POSITION_VALID
		if hand.get_hand_joint_flags(tip_joint) & valid and hand.get_hand_joint_flags(distal) & valid:
			var tip: Vector3 = hand.get_hand_joint_transform(tip_joint).origin
			var base: Vector3 = hand.get_hand_joint_transform(distal).origin
			if tip.is_finite() and base.is_finite() and tip.distance_to(base) > .003:
				return {"origin":game.origin.to_global(tip * XRServer.world_scale),"direction":(game.origin.global_basis*(tip-base)).normalized(),"source":"native"}
	if not game.right.get_has_tracking_data(): return {}
	var tip = game.avatar.index_touch_position() if is_instance_valid(game.avatar) else null
	var source := "avatar"
	if not tip is Vector3 or not tip.is_finite():
		# VRM finger bones are optional. Keep the menu usable with a fingerless
		# avatar using an approximate fingertip relative to the tracked grip.
		tip = game.right.to_global(Vector3(.02,.01,-.085))
		source = "estimated"
	# The aim pose stays stable while the trigger curls the visible finger.
	var direction: Vector3 = -game.right.global_basis.z
	var tracker := XRServer.get_tracker(game.right.tracker) as XRPositionalTracker
	if tracker and tracker.has_pose("aim"):
		var aim := tracker.get_pose("aim")
		if aim.has_tracking_data: direction = -(game.origin.global_basis * aim.get_adjusted_transform().basis.z)
	return {"origin":tip,"direction":direction.normalized(),"source":source}
