extends SceneTree
var failures := 0
var checks := 0
var g
var trackers: Array[XRControllerTracker] = []
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run")
func pose(hand: int, world: Transform3D) -> void:
	var local: Transform3D = g.origin.global_transform.affine_inverse()*world*g.controller_calibration.pose(hand).affine_inverse()
	trackers[hand].set_pose("grip",local,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
func step() -> void:
	await process_frame
	g.bbq.tick(.02)
func grip(hand: int, value: float) -> void:
	trackers[hand].set_input("grip",value)
	await step()
func trigger(hand: int) -> void:
	trackers[hand].set_input("trigger_click",true)
	await step()
	trackers[hand].set_input("trigger_click",false)
	await step()
func run() -> void:
	g = load("res://scenes/main.tscn").instantiate(); root.add_child(g)
	await create_timer(.4).timeout
	g.set_process(false); g.motor.set_physics_process(false)
	g.xr = true; g.tracking_manager.focused = true
	g.menu_open = false; g.game.reset()
	for hand in range(2):
		var tracker := XRControllerTracker.new(); tracker.name = "bbq_test_"+str(hand)
		tracker.hand = XRPositionalTracker.TRACKER_HAND_LEFT if hand == 0 else XRPositionalTracker.TRACKER_HAND_RIGHT
		XRServer.add_tracker(tracker); trackers.append(tracker)
		var controller := XRController3D.new()
		controller.tracker = tracker.name; controller.pose = "grip"; g.origin.add_child(controller)
		if hand == 0:
			g.left = controller; controller.button_pressed.connect(g._left_button)
		else:
			g.right = controller; controller.button_pressed.connect(g._right_pressed); controller.button_released.connect(g._right_released)
		tracker.set_input("grip",0.0); tracker.set_input("trigger_click",false)
		pose(hand,g.head.global_transform)
	check(g.bbq.start() and g.rod_holster.stowed,"BBQ start stows rod through game integration")
	await step()
	var item = g.bbq.items[0]
	pose(0,item.global_transform); await step(); await grip(0,1)
	check(g.bbq.held[0] == item,"Tracked left squeeze picks up food")
	check(not g.motor.catch_controls,"VR locomotion stays available around station")
	var lifted: Transform3D = g.bbq.global_transform*Transform3D(Basis.IDENTITY,Vector3(0,1.14,0))
	pose(0,lifted); await step()
	check(item.global_position.distance_to(lifted.origin)<.01,"Held food follows real calibrated controller pose")
	await trigger(1)
	check(not item.consumed and not g.casting,"Other trigger neither eats nor casts")
	for i in range(8):
		lifted.basis = g.bbq.global_basis*Basis(Vector3.RIGHT,PI*(i+1)/8.0)
		pose(0,lifted); await step()
	await grip(0,0)
	check(item.on_grill and item.side==1,"Gradual wrist rotation and grip release flip food")
	pose(1,item.global_transform); await step(); await grip(1,1)
	check(g.bbq.held[1]==item,"Right hand can pick up flipped food")
	await trigger(1)
	check(g.bbq.held[1]==null,"Right controller trigger consumes right-held food")
	await grip(1,0)
	pose(1,Transform3D(Basis.IDENTITY,g.bbq.to_global(g.bbq.COOLER_POSITION+Vector3(0,.37,0))))
	await step(); await trigger(1)
	check(g.bbq.cooler_open,"Real trigger near lid opens fridge")
	var can = g.bbq.items.filter(func(i):return i.kind=="beer")[0]
	pose(1,can.global_transform); await step(); await grip(1,1)
	check(g.bbq.held[1]==can,"Tracked squeeze retrieves beer from fridge")
	await trigger(1)
	check(can.opened and not can.consumed,"Controller first trigger opens can only")
	await trigger(1)
	check(g.bbq.held[1]==null,"Controller second trigger consumes can")
	await grip(1,0)
	can = g.bbq.items.filter(func(i):return i.kind=="beer")[0]
	pose(0,can.global_transform); await step(); await grip(0,1); await trigger(0)
	pose(0,Transform3D(Basis.IDENTITY,g.head.global_transform*Vector3(0,-.075,-.08)))
	for i in range(30): await step()
	check(g.bbq.held[0]==null,"Tracked face gesture consumes opened beer")
	await grip(0,0)
	g.bbq.selected=0; g.bbq.add_food(); item=g.bbq.items.back()
	pose(0,item.global_transform); await step(); await grip(0,1)
	g.tracking_manager.focused=false; await step()
	check(g.bbq.held[0]==null and not item.consumed,"Focus loss returns held food without eating it")
	g.tracking_manager.focused=true; await step()
	check(g.bbq.held[0]==null,"Restored tracking requires fresh squeeze")
	# Either hand can hold the tool; its trigger is a clamp, never an eat action.
	await grip(0,0)
	var tool = g.bbq.tongs
	for hand in range(2):
		pose(hand,g.bbq.global_transform*g.bbq.TONGS_REST)
		await step(); await grip(hand,1)
		check(g.bbq.held[hand]==tool,"Tracked grip picks up tongs with hand "+str(hand))
		for settle in range(9): await step()
		var bottom: Vector3 = tool.to_local(tool.jaws[0].to_global(tool.JAW_CENTER))
		var top: Vector3 = tool.to_local(tool.jaws[1].to_global(tool.JAW_CENTER))
		check(top.y-bottom.y > .20 and absf(top.x-bottom.x)<.001,"Open prongs separate vertically, not sideways")
		check(tool.jaws[0].get_child(0).global_basis.y.dot(tool.global_basis.y)>.9 and tool.jaws[1].get_child(0).global_basis.y.dot(tool.global_basis.y)<-.9,"Prong gripping faces oppose each other")
		item=g.bbq.items.filter(func(i):return i.kind!="beer")[0]
		item.transform=Transform3D(Basis.IDENTITY,Vector3(0,1.1,0))
		var tip_target: Vector3 = item.global_position
		var tool_pose := Transform3D(g.bbq.global_basis,tip_target-g.bbq.global_basis*tool.TIP)
		pose(hand,tool_pose); await step()
		trackers[hand].set_input("trigger_click",true); await step()
		check(tool.food==item and item.held_hand==hand,"Trigger clamps food at tongs tips")
		for settle in range(9): await step()
		check(tool.jaw_angle < tool.OPEN_ANGLE-.10,"Trigger visibly closes jaws around food thickness")
		check(not item.consumed and g.bbq.held[hand]==tool,"Clamping never eats food or the tool")
		var cook_before: Array = item.cook.duplicate()
		await trigger(1-hand)
		check(tool.food==item and not item.consumed,"Opposite trigger cannot consume clamped food")
		for frame in range(8):
			tool_pose.basis=g.bbq.global_basis*Basis(Vector3.FORWARD,PI*(frame+1)/8.0)
			pose(hand,tool_pose); await step()
		check(item.global_basis.y.dot(Vector3.UP)<-.99,"Food rotates with gradual tong wrist roll")
		check(item.cook==cook_before,"Food held in tongs stops cooking")
		trackers[hand].set_input("trigger_click",false); await step()
		check(item.on_grill and item.side==1,"Releasing tong trigger places flipped side on grate")
		check(g.bbq.held[hand]==tool and tool.food==null,"Trigger release retains tongs in hand")
		# Empty repeated clicks and distant food cannot latch or eat a portion.
		pose(hand,Transform3D(Basis.IDENTITY,g.head.global_position+Vector3(1,0,0))); await step()
		trackers[hand].set_input("trigger",1.0)
		for settle in range(9): await step()
		bottom = tool.to_local(tool.jaws[0].to_global(tool.JAW_CENTER))
		top = tool.to_local(tool.jaws[1].to_global(tool.JAW_CENTER))
		check(top.y-bottom.y < .02,"Held analog trigger closes empty jaw gap")
		trackers[hand].set_input("trigger",0.0)
		for settle in range(9): await step()
		check(is_equal_approx(tool.jaw_angle,tool.OPEN_ANGLE),"Analog trigger release visibly reopens jaws")
		check(tool.food==null and not item.consumed,"Empty squeeze cannot grab distant food")
		await grip(hand,0)
		check(tool.held_hand==-1 and tool.transform.is_equal_approx(g.bbq.TONGS_REST),"Grip release docks tool")
	# Loss of tracking safely releases BOTH the tool and the food.
	pose(0,g.bbq.global_transform*g.bbq.TONGS_REST); await step(); await grip(0,1)
	var aligned := Transform3D(g.bbq.global_basis,item.global_position-g.bbq.global_basis*tool.TIP)
	pose(0,aligned); await step(); trackers[0].set_input("trigger_click",true); await step()
	check(tool.food==item,"Food attached before focus-loss test")
	g.tracking_manager.focused=false; await step()
	check(tool.food==null and tool.held_hand==-1 and item.held_hand==-1 and not item.consumed,"Focus loss safely docks tongs and releases food")
	g.tracking_manager.focused=true
	g.bbq.stop(); g.xr=false
	for tracker in trackers: XRServer.remove_tracker(tracker)
	g.queue_free(); await process_frame
	await create_timer(.3).timeout
	print("BBQ_CONTROLLERS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
