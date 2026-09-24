extends RefCounted
## A preview never writes accepted preferences. Undo restores the complete prior fit.
var baseline:Dictionary={}
var candidate:Dictionary={}
var undo_state:Dictionary={}
var hand:=0
var capture_requested:=false
var samples:Array[Transform3D]=[]
var stable_seconds:=0.0
func sample_pose(pose:Transform3D,dt:float,tracked:bool)->void:
	if not tracked or dt<=0 or dt>.1 or not pose.origin.is_finite() or not pose.basis.is_finite() or absf(pose.basis.determinant())<.01:
		samples.clear();stable_seconds=0;return
	if not samples.is_empty():
		var first:=samples[0]
		if first.origin.distance_to(pose.origin)>.015 or first.basis.get_rotation_quaternion().angle_to(pose.basis.get_rotation_quaternion())>deg_to_rad(3):
			samples.clear();stable_seconds=0
	samples.append(pose);stable_seconds+=dt
	if samples.size()>90:samples.pop_front()
func stable_pose()->Dictionary:
	if stable_seconds<.4 or samples.size()<8:return {}
	var result:=samples[0]
	for i in range(1,samples.size()):result=result.interpolate_with(samples[i],1.0/(i+1))
	return {"pose":result}

func begin(reach:float,rotations:Array[Vector3],selected_hand:int,head_rotations:Array[Vector3]=[Vector3.ZERO,Vector3.ZERO],fitted:Array=[false,false])->void:
	baseline={"fitted":fitted.duplicate(),"reach":reach,"rotations":rotations.duplicate(),"head_rotations":head_rotations.duplicate()}
	candidate.clear();hand=selected_hand;capture_requested=false;samples.clear();stable_seconds=0
func stage(fit:Dictionary)->bool:
	if not fit.has_all(["reach","rotation","target"]):return false
	if not is_finite(fit.reach) or fit.reach<.35 or fit.reach>1.6 or not fit.rotation.is_finite() or not fit.target.is_finite():return false
	if not fit.get("head_rotation",Vector3.ZERO).is_finite():return false
	if not fit.get("pose_rotation",Vector3.ZERO).is_finite():return false
	if baseline.is_empty():return false
	candidate=fit.duplicate(true)
	if not candidate.has("pose_rotation"):candidate.rotation=baseline.rotations[hand]
	candidate.head_rotation=baseline.get("effective_head",baseline.head_rotations[hand])
	return true
func adjust(reach_delta:float)->void:
	if candidate.is_empty() or not is_finite(reach_delta):return
	candidate.reach=clampf(candidate.reach+reach_delta,.35,1.6)
func accept()->Dictionary:
	if candidate.is_empty() or baseline.is_empty():return {}
	undo_state=baseline.duplicate(true)
	var result:Dictionary=baseline.duplicate(true)
	# Keep the independent face profile; address fitting calibrates the grip
	# and shaft while a manual length adjustment preserves their rotations.
	result.reach=candidate.reach
	if candidate.has("pose_rotation"):
		if not result.has("pose_rotations"):result.pose_rotations=[Vector3.ZERO,Vector3.ZERO]
		result.pose_rotations[hand]=candidate.pose_rotation
		result.rotations[hand]=candidate.rotation
	cancel();return result
func cancel()->void:
	baseline.clear();candidate.clear();capture_requested=false;samples.clear();stable_seconds=0
func undo()->Dictionary:
	var result:=undo_state.duplicate(true)
	undo_state.clear();return result
