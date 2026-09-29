extends Node3D
## Visual grip only. Swing/contact measurements always use the real striking hand.
var activity:Node3D
var engaged:=false
var automatic:=false
var idle_seconds:=0.0
var idle_pose:=Transform3D.IDENTITY
var sampled:=false
var hand:=-1
func reset()->void:
	engaged=false;automatic=false;idle_seconds=0;sampled=false
func update(dt:float)->bool:
	var game:Node3D=activity.host
	var striking:XRController3D=activity.pointer_controller()
	var offhand:int=1 if striking==game.left else 0
	if hand!=offhand:reset();hand=offhand
	if not game.xr or not game.tracking_manager.focused or not game.motor.tracking_focused:
		reset();return false
	var other:XRController3D=game.right if offhand==1 else game.left
	if not striking.get_has_tracking_data():reset();return false
	var index:int=1-offhand
	var grip:Transform3D=activity.fitting.grip_pose(game.controller_pose(index),index)
	var shaft:Transform3D=activity.fitting.transforms(grip,index).shaft
	global_transform=Transform3D(grip.basis.orthonormalized(),shaft.origin-shaft.basis.y.normalized()*.105)
	var tracked:=other.get_has_tracking_data()
	var pose:Transform3D=game.controller_pose(offhand)
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
	if game.menu_open or activity.fitting.active or not activity.active or activity.guide.held or activity.finished or game.bbq.visiting:
		engaged=false;return false
	if game.shoulder_radio.held or game.bbq.holds(offhand):
		automatic=false;engaged=false;return false
	var distance:float=pose.origin.distance_to(global_position)
	engaged=automatic or (pressed and distance<(.35 if engaged else .18))
	return engaged
