extends RefCounted
const VERSION:=2
static func migrate(cfg:ConfigFile)->bool:
	if int(cfg.get_value("golf","fit_version",0))>=VERSION:return false
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
	cfg.set_value("golf","fit_version",VERSION)
	return true
