extends RefCounted
const BAG := [
	{"name":"Driver","short":"DR","loft":11.0,"speed":46.0,"length":1.13},
	{"name":"3 Wood","short":"3W","loft":15.0,"speed":43.0,"length":1.06},
	{"name":"5 Iron","short":"5I","loft":27.0,"speed":38.0,"length":.97},
	{"name":"7 Iron","short":"7I","loft":34.0,"speed":35.0,"length":.93},
	{"name":"9 Iron","short":"9I","loft":42.0,"speed":32.0,"length":.89},
	{"name":"Pitching wedge","short":"PW","loft":47.0,"speed":29.0,"length":.87},
	{"name":"Sand wedge","short":"SW","loft":56.0,"speed":25.0,"length":.86},
	{"name":"Putter","short":"PT","loft":2.0,"speed":3.5,"length":.86}]
static func impact(index: int,club_velocity: Vector3,face: Vector3,lie: String,contact:Dictionary={}) -> Dictionary:
	if index<0 or index>=BAG.size() or not club_velocity.is_finite() or not face.is_finite():return {}
	var shape=preload("res://addons/golfminus/scripts/golf/club_head.gd").for_club(index)
	var hit:=contact.duplicate()
	if not hit.has("normal"):
		# Desktop input is a synthetic centre-face strike through the same solver.
		if face.length()<.5:return {}
		var forward:=face.normalized()
		var right:=forward.cross(Vector3.UP).normalized()
		if right.length()<.5:return {}
		var basis:=Basis(right,right.cross(forward),-forward)*Basis(Vector3.RIGHT,shape.loft)
		var normal:Vector3=basis*Vector3.FORWARD
		hit={"normal":normal,"contact":basis*shape.face_center,"head_center":Vector3.ZERO,"head_basis":basis}
	return preload("res://addons/golfminus/scripts/golf/impact_solver.gd").solve(shape,club_velocity,hit.get("angular_velocity",Vector3.ZERO),hit,lie)
