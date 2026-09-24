extends Node3D
## Visual grip only. Swing/contact measurements always use the real striking hand.
var game:Node3D
var engaged:=false
var automatic:=false
var idle_seconds:=0.0
var idle_pose:=Transform3D.IDENTITY
var sampled:=false
var hand:=-1
func reset()->void:
	engaged=false;automatic=false;idle_seconds=0;sampled=false
func update(dt:float)->bool:
	var offhand:int=1 if game.left_handed else 0
	if hand!=offhand:reset();hand=offhand
	if not game.xr or not game.focused:
		reset();return false
	var striking:XRController3D=game.left if game.left_handed else game.right
	var other:XRController3D=game.right if game.left_handed else game.left
	if not striking.get_has_tracking_data():reset();return false
	var index:int=0 if game.left_handed else 1
	var grip:Transform3D=striking.global_transform*game.club_grip_pose(index)
	var shaft:Transform3D=grip*Transform3D(Basis.from_euler(game.club_rotations[index]*PI/180.0),Vector3.ZERO)
	global_transform=Transform3D(grip.basis.orthonormalized(),shaft.origin-shaft.basis.y.normalized()*.105)
	var tracked:=other.get_has_tracking_data()
	var pose:Transform3D=other.transform*game.calibration.pose(offhand)
	var pressed:=maxf(other.get_float("grip"),other.get_float("trigger"))>(.35 if engaged else .55) or other.is_button_pressed("trigger_click") or other.is_button_pressed("grip_click")
	var using_controls:=pressed or other.get_vector2("primary").length()>.2 or other.is_button_pressed("ax_button") or other.is_button_pressed("by_button") or other.is_button_pressed("primary_click")
	using_controls=using_controls or maxf(other.get_float("grip"),other.get_float("trigger"))>.1
	for touch in ["trigger_touch","grip_touch","primary_touch","thumbrest_touch","ax_touch","by_touch"]:
		using_controls=using_controls or other.is_button_pressed(touch)
	if tracked:
		if not sampled or using_controls or pose.origin.distance_to(idle_pose.origin)>.02 or pose.basis.get_rotation_quaternion().angle_to(idle_pose.basis.get_rotation_quaternion())>deg_to_rad(7):
			idle_seconds=0;idle_pose=pose;sampled=true
		else:idle_seconds+=clampf(dt,0,.1)
	else:idle_seconds=1.0;sampled=false
	# A controller laid down remains tracked. A quiet hand away from the grip
	# becomes the support hand; picking it up or touching a control releases it.
	automatic=not tracked or idle_seconds>=.8
	# Keep detecting a controller set down even while the club is stowed or a
	# menu is open, so one-hand locomotion does not depend on holding the club.
	if game.menu_open or game.fitting_club or game.equipment.stowed or game.course_guide.held or game.godview.active or game.club_radial.opened:
		engaged=false;return false
	if is_instance_valid(game.host_game) and (game.host_game.shoulder_radio.held or game.host_game.bbq.holds(offhand)):
		automatic=false;engaged=false;return false
	var distance:float=(game.origin.global_transform*pose).origin.distance_to(global_position)
	engaged=automatic or (pressed and distance<(.35 if engaged else .18))
	return engaged
