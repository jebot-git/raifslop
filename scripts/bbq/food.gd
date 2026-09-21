extends Node3D
## Physical orientation determines the side touching the grate. No timed consumption.
var kind := "fish"
var display_name := "Fish"
var held_hand := -1
var on_grill := false
var in_cooler := false
var opened := false
var consumed := false
var cook := [0.0, 0.0]
var side := 0
var held_age := 0.0
var face_time := 0.0
var opening_age := 0.0
var grip_offset := Transform3D.IDENTITY
var home := Transform3D.IDENTITY
var thickness := .04
var cook_materials: Array[ShaderMaterial] = []

func pickup(hand: int, pose: Transform3D) -> bool:
	if consumed or held_hand >= 0: return false
	held_hand = hand
	grip_offset = pose.affine_inverse() * global_transform
	on_grill = false
	in_cooler = false
	held_age = 0.0
	face_time = 0.0
	return true

func follow_hand(pose: Transform3D) -> void:
	global_transform = pose * grip_offset

func place_on_grill(height: float) -> void:
	# A half-turn of the actual held pose changes the contact side.
	side = 0 if global_basis.y.dot(Vector3.UP) >= 0.0 else 1
	var forward := Vector3(global_basis.x.x, 0, global_basis.x.z).normalized()
	if forward.length_squared() < .1: forward = Vector3.RIGHT
	var up := Vector3.UP if side == 0 else Vector3.DOWN
	global_basis = Basis(forward, up, forward.cross(up)).orthonormalized()
	global_position.y = height + thickness
	held_hand = -1
	on_grill = true
	face_time = 0.0

func advance(delta: float, face: Vector3, can_consume: bool) -> bool:
	if consumed: return false
	for material in cook_materials:
		material.set_shader_parameter("world_to_food",global_transform.affine_inverse())
	if opened: opening_age += delta
	if on_grill and held_hand < 0 and kind != "beer":
		cook[side] = minf(cook[side] + delta / 18.0, 1.8)
		for m in cook_materials:
			m.set_shader_parameter("cook_bottom", cook[0])
			m.set_shader_parameter("cook_top", cook[1])
	if held_hand < 0: return false
	held_age += delta
	var near_face := global_position.distance_to(face) < .16
	var ready := kind != "beer" or (opened and opening_age >= .30)
	if can_consume and held_age > .35 and ready and near_face:
		face_time += delta
	else: face_time = 0.0
	return face_time >= .18

func status() -> String:
	if kind == "beer": return "Open · drink" if opened else "Sealed · trigger to open"
	if maxf(cook[0], cook[1]) > 1.3: return "Charred"
	if minf(cook[0], cook[1]) >= .85: return "Ready"
	if maxf(cook[0], cook[1]) >= .85: return "Turn over"
	return "Cooking" if on_grill else "Fresh"
