extends RefCounted
## Fixed schema: no scene paths, objects, saved Guide data or client-supplied peer IDs.
const Poses=preload("res://scripts/tracking/poses.gd")
const Fish = preload("res://scripts/fishing_session.gd")
const TRANSFORMS = ["head", "left", "right", "rod", "fish"]
const VECTORS = ["feet", "motion", "tip", "bobber", "mouth", "target"]
static func capture(root: Node, serial: int) -> Dictionary:
	var size: float = root.game.journal.back().length if not root.game.journal.is_empty() else Fish.SPECIES[root.game.fish_index].length
	# Keep protocol 2 compatible: native per-knuckle detail stays local; peers
	# receive the established five curls and use the same controller fallback.
	var body: Dictionary = root.tracking_manager.body.duplicate() if is_instance_valid(root.tracking_manager) else {}
	body.erase("left_finger_rotations"); body.erase("right_finger_rotations")
	return {"body":body,"face":root.tracking_manager.face if is_instance_valid(root.tracking_manager) else {},"visemes":root.network.voice.mouth_pose(root.multiplayer.get_unique_id()),"serial":serial,"location":root.current_location,"head":root.head.global_transform,
		"left":root.left.global_transform if root.xr else root.desktop_left.global_transform,
		"right":root.right.global_transform if root.xr else root.rod.global_transform,
		"rod_tier":root.game.tackle.equipped,"reel_angle":fposmod(root.crank.rotation.x,TAU),"rod":root.rod.global_transform,"fish":root.fish_display.global_transform,
		"feet":root.motor.global_position,"motion":root.motor.last_motion,"tip":root.tip.global_position,
		"bobber":root.bobber.global_position,"mouth":root.fish_display.to_global(root._catch_mouth()),
		"target":root.cast_target,"state":int(root.game.state),"bait":root.game.bait,"species":root.game.fish_index,
		"length":size,"caught":root.fish_display.visible,"in_hand":root.catch_in_hand,"xr":root.xr,
		"left_valid":not root.xr or root.left.get_has_tracking_data(),"right_valid":not root.xr or root.right.get_has_tracking_data(),
		"curl":root.avatar.left_curl if is_instance_valid(root.avatar) else 0.0}
static func valid(data: Dictionary) -> bool:
	if data.size()!=28: return false
	if not data.get("body") is Dictionary or not data.get("face") is Dictionary: return false
	if Poses.validate_body(data.body).size()!=data.body.size() or Poses.validate_face(data.face).size()!=data.face.size(): return false
	if not Poses.valid_weights(data.get("visemes")): return false
	for key in TRANSFORMS:
		if not data.get(key) is Transform3D: return false
		var t: Transform3D = data[key]
		if not bounded(t.origin) or not t.basis.is_finite(): return false
		for axis in [t.basis.x,t.basis.y,t.basis.z]:
			if absf(axis.length()-1.0)>.05: return false
		if absf(t.basis.determinant()-1.0)>.1: return false
	for key in VECTORS:
		if not data.get(key) is Vector3 or not bounded(data[key]): return false
	for key in ["serial","state","bait","species","rod_tier"]:
		if not data.get(key) is int: return false
	if data.serial<0 or data.serial>2147483647 or data.state<0 or data.state>6 or data.bait<0 or data.bait>=Fish.BAITS.size() or data.species<0 or data.species>=Fish.SPECIES.size(): return false
	if not data.get("location") is String or not Fish.LOCATION_SPECIES.has(data.location): return false
	for key in ["length","curl","reel_angle"]:
		if not (data.get(key) is float or data.get(key) is int) or not is_finite(data[key]): return false
	if data.rod_tier<0 or data.rod_tier>=4 or data.reel_angle<0 or data.reel_angle>TAU: return false
	if data.length<=0 or data.length>500 or data.curl<0 or data.curl>1: return false
	for key in ["caught","in_hand","xr","left_valid","right_valid"]:
		if not data.get(key) is bool: return false
	if data.caught and data.state!=Fish.State.LANDED: return false
	return true
static func bounded(v: Vector3) -> bool:
	return v.is_finite() and maxf(absf(v.x),maxf(absf(v.y),absf(v.z)))<2048
static func event_key(data: Dictionary) -> Array:
	return [data.location,data.state,data.bait,data.species,data.length,data.caught,data.in_hand,data.rod_tier]
