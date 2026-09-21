extends "res://scripts/bbq/food.gd"
## The trigger closes the jaws; the held pose, never a button, turns the food.
const TIP := Vector3(0,0,-.25)
const JAW_REACH := .321
const OPEN_ANGLE := .34
const EMPTY_CLOSED_ANGLE := .025
const REST_ANGLE := .065
const JAW_CENTER := Vector3(0,0,-JAW_REACH)
var food: Node3D
var squeezed := false
var jaw_angle := REST_ANGLE
var clamped_angle := EMPTY_CLOSED_ANGLE
var jaws: Array[Node3D] = []

func _init() -> void:
	kind = "tongs"
	display_name = "Grill tongs"

func _ready() -> void:
	var handle: Node3D = load("res://assets/models/bbq/tongs_handle.glb").instantiate()
	handle.rotation.z = PI/2; add_child(handle)
	for side in [-1,1]:
		var pivot := Node3D.new(); add_child(pivot)
		pivot.position.z = .075; pivot.rotation.x = side*jaw_angle
		var jaw: Node3D = load("res://assets/models/bbq/tongs_jaw.glb").instantiate()
		# Lower contact face points up; upper face points down into the gap.
		if side > 0: jaw.rotation.z = PI
		pivot.add_child(jaw)
		jaws.append(pivot)

func pickup(hand: int, pose: Transform3D) -> bool:
	if held_hand >= 0: return false
	held_hand = hand; grip_offset = Transform3D.IDENTITY
	global_transform = pose
	return true

func follow_hand(pose: Transform3D) -> void:
	global_transform = pose * grip_offset
	if is_instance_valid(food): food.follow_hand(global_transform)

func clamp_item(item: Node3D) -> bool:
	if is_instance_valid(food) or item.kind not in ["fish","burger"]: return false
	if not item.pickup(held_hand,global_transform): return false
	food = item
	var bounds := preload("res://scripts/fish_size.gd").bounds(item,global_transform.affine_inverse()*item.get_parent().global_transform)
	clamped_angle = atan(clampf(bounds.size.y*.5+.009,.009,.100)/JAW_REACH)
	return true

func animate_jaws(delta: float) -> void:
	var target := (clamped_angle if is_instance_valid(food) else EMPTY_CLOSED_ANGLE) if squeezed else OPEN_ANGLE
	if held_hand < 0: target = REST_ANGLE
	jaw_angle = move_toward(jaw_angle,target,delta*2.0)
	for i in jaws.size(): jaws[i].rotation.x = (-1 if i == 0 else 1)*jaw_angle
