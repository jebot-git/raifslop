extends RefCounted
const VERSION:=3
const LEAN_DEGREES:=[32.0,31.0,29.0,27.0,26.0,26.0,26.0,20.0]
static func grip_basis(hand:int)->Basis:
	# OpenXR grip +Z runs from thumb to little finger, down a held handle.
	# The authored club extends along -Y. The trail-hand palm faces the shot:
	# -X in the right grip, +X in the left grip. Both mappings are rotations.
	return Basis(Vector3.UP if hand==0 else Vector3.DOWN,Vector3.FORWARD,Vector3.LEFT if hand==0 else Vector3.RIGHT)
static func default_shaft_rotation(hand:int)->Vector3:
	return grip_basis(hand).get_euler()*180/PI
static func head_rotation_for_lean(hand:int,lean:float)->Vector3:
	return (grip_basis(hand)*Basis(Vector3.BACK,deg_to_rad(lean if hand==0 else -lean))).get_euler()*180/PI
static func default_head_rotation(hand:int,index:int)->Vector3:
	return head_rotation_for_lean(hand,LEAN_DEGREES[index])
static func migrate(cfg:ConfigFile)->bool:
	if int(cfg.get_value("golf","fit_version",0))>=VERSION:return false
	if int(cfg.get_value("golf","fit_version",0))<2:_migrate_legacy(cfg)
	for hand in 2:
		var rotation=cfg.get_value("golf","club_rotation_%d"%hand,Vector3.ZERO)
		var head=cfg.get_value("golf","club_head_rotation_%d"%hand,Vector3.ZERO)
		if not rotation is Vector3 or not head is Vector3 or not rotation.is_finite() or not head.is_finite():continue
		var fitted:=bool(cfg.get_value("golf","club_fitted_%d"%hand,rotation.length_squared()>.001 or head.length_squared()>.001))
		var source:=str(cfg.get_value("golf","club_head_source_%d"%hand,"default"))
		cfg.set_value("golf","club_fitted_%d"%hand,fitted)
		# Keep manual and unclassified older calibrations intact. Only replace
		# the known broken defaults, including defaults saved by a v2 auto-fit.
		if source not in ["default","fit"]:continue
		if not fitted and rotation.is_zero_approx():
			cfg.set_value("grip_axis_v2","rotation_%d"%hand,rotation)
			cfg.set_value("golf","club_rotation_%d"%hand,default_shaft_rotation(hand))
		if fitted:
			for lean in LEAN_DEGREES:
				if head.is_equal_approx(Vector3(0,0,lean if hand==0 else -lean)):
					cfg.set_value("grip_axis_v2","head_rotation_%d"%hand,head)
					cfg.set_value("golf","club_head_rotation_%d"%hand,head_rotation_for_lean(hand,lean))
					break
	cfg.set_value("golf","fit_version",VERSION)
	return true
static func _migrate_legacy(cfg:ConfigFile)->void:
	for hand in 2:
		var rotation=cfg.get_value("golf","club_rotation_%d"%hand,Vector3.ZERO)
		var head=cfg.get_value("golf","club_head_rotation_%d"%hand,Vector3.ZERO)
		if not rotation is Vector3 or not head is Vector3 or not rotation.is_finite() or not head.is_finite():continue
		if not bool(cfg.get_value("golf","club_fitted_%d"%hand,rotation.length_squared()>.001 or head.length_squared()>.001)):continue
		# Old profiles cannot distinguish manual face corrections from auto-fit.
		# Archive both and preserve their current pose until an explicit new fit.
		cfg.set_value("legacy_fit","reach",cfg.get_value("golf","reach",1.0))
		cfg.set_value("legacy_fit","rotation_%d"%hand,rotation)
		cfg.set_value("legacy_fit","head_rotation_%d"%hand,head)
		cfg.set_value("golf","club_head_rotation_%d"%hand,(Basis.from_euler(rotation*PI/180)*Basis.from_euler(head*PI/180)).get_euler()*180/PI)
		cfg.set_value("golf","club_head_source_%d"%hand,"legacy")
