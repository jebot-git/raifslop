extends SceneTree
var failures: Array=[]
var last_wrist := Transform3D.IDENTITY
var last_left_wrist := Transform3D.IDENTITY
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures.append(label)
func record_wrist(_grip: Transform3D, rig: Node3D) -> void:
	last_wrist=rig.skeleton.global_transform*rig.skeleton.get_bone_global_pose(rig.right_hand_bone)
	last_left_wrist=rig.skeleton.global_transform*rig.skeleton.get_bone_global_pose(rig.left_hand_bone)
func run() -> void:
	var g=load("res://scenes/main.tscn").instantiate();root.add_child(g)
	await create_timer(.4).timeout
	g.set_process(false);g.motor.set_physics_process(false)
	var desktop_pose: Transform3D=g.rod.global_transform
	await process_frame;await process_frame
	check(g.rod.global_transform.is_equal_approx(desktop_pose),"Desktop rod remains the IK input without attachment feedback")
	g.xr=true;g.rod.reparent(g.right);g.rod.top_level=true
	g.motor.position=Vector3(2,.2,-3);g.head.rotation.y=.65
	g.left.position=Vector3(-.3,1.2,-.3)
	for path in g.avatars.DEFAULTS:
		await g._select_avatar(path)
		var rig=g.avatar
		rig.right_grip_updated.connect(record_wrist.bind(rig))
		for offset in [Vector3(.3,1.2,.3),Vector3(3,1.2,.3),Vector3(.3,3,.3),Vector3(.3,1.2,3)]:
			g.right.transform=Transform3D(Basis.from_euler(Vector3(.2,.4,-.3)),offset)
			g._update_avatar(.016)
			await process_frame;await process_frame
			var grip: Transform3D=rig.hand_grip_pose()
			var label: String=path.get_file()+" "+str(offset)
			var left_grip: Transform3D=rig.hand_grip_pose(true)
			var left_wrist: Transform3D=last_left_wrist
			check(absf(left_grip.origin.distance_to(left_wrist.origin)-.06)<.001,"Offhand line attachment stays at solved palm: "+label)
			check(left_grip.basis.is_equal_approx(g.left.global_basis.orthonormalized()),"Offhand grip undoes VRM wrist correction: "+label)
			check((g.rod.global_transform*g.rod_holster.HELD_POSE.affine_inverse()).is_equal_approx(grip),"Rod follows rendered hand: "+label)
			check(grip.origin.distance_to(last_wrist.origin)<.061 and grip.origin.distance_to(last_wrist.origin)>.059,"Handle stays at palm: "+label)
			check(grip.basis.is_equal_approx(g.right.global_basis.orthonormalized()) and is_equal_approx(g.tip.global_position.distance_to(grip.origin),1.68),"Wrist rotation and physical rod length preserved: "+label)
			if offset.length()>2:
				check(grip.origin.distance_to(g.right.global_position)>.5,"Unreachable controller cannot pull rod out of hand: "+label)
			else:
				check(grip.origin.distance_to(g.right.global_position)<.05,"Reachable controller retains original mount: "+label)
			var held: Transform3D=g.rod.global_transform
			g.right.position+=Vector3(.5,0,0)
			check(g.rod.global_transform.is_equal_approx(held),"Controller hierarchy cannot move rod between solves: "+label)
			check(g.bobber.global_position.distance_to(g.tip.global_position+Vector3.DOWN*.30)<.001,"Hanging tackle updates with solved tip: "+label)
			var state=preload("res://scripts/network/state.gd").capture(g,1)
			check(preload("res://scripts/network/state.gd").valid(state) and not g.rod_holster.remote_stowed(state),"Unreachable hand remains unfolded in network pose: "+label)
		# Missing optional index bones must not disable the mandatory hand mount.
		rig.index_tip_bone=-1;g.right.position+=Vector3(0,.1,0);g._update_avatar(.016)
		await process_frame;await process_frame
		check(rig.right_grip_frame>=Engine.get_process_frames()-1,"Hand mount does not require index finger bones")
		g.rod_holster.update_holster();g.rod_holster.set_stowed(true)
		var belt: Transform3D=g.rod.global_transform
		g.right.position+=Vector3(0,.5,0);g._update_avatar(.016)
		await process_frame;await process_frame
		check(g.rod.global_transform.is_equal_approx(belt),"Solved hand cannot pull folded rod out of holster")
		g.rod_holster.set_stowed(false)
		check(g.rod.global_transform.is_equal_approx(rig.hand_grip_pose()*g.rod_holster.HELD_POSE),"Retrieval immediately uses solved grip")
	var remote=preload("res://scripts/network/remote_angler.gd").new()
	remote.session=g.network;g.add_child(remote)
	remote.set_avatar(g.avatars.load_model(g.avatars.DEFAULTS[2]),"test")
	remote.receive_state(preload("res://scripts/network/state.gd").capture(g,2))
	remote.avatar.right_grip_updated.connect(record_wrist.bind(remote.avatar))
	await process_frame;await process_frame
	var remote_grip: Transform3D=remote.avatar.hand_grip_pose()
	check(remote.rod.global_transform.is_equal_approx(remote_grip*g.rod_holster.HELD_POSE),"Remote rod follows remote avatar's solved hand")
	check(remote.rendered.tip.distance_to(remote.rod.to_global(Vector3(0,0,-1.68)))<.001,"Remote line begins at attached rod tip")
	g.xr=false;g.queue_free();await process_frame;await create_timer(.3).timeout
	print("ROD_ATTACHMENT_RESULT ",failures);quit(0 if failures.is_empty() else 1)
