extends RefCounted
## Render-clock rigid-pose sweep of the complete clubhead against the ball sphere.
const Turf=preload("res://addons/golfminus/scripts/golf/club_turf.gd")
var turf:=Turf.new()
var previous:=Vector3.ZERO
var previous_pose:=Transform3D.IDENTITY
var valid:=false
var filtered_velocity:=Vector3.ZERO
var filtered_angular:=Vector3.ZERO
var cooldown:=0.0
var last_sample:Dictionary={}
func reset()->void:
	turf.reset()
	valid=false;filtered_velocity=Vector3.ZERO;filtered_angular=Vector3.ZERO;cooldown=.15
func sample(head:Vector3,ball:Vector3,dt:float,active:bool)->Dictionary:
	return sample_pose(Transform3D(Basis.IDENTITY,head),preload("res://addons/golfminus/scripts/golf/club_head.gd").for_club(7),ball,dt,active)
func sample_pose(pose:Transform3D,shape:RefCounted,ball:Vector3,dt:float,active:bool,ball_velocity:=Vector3.ZERO,terrain:RefCounted=null)->Dictionary:
	cooldown=maxf(0,cooldown-dt)
	last_sample={"dt_s":dt,"head":pose.origin,"ball":ball,"active":active,"status":"inactive"}
	if not is_finite(dt) or dt<=0 or dt>.05 or not ball.is_finite() or not ball_velocity.is_finite() or not pose.origin.is_finite() or not pose.basis.is_finite() or absf(pose.basis.determinant())<.01:
		last_sample.status="invalid_interval" if dt<=0 or dt>.05 else "inactive"
		reset();return {}
	pose.basis=pose.basis.orthonormalized()
	if not active:
		# Keep tracking a known pose while the grip is released. Arming should
		# not impose a fresh 150 ms blind interval on a short chip or putt.
		turf.reset()
		previous_pose=pose;previous=pose.origin;valid=true
		filtered_velocity=Vector3.ZERO;filtered_angular=Vector3.ZERO
		return {}
	if not valid:previous_pose=pose;previous=pose.origin;valid=true;last_sample.status="priming";return {}
	var raw:Vector3=(pose.origin-previous_pose.origin)/dt
	var rotation:Quaternion=pose.basis.get_rotation_quaternion()*previous_pose.basis.get_rotation_quaternion().inverse()
	if rotation.w<0:rotation=-rotation
	var angular:Vector3=rotation.get_axis()*rotation.get_angle()/dt
	if raw.length()>65 or angular.length()>90:
		last_sample.status="discontinuity";reset();return {}
	var weight:=1.0-exp(-dt/.0106)
	filtered_velocity=filtered_velocity.lerp(raw,weight);filtered_angular=filtered_angular.lerp(angular,weight)
	last_sample.merge({"raw_velocity":raw,"filtered_velocity":filtered_velocity,"raw_angular_velocity":angular,"filtered_angular_velocity":filtered_angular,"cooldown_s":cooldown},true)
	var start:=previous_pose
	previous_pose=pose;previous=pose.origin
	last_sample.status="cooldown" if cooldown>0 else "miss"
	if cooldown>0:turf.reset();return {}
	var hit:Dictionary=shape.sweep(start,pose,ball,ball_velocity*dt)
	# Only integrate terrain up to the first ball contact, never the follow-through.
	turf.sweep(start,pose,shape,terrain,dt,float(hit.get("fraction",1.0)),raw)
	if hit.is_empty():return {}
	if not hit.has("normal"):last_sample.status="invalid_contact";return {}
	# Closing is checked at the actual contact point, including head rotation.
	var raw_point:Vector3=raw+angular.cross(hit.contact-hit.head_center)
	if (raw_point-ball_velocity).dot(hit.normal)<=.03:return {}
	var velocity:=filtered_velocity;var spin:=filtered_angular
	# A just-reversed chip can be entering the mesh while the low-pass history
	# still points away. Use the measured sweep in that case, not a rejected hit.
	if (velocity+spin.cross(hit.contact-hit.head_center)-ball_velocity).dot(hit.normal)<=.03:
		velocity=raw;spin=angular
	var resistance:Dictionary=turf.attenuate(velocity,spin,shape,hit.head_basis)
	velocity*=float(resistance.speed_scale);spin*=float(resistance.speed_scale)
	hit.turf=resistance
	turf.reset()
	cooldown=.8;last_sample.status="contact"
	hit.merge({"velocity":velocity,"raw_velocity":raw,"angular_velocity":spin,"raw_angular_velocity":angular,"ball_velocity":ball_velocity},true)
	last_sample.merge(hit,true)
	return hit
