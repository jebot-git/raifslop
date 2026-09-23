extends SceneTree
const Motor = preload("res://scripts/locomotion.gd")
const Mount = preload("res://scripts/tracking/hip_mount.gd")
var failures: Array = []
var motor
var tracker: XRControllerTracker
func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures.append(label)
func _initialize() -> void: run.call_deferred()
func obstacle(at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new(); root.add_child(body); body.position = at
	var shape := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size = size; shape.shape = box; body.add_child(shape)
	return body
func tick(count := 1) -> void:
	for i in count:
		await physics_frame
		motor._physics_process(1.0 / 60.0)
func reset_pose() -> void:
	motor.position = Vector3(0, .01, 0); motor.origin.transform = Transform3D.IDENTITY
	motor.head.position = Vector3(0, 1.65, 0); motor.previous_head = Vector3(INF, INF, INF)
	motor.tracked_hip = Transform3D(Basis.IDENTITY, Vector3(0, .95, 0)); motor.velocity = Vector3.ZERO
func run() -> void:
	var floor_ := obstacle(Vector3(0,-.1,0), Vector3(10,.2,10))
	var rail := obstacle(Vector3(0,.4,-.6), Vector3(3,.8,.2))
	motor = Motor.new(); root.add_child(motor); motor.set_physics_process(false)
	motor.origin = XROrigin3D.new(); motor.add_child(motor.origin)
	motor.head = Camera3D.new(); motor.origin.add_child(motor.head)
	motor.left = XRController3D.new(); motor.origin.add_child(motor.left)
	motor.right = XRController3D.new(); motor.origin.add_child(motor.right)
	tracker = XRControllerTracker.new(); tracker.name = "hip_collision_controller"; XRServer.add_tracker(tracker)
	motor.right.tracker = tracker.name; motor.right.pose = "grip"
	tracker.set_pose("grip", Transform3D.IDENTITY, Vector3.ZERO, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	tracker.set_input("primary", Vector2.ZERO); tracker.set_input("primary_click", false)
	motor.xr = true; reset_pose(); await tick(5)
	var before: Vector3 = motor.global_position
	motor.head.position = Vector3(0,1.15,-.8)
	await tick(10)
	check(absf(motor.global_position.z-before.z)<.01 and motor.head.global_position.z<-.79, "Tracked hips permit leaning over a low rail without pushing the player backward")
	check(motor.is_on_floor(), "Hip-anchored capsule retains floor support while leaning")
	motor.head.position = Vector3(0,1.65,0); await tick(3)
	motor.tracked_hip.origin.z = -.8
	await tick(5)
	check(motor.global_position.z>-.3 and motor.origin.to_global(motor.tracked_hip.origin).z>-.3, "Physical hip movement still collides with low rails")
	reset_pose(); rail.position.y = 1.4; rail.get_child(0).shape.size.y = 2.8; await tick(5)
	motor.head.position.z = -.8; await tick(5)
	check(motor.head.global_position.z>-.4, "Fast head lean cannot tunnel through a tall wall")
	reset_pose(); rail.position.x = 5; await tick(5)
	motor.tracked_hip.origin.x = .3; motor.head.position.x = .3; await tick(1)
	var after: Vector3 = motor.global_position
	await tick(10)
	check(absf(after.x-.3)<.01 and motor.global_position.distance_to(after)<.01, "Repeated physics ticks never apply a tracked hip step twice")
	motor.tracked_hip = null; motor.head.position.x += .2; await tick(3)
	check(absf(motor.head.global_position.x-motor.global_position.x)<.01 and motor.head_shape.disabled, "Hip tracking loss restores head-following collision")
	XRServer.remove_tracker(tracker); motor.queue_free(); floor_.queue_free(); rail.queue_free(); await process_frame
	var g = load("res://scenes/main.tscn").instantiate(); root.add_child(g); await create_timer(.4).timeout
	g.set_process(false); g.motor.set_physics_process(false)
	g.tracking_manager.body = {"hips":Transform3D(Basis(Vector3.UP,.6),Vector3(.1,.95,-.15))}
	g.rod_holster.update_holster(); g.fish_guide.update_device()
	var rod_pose: Transform3D = g.rod_holster.belt_pose
	var guide_pose: Transform3D = g.fish_guide.belt_transform
	g.head.rotation.y += 1.4; g.head.position.z -= .4
	g.rod_holster.update_holster(); g.fish_guide.update_device()
	check(g.rod_holster.belt_pose.is_equal_approx(rod_pose) and g.fish_guide.belt_transform.is_equal_approx(guide_pose), "Fishing rod and guide stay with hips when the head turns or leans")
	g.tracking_manager.body.hips.basis = Basis(Vector3.UP,1.2)
	g.rod_holster.update_holster(); g.fish_guide.update_device()
	check(not g.rod_holster.belt_pose.is_equal_approx(rod_pose) and not g.fish_guide.belt_transform.is_equal_approx(guide_pose), "Hip rotation moves both fishing holsters")
	g.queue_free(); await process_frame; await create_timer(.3).timeout
	print("HIP_TRACKING_RESULT ", failures); quit(0 if failures.is_empty() else 1)
