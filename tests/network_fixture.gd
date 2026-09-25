extends RefCounted
const State = preload("res://scripts/network/state.gd")
static func player(body_count: int = 0, face: bool = false) -> Dictionary:
	var data := {"user_height":1.78,"serial":124,"location":"lakeside","body":{},"face":{},
		"visemes":PackedFloat32Array([.15,.28,.32,.01,.03]),"state":0,"bait":0,"species":0,
		"rod_tier":0,"rig":0,"length":10.0,"curl":.3,"reel_angle":.712,"golf_club":-1,"golf_stowed":false}
	var i := 0
	for key in State.TRANSFORMS:
		i += 1; data[key] = Transform3D(Basis.from_euler(Vector3(.12*i,.24*i,.07*i)), Vector3(10.125+i*.1,1.75,-25.873+i*.3))
	for key in State.VECTORS:
		i += 1; data[key] = Vector3(10.87+i*.02,.123*i,-25.89-i*.03)
	for key in ["caught","in_hand","xr","bobber_visible","bait_visible"]: data[key] = false
	data.left_valid = true; data.right_valid = true
	var body_keys := ["hips","chest","left_foot","right_foot","left_knee","right_knee","left_elbow","right_elbow","left_hand","right_hand"]
	for index in body_count:
		data.body[body_keys[index]] = Transform3D(Basis.from_euler(Vector3(.014*index,.26,.16)),Vector3(.12,.15+.1*index,-.2))
	if body_count > 0:
		data.body.left_curls = PackedFloat32Array([.15,.25,.36,.48,.59]); data.body.right_curls = PackedFloat32Array([.61,.72,.83,.92,1])
	if face:
		data.face = {"look":Vector2(.1,.07),"blink":Vector2(.4,.2),"gaze":true,"lids":true,
			"mouth":PackedFloat32Array([.1,.2,.3,.4,.5]),"expressions":PackedFloat32Array([.5,.4,.3,.2,.1])}
	assert(State.valid(data))
	return data
