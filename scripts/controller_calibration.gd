extends RefCounted
## Local grip corrections, independent for each controller. Stored in metres/degrees.
var offsets := [Vector3.ZERO, Vector3.ZERO]
var angles := [Vector3.ZERO, Vector3.ZERO]
var optical_hands := [false, false] # Runtime source; never persisted as calibration.
func pose(hand: int) -> Transform3D:
	if optical_hands[hand]: return Transform3D.IDENTITY
	return Transform3D(Basis.from_euler(angles[hand] * PI / 180.0), offsets[hand])
func load_config(cfg: ConfigFile) -> void:
	for hand in 2:
		for field in ["offset", "rotation"]:
			var value = cfg.get_value("controls", ("left_" if hand == 0 else "right_") + field, Vector3.ZERO)
			var limit := .20 if field == "offset" else 60.0
			var safe: Vector3 = value.clamp(Vector3.ONE * -limit, Vector3.ONE * limit) if value is Vector3 and value.is_finite() else Vector3.ZERO
			if field == "offset": offsets[hand] = safe
			else: angles[hand] = safe
func save_config(cfg: ConfigFile) -> void:
	for hand in 2:
		var prefix := "left_" if hand == 0 else "right_"
		cfg.set_value("controls", prefix + "offset", offsets[hand])
		cfg.set_value("controls", prefix + "rotation", angles[hand])
