extends Node3D
const S = preload("res://scripts/fishing_session.gd")
const HELD_POSE = Transform3D(Basis(Vector3.RIGHT, .35), Vector3.ZERO)
var game_root: Node3D
var stowed := false
var grip_was_down := false
var belt_pose := Transform3D.IDENTITY
var desktop_pose := Transform3D.IDENTITY

func update_holster() -> void:
	var g = game_root
	var facing := Basis(Vector3.UP, atan2(g.head.global_basis.z.x,g.head.global_basis.z.z))
	var hip := Vector3(g.head.global_position.x,maxf(g.motor.global_position.y+.55,g.head.global_position.y-.70),g.head.global_position.z)
	if is_instance_valid(g.tracking_manager) and g.tracking_manager.body.has("hips"):
		var hips: Transform3D = g.motor.global_transform*g.tracking_manager.body.hips
		hip=hips.origin;facing=Basis(Vector3.UP,atan2(hips.basis.z.x,hips.basis.z.z))
	belt_pose=Transform3D(facing*Basis(Vector3.RIGHT,-PI/2),hip+facing*Vector3(.29,0,-.02))
	if stowed: g.rod.global_transform=belt_pose
	if not g.xr: return
	if not g.right.get_has_tracking_data():
		grip_was_down=true
		return
	var down: bool=g.right.get_float("grip")>(.35 if grip_was_down else .55)
	if down and not grip_was_down and not g.menu_open and g.tracking_manager.focused and g.right.global_position.distance_to(belt_pose.origin)<.23:
		set_stowed(not stowed)
	grip_was_down=down

func set_stowed(value: bool) -> bool:
	if stowed==value: return true
	var g=game_root
	if value and (g.casting or not g.game.state in [S.State.READY,S.State.LOST]):
		g.game.message="Finish this cast and release your catch before stashing the rod."
		g.hud.queue_redraw()
		return false
	stowed=value
	if stowed:
		desktop_pose=g.rod.transform
		g.rod.reparent(g)
		g.rod.global_transform=belt_pose
	else:
		g.rod.reparent(g.right if g.xr else g.origin)
		g.rod.transform=HELD_POSE if g.xr else desktop_pose
	g.rod_visual.set_folded(stowed)
	g.rod.show()
	g.casting=false;g.peak_speed=0;g.velocity=Vector3.ZERO;g.tracking_was_valid=false
	g.reel_tracker.engaged=false;g.reel_tracker.angular_delta=0;g.fight_input.reset()
	g.fishing_feedback.reel_rate=0
	g.last_tip=g.origin.to_local(g.tip.global_position) if g.xr else g.tip.global_position
	g.game.message="Rod stashed · right hip + grip to pick up." if stowed else "Rod ready · hold trigger, swing, release."
	g.hud.queue_redraw()
	if g.xr and g.right.get_has_tracking_data(): g.right.trigger_haptic_pulse("haptic",0,.3,.08,0)
	return true

static func remote_stowed(data: Dictionary) -> bool:
	# Protocol 2 already sends independent rod and grip poses. An idle XR rod
	# outside its fixed hand mount is holstered, so no packet schema change is needed.
	if not data.xr or not data.state in [S.State.READY,S.State.LOST]: return false
	var held: Transform3D=data.right*HELD_POSE
	return data.rod.origin.distance_to(held.origin)>.015 or data.rod.basis.get_rotation_quaternion().angle_to(held.basis.get_rotation_quaternion())>.02
