## Adapted from FPSloppa 5105fb8cfa38c76aa1d5d172af3047fe2d12ae0d.
extends RefCounted
static func held_weapon(grip: Transform3D, aim: Transform3D) -> Transform3D:
	# Position at the palm, but preserve the runtime's independent aim direction.
	return Transform3D(aim.basis,grip.origin)

## Pose validation bounds room-scale requests; movement still uses the shared capsule.
static func valid_transform(value: Variant) -> bool:
	if not value is Transform3D or not value.origin.is_finite() or not value.basis.is_finite(): return false
	if absf(value.basis.determinant()-1.0)>.05: return false
	for axis in [value.basis.x,value.basis.y,value.basis.z]:
		if absf(axis.length()-1.0)>.02: return false
	return absf(value.basis.x.dot(value.basis.y))<.02 and absf(value.basis.x.dot(value.basis.z))<.02 and absf(value.basis.y.dot(value.basis.z))<.02
static func validate_body(value: Variant) -> Dictionary:
	if not value is Dictionary or value.size()>14: return {}
	var result: Dictionary={}
	for key in value:
		if key in ["left_curls","right_curls"]:
			if not value[key] is PackedFloat32Array or value[key].size()!=5: return {}
			for curl in value[key]:
				if not is_finite(curl) or curl<0 or curl>1: return {}
		elif key in ["left_finger_rotations","right_finger_rotations"]:
			if not value[key] is Dictionary or value[key].size()>15: return {}
			for joint in value[key]:
				if joint not in ["ThumbMetacarpal","ThumbProximal","ThumbDistal","IndexProximal","IndexIntermediate","IndexDistal","MiddleProximal","MiddleIntermediate","MiddleDistal","RingProximal","RingIntermediate","RingDistal","LittleProximal","LittleIntermediate","LittleDistal"]: return {}
				if not value[key][joint] is Basis or not valid_transform(Transform3D(value[key][joint],Vector3.ZERO)): return {}
		elif key in ["hips","chest","left_foot","right_foot","left_knee","right_knee","left_elbow","right_elbow","left_hand","right_hand"]:
			if not valid_transform(value[key]) or value[key].origin.distance_to(Vector3(0,1,0))>2.2: return {}
		else: return {}
		result[key]=value[key]
	return result

static func validate_face(value: Variant) -> Dictionary:
	if not value is Dictionary or value.size()<4 or value.size()>6: return {}
	if not value.get("look") is Vector2 or not value.get("blink") is Vector2: return {}
	if not value.get("gaze") is bool or not value.get("lids") is bool: return {}
	if not value.look.is_finite() or not value.blink.is_finite(): return {}
	var result:={"look":value.look.clamp(Vector2(-.20944,-.139626),Vector2(.20944,.139626)),"blink":value.blink.clamp(Vector2.ZERO,Vector2(.9,.9)),"gaze":value.gaze,"lids":value.lids}

	for key in ["mouth","expressions"]:
		if value.has(key):
			if not valid_weights(value[key]): return {}
			result[key]=value[key]
	for key in value:
		if key not in ["look","blink","gaze","lids","mouth","expressions"]: return {}
	return result

static func valid_weights(value: Variant) -> bool:
	if not value is PackedFloat32Array or value.size()!=5: return false
	for weight in value:
		if not is_finite(weight) or weight<0 or weight>1: return false
	return true
