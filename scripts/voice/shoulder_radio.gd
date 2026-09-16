extends Node3D
## FPSloppa shoulder_radio (b0fc725), adapted to fishing's left support hand.
var game_root: Node3D
var held:=false
var active:=false
var grip_was_down:=false
var model:=Node3D.new()
var label:=Label3D.new()
func setup(value: Node3D) -> void:
	game_root=value;add_child(model)
	var shell=game_root.material(Color("303a30"),.65)
	var dark=game_root.material(Color("101810"),.8)
	game_root.box(model,Vector3.ZERO,Vector3(.065,.10,.03),shell)
	game_root.box(model,Vector3(-.02,.08,0),Vector3(.006,.09,.006),dark)
	for y in 4:game_root.box(model,Vector3(0,.022-y*.012,-.017),Vector3(.045,.004,.003),dark)
	label.font_size=24;label.pixel_size=.0012;label.position.y=.15
	label.layers=preload("res://scripts/guide_camera.gd").UI_LAYER
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;model.add_child(label);model.hide()
func shoulder() -> Transform3D:
	var head: Transform3D=game_root.head.global_transform
	var yaw:=Basis(Vector3.UP,atan2(head.basis.z.x,head.basis.z.z))
	return Transform3D(yaw,head.origin+yaw*Vector3(-.23,-.25,.04))
func reset() -> void:
	held=false;active=false;grip_was_down=true;model.hide()
	game_root.network.voice.set_radio(false)
func update() -> void:
	var g=game_root
	if not g.xr:
		if held:reset()
		model.hide();return
	var voice=g.network.voice
	var tracked: bool=g.left.get_has_tracking_data()
	var grip: bool=tracked and g.left.get_float("grip")>(.35 if grip_was_down else .55)
	var valid: bool=voice.can_transmit() and voice.mode>0 and tracked and not g.menu_open and not g.fish_guide.held and g.game.state!=g.Session.State.LANDED
	if not valid:reset();grip_was_down=grip;return
	var mount:=shoulder()
	var near: bool=g.controller_pose(0).origin.distance_to(mount.origin)<.22
	if not grip:held=false
	elif near and not grip_was_down:held=true
	grip_was_down=grip
	active=held and (g.left.is_button_pressed("trigger_click") or g.left.get_float("trigger")>.55)
	voice.set_radio(active)
	model.show();model.global_transform=g.controller_pose(0) if held else mount
	# FPSloppa: the grip forward axis points toward the fingertips.
	if held:model.rotate_object_local(Vector3.RIGHT,-PI/2)
	label.visible=held or near
	label.text="ALL WATERS · RADIO" if active else "HOLD TRIGGER · TALK" if held else "GRAB RADIO"
	label.modulate=Color("87e8ae") if active else Color("e5d5ad")
