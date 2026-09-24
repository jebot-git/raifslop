extends Node3D
## Fishing-style hip equipment. Host tracking is optional; head/feet are fallback.
var game: Node3D
var stowed:=false
var grip_was_down:Array[bool]=[true,true]
var belt_pose:=Transform3D.IDENTITY

func hip_pose(side: float) -> Transform3D:
	var facing:=Basis(Vector3.UP,atan2(game.head.global_basis.z.x,game.head.global_basis.z.z))
	var hip:=Vector3(game.head.global_position.x,maxf(game.body.global_position.y+.55,game.head.global_position.y-.70),game.head.global_position.z)
	if is_instance_valid(game.host_game):
		var mount := preload("res://scripts/tracking/hip_mount.gd").pose(game.head, game.body, game.host_game.tracking_manager)
		hip = mount.origin; facing = mount.basis
	return Transform3D(facing,hip+facing*Vector3(side*.29,0,-.02))

func update() -> void:
	belt_pose=hip_pose(-1.0 if game.left_handed else 1.0)
	if stowed and is_instance_valid(game.club):game.club.global_transform=Transform3D(belt_pose.basis.scaled(Vector3.ONE*.65),belt_pose.origin)
	if is_instance_valid(game.host_activity) and game.host_activity.clubhouse_round!=null:
		if not stowed:set_stowed(true)
		return
	if not game.xr:return
	if not game.focused or game.menu_open or game.fitting_club or game.club_radial.opened or game.godview.active:
		grip_was_down.assign([true,true]);return
	var previous:=grip_was_down.duplicate()
	for hand in 2:
		var controller:XRController3D=game.left if hand==0 else game.right
		grip_was_down[hand]=not controller.get_has_tracking_data() or controller.get_float("grip")>(.35 if previous[hand] else .55) or controller.is_button_pressed("grip_click")
	var striking:int=0 if game.left_handed else 1
	for hand in [striking,1-striking]:
		# Either hand can retrieve a stowed club. Only its holding hand can
		# holster it, so the offhand cannot accidentally put it away mid-swing.
		if not stowed and hand!=striking:continue
		var controller:XRController3D=game.left if hand==0 else game.right
		if not controller.get_has_tracking_data() or not grip_was_down[hand] or previous[hand]:continue
		var pose:Transform3D=controller.global_transform*game.calibration.pose(hand)
		if stowed:
			if game.course_guide.held and game.course_guide.held_hand==hand:continue
			if game.course_guide.pickup_near(pose.origin):continue
			if is_instance_valid(game.host_game):
				if game.host_game.bbq.holds(hand):continue
				if hand==0 and (game.host_game.shoulder_radio.held or pose.origin.distance_to(game.host_game.shoulder_radio.shoulder().origin)<.22):continue
		var remote_pickup:bool=stowed and game.one_hand_controller()==controller
		if not remote_pickup and pose.origin.distance_to(belt_pose.origin)>=.23:continue
		if stowed and hand!=striking:game.set_hand(hand==0)
		set_stowed(not stowed)
		return

func set_stowed(value: bool) -> void:
	if game.fitting_club:game.cancel_club_fit()
	if not value and is_instance_valid(game.course_guide):game.course_guide.dock()
	stowed=value
	game.reset_swing()
	if not is_instance_valid(game.club):return
	game.club.reparent(game if stowed else (game.left if game.left_handed else game.right))
	if stowed:game.club.global_transform=Transform3D(belt_pose.basis.scaled(Vector3.ONE*.65),belt_pose.origin)
	else:game._update_club_pose()
	game.club.visible=not game.menu_open
	game.status_text="Club stashed · grip at the hip, or grip with your empty hand in one-hand mode." if stowed else "Club ready."
	game.telemetry.record("club_stowed",{"stowed":stowed})
