extends RefCounted
## Reject controller discontinuities before extending the pose into a long rod tip.
const HELD_POSE=preload("res://scripts/rod_holster.gd").HELD_POSE
var previous:=Transform3D.IDENTITY
var ready:=false
var status:="unseeded"
func reset(pose:Transform3D)->void:
	previous=pose;ready=valid_pose(pose);status="seeded"
static func valid_pose(pose:Transform3D)->bool:
	return pose.is_finite() and absf(pose.basis.determinant())>.01
static func tip(pose:Transform3D)->Vector3:
	return pose*HELD_POSE*Vector3(0,0,-1.68)
func sample(pose:Transform3D,dt:float,tracked:bool)->Dictionary:
	if not tracked or not valid_pose(pose):ready=false;status="tracking_lost";return {}
	var old:=previous;previous=pose
	if not ready:ready=true;status="seeded";return {}
	if not is_finite(dt) or dt<=0 or dt>.1:status="interval";return {}
	var distance:=pose.origin.distance_to(old.origin)
	var angle:=old.basis.orthonormalized().get_rotation_quaternion().angle_to(pose.basis.orthonormalized().get_rotation_quaternion())
	# Controller translation and rotation have separate limits. A 1.68 m lever
	# can legitimately travel >0.5 m/frame while the hand moves only centimetres.
	if distance>maxf(.15,12.0*dt) or angle>maxf(deg_to_rad(25),65.0*dt):
		status="discontinuity";return {}
	status="accepted"
	return {"movement":tip(pose)-tip(old),"tip":tip(pose),"hand_distance":distance,"angle":angle}
