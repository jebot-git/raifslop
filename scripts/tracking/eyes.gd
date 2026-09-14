## Adapted from FPSloppa 5105fb8cfa38c76aa1d5d172af3047fe2d12ae0d.
extends Node
## Optional measured gaze / eyelids. No eye data is synthesized on unsupported devices.
var rig
var gaze: XRController3D
func setup(owner_rig: Node) -> void:
	rig=owner_rig
	gaze=rig.controller("EyeGaze","/user/eyes_ext","eye_gaze_pose")
func sample() -> Dictionary:
	if not rig.focused: return {}
	var result: Dictionary={"look":Vector2.ZERO,"blink":Vector2.ZERO,"gaze":false,"lids":false}
	if gaze.get_has_tracking_data():
		var direction: Vector3=-(rig.head.global_basis.inverse()*gaze.global_basis).z.normalized()
		result.look=Vector2(atan2(-direction.x,-direction.z),asin(clampf(direction.y,-1,1)))
		result.gaze=true
	var face:=XRServer.get_tracker("/user/face_tracker") as XRFaceTracker
	if face:
		result.blink=Vector2(face.get_blend_shape(XRFaceTracker.FT_EYE_CLOSED_LEFT),face.get_blend_shape(XRFaceTracker.FT_EYE_CLOSED_RIGHT))
		result.lids=true
		var jaw:=clampf(face.get_blend_shape(XRFaceTracker.FT_JAW_OPEN)-face.get_blend_shape(XRFaceTracker.FT_MOUTH_CLOSED),0,1)
		result.mouth=PackedFloat32Array([jaw,0,0,0,0])
		var expressions := preload("res://scripts/tracking/face_expressions.gd").sample(face)
		result.expressions=PackedFloat32Array([expressions[0],expressions[1],expressions[2],expressions[4],expressions[3]])
		if not result.gaze:
			var horizontal: float=(face.get_blend_shape(XRFaceTracker.FT_EYE_LOOK_OUT_LEFT)-face.get_blend_shape(XRFaceTracker.FT_EYE_LOOK_IN_LEFT)+face.get_blend_shape(XRFaceTracker.FT_EYE_LOOK_IN_RIGHT)-face.get_blend_shape(XRFaceTracker.FT_EYE_LOOK_OUT_RIGHT))*.5
			var vertical: float=(face.get_blend_shape(XRFaceTracker.FT_EYE_LOOK_UP_LEFT)+face.get_blend_shape(XRFaceTracker.FT_EYE_LOOK_UP_RIGHT)-face.get_blend_shape(XRFaceTracker.FT_EYE_LOOK_DOWN_LEFT)-face.get_blend_shape(XRFaceTracker.FT_EYE_LOOK_DOWN_RIGHT))*.5
			result.look=Vector2(horizontal*.20944,vertical*.139626)
			result.gaze=true
	return preload("res://scripts/tracking/poses.gd").validate_face(result) if result.gaze or result.lids else {}
