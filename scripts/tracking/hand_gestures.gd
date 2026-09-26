extends RefCounted
## Distances are tracking-space metres, independent of avatar and world scale.
const Hands=preload("res://scripts/tracking/hand_input.gd")
const IK=preload("res://scripts/avatar_ik.gd")
const POSITION=XRHandTracker.HAND_JOINT_FLAG_POSITION_VALID
const ORIENTATION=XRHandTracker.HAND_JOINT_FLAG_ORIENTATION_VALID
var ready:=false
var neutral_time:=0.0
var pinched:=false
var pinch_time:=0.0
var menu_time:=0.0
var menu_latched:=false
func reset()->void:
	ready=false;neutral_time=0;pinched=false;pinch_time=0;menu_time=0;menu_latched=false
static func valid_joint(hand:XRHandTracker,joint:int,orientation:=false)->bool:
	var flags:=hand.get_hand_joint_flags(joint)
	var pose:=hand.get_hand_joint_transform(joint)
	return bool(flags&POSITION) and pose.is_finite() and (not orientation or bool(flags&ORIENTATION) and absf(pose.basis.determinant())>.01)
static func optical(hand:XRHandTracker,controller:XRPositionalTracker)->bool:
	if hand==null or not hand.has_tracking_data:return false
	if hand.hand_tracking_source==XRHandTracker.HAND_TRACKING_SOURCE_UNOBSTRUCTED:return true
	if hand.hand_tracking_source!=XRHandTracker.HAND_TRACKING_SOURCE_UNKNOWN:return false
	# Unknown sources can be controller-inferred (notably Index/SteamVR).
	if controller==null:return true
	if str(controller.profile).contains("hand_interaction"):return true
	return not controller.has_pose("grip") or not controller.get_pose("grip").has_tracking_data
func sample(hand:XRHandTracker,left_hand:bool,delta:float)->Dictionary:
	if hand==null or not hand.has_tracking_data or delta<=0 or delta>.1:
		reset();return {}
	for joint in [XRHandTracker.HAND_JOINT_WRIST,5,10,15]:
		if not valid_joint(hand,joint,joint==XRHandTracker.HAND_JOINT_WRIST):reset();return {}
	var wrist:=hand.get_hand_joint_transform(XRHandTracker.HAND_JOINT_WRIST)
	# Match the native avatar wrist-to-tool mapping, without controller offsets.
	var grip_basis:=wrist.basis.orthonormalized()*IK.controller_hand_basis(left_hand).inverse()
	var grip:=Transform3D(grip_basis,wrist.origin-grip_basis.y*.06)
	var aim:=Transform3D(Basis.looking_at(wrist.basis.y,-wrist.basis.z),wrist.origin)
	var thumb:=hand.get_hand_joint_transform(5).origin
	var distance:=thumb.distance_to(hand.get_hand_joint_transform(10).origin)
	var middle_distance:=thumb.distance_to(hand.get_hand_joint_transform(15).origin)
	var grasp:=0.0
	var curls:=Hands.sample(null,hand)
	var complete:=true
	for finger in [2,3,4]:
		for joint in Hands.FINGERS[finger]:complete=complete and valid_joint(hand,joint)
	if complete:grasp=(curls[2]+curls[3]+curls[4])/3.0
	var pinch:=distance<(.04 if pinched else .025)
	var menu_pinch:=middle_distance<.025 and distance>.04 and grasp<.6
	if not ready:
		neutral_time=neutral_time+delta if not pinch and not menu_pinch and grasp<.3 else 0.0
		ready=neutral_time>=.12
	var menu:=false
	if ready:
		menu_time=menu_time+delta if menu_pinch else 0.0
		if menu_time>=.65 and not menu_latched:menu=true;menu_latched=true
		if middle_distance>.045:menu_latched=false
		pinch_time=pinch_time+delta if pinch and not menu_pinch and not menu_latched else 0.0
		pinched=pinch_time>=.04
	else:pinched=false
	var tracked_flags:=XRHandTracker.HAND_JOINT_FLAG_POSITION_TRACKED|XRHandTracker.HAND_JOINT_FLAG_ORIENTATION_TRACKED
	var reliable:bool=(hand.get_hand_joint_flags(XRHandTracker.HAND_JOINT_WRIST)&tracked_flags)==tracked_flags
	return {"grip_pose":grip,"aim_pose":aim,"select":pinched,"grasp":grasp if ready and not menu_pinch and not menu_latched else 0.0,"menu":menu,"reliable":reliable}
