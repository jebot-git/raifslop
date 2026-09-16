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
	if value:
		# Stowing cancels the current line and rearms the selected bait.
		g.game.reset();g.fish_display.hide();g.catch_in_hand=false
		g.motor.catch_controls=false;g.escape_offset=Vector3.ZERO
	stowed=value
	if stowed:
		desktop_pose=g.rod.transform
		g.rod.reparent(g)
		g.rod.global_transform=belt_pose
	else:
		g.rod.reparent(g.right if g.xr else g.origin)
		g.rod.top_level=g.xr
		if g.xr:
			var grip: Variant=g.avatar.hand_grip_pose() if is_instance_valid(g.avatar) else null
			g.rod.global_transform=(grip if grip is Transform3D else g.right.global_transform)*HELD_POSE
		else: g.rod.transform=desktop_pose
	g.rod_visual.set_folded(stowed)
	g.rod.show()
	g.casting=false;g.peak_speed=0;g.velocity=Vector3.ZERO;g.tracking_was_valid=false
	g.reel_tracker.engaged=false;g.reel_tracker.angular_delta=0;g.fight_input.reset()
	g.fishing_feedback.reel_rate=0
	g.last_tip=g.origin.to_local(g.tip.global_position) if g.xr else g.tip.global_position
	g.game.message="Rod stashed · right hip + grip to pick up." if stowed else "Rod ready · hold trigger, sweep back then forward, release."
	g._update_line()
	g.hud.queue_redraw()
	if g.xr and g.right.get_has_tracking_data(): g.right.trigger_haptic_pulse("haptic",0,.3,.08,0)
	return true

static func remote_stowed(data: Dictionary) -> bool:
	# A solved hand can stop short of its controller. Only the belt's exact
	# downward orientation and hip region identify a folded rod in protocol 2.
	if not data.xr or not data.state in [S.State.READY,S.State.LOST]: return false
	var from_head: Vector3=data.rod.origin-data.head.origin
	return data.rod.basis.z.distance_to(Vector3.UP)<.001 and Vector2(from_head.x,from_head.z).length()<.65 and from_head.y<-.30 and data.rod.origin.y>=data.feet.y+.50
