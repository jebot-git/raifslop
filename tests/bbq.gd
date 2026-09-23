extends SceneTree
const BBQ = preload("res://scripts/bbq/bbq.gd")
const Food = preload("res://scripts/bbq/food.gd")
const Session = preload("res://scripts/fishing_session.gd")
var failures := 0
var checks := 0
class Rig extends Node3D:
	var held := false
class Holster extends Node3D:
	var stowed := true
	func set_stowed(value: bool) -> void: stowed = value
class Motor extends Node3D:
	var catch_controls := false
class FakeGame extends Node3D:
	var game = Session.new()
	var head := Node3D.new()
	var motor := Motor.new()
	var rod_holster := Holster.new()
	var fish_guide := Rig.new()
	var shoulder_radio := Rig.new()
	var current_location := "lakeside"
	var menu_open := false
	var xr := false
	func _ready() -> void:
		add_child(head); add_child(motor); add_child(rod_holster)
		add_child(fish_guide); add_child(shoulder_radio); head.position.y = 1.65
	func controller_pose(_hand: int) -> Transform3D: return Transform3D.IDENTITY
	func _toggle_avatar_menu() -> void: menu_open = not menu_open

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var journal := [{"latin":"Perca fluviatilis","location_id":"lakeside"},{"latin":"Perca fluviatilis","location_id":"lakeside"},{"latin":"Salmo trutta","location_id":"meadow_bend"},{"latin":"Carassius carassius"},{"latin":"unknown","location_id":"lakeside"}]
	var local := BBQ.local_catches(journal,"lakeside")
	check(local.size() == 1 and local[0].latin == "Perca fluviatilis", "Only actual catches from this location; duplicates and malformed entries excluded")
	check(BBQ.local_catches(journal,"coastal_rocks").is_empty(),"Unvisited water has no catch options")
	var g := FakeGame.new(); root.add_child(g); g.game.journal = journal
	var bbq := BBQ.new(); g.add_child(bbq); bbq.setup(g)
	check(bbq.start(),"Cookout starts while ready")
	# Check actual transformed mesh vertices, not merely the sign of the angle.
	var lid_vertices: Array[Vector3] = []
	for mesh in bbq.lid.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			for vertex in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				lid_vertices.append(bbq.lid.to_local(mesh.to_global(vertex)))
	var front := Vector3.ZERO
	for vertex in lid_vertices:
		if vertex.z > front.z: front = vertex
	check(front.z > .34,"Exported lid front edge faces the player (+Z)")
	# Use the edge centreline: the latch hangs below it and initially sweeps
	# a few millimetres forward as it rises, although the lid opens rearward.
	front.y = 0.0
	var hinge: Vector3 = bbq.lid.position
	var previous_front: Vector3 = bbq.to_local(bbq.lid.to_global(front))
	for frame in range(1,21):
		bbq.lid.rotation.x = bbq.LID_OPEN_ANGLE*frame/20.0
		var edge: Vector3 = bbq.to_local(bbq.lid.to_global(front))
		check(edge.y > hinge.y and edge.z < previous_front.z,"Opening lifts front edge above rim and away from player")
		check(bbq.lid.position.is_equal_approx(hinge),"Rear hinge stays fixed")
		previous_front = edge
	check(previous_front.z < hinge.z,"Open lid clears the interior behind the rear hinge")
	bbq.lid.rotation.x = 0

	check(bbq.choices.size() == 2 and bbq.choices[0].kind == "burger", "Only local fish and fish burgers on menu")
	var cans: Array = bbq.items.filter(func(i): return i.kind == "beer")
	check(cans.size() == 4 and not bbq.cooler_open,"Four cans stocked in closed cooler")
	for can in cans:
		check(can.get_parent() == bbq.contents and not can.is_visible_in_tree(),"Can hidden inside cooler")
		check(not bbq.pickup(0,can,can.global_transform),"Closed cooler cannot be grabbed through")
	var fish = bbq.items[0]
	check(not fish.advance(300,fish.global_position,true),"Food on plate never consumed by timeout or face proximity")
	var pose: Transform3D = fish.global_transform
	check(bbq.pickup(0,fish,pose),"Left hand can pick food up")
	check(not bbq.pickup(1,fish,pose),"Second hand cannot steal a held item")
	check(not fish.advance(120,Vector3(0,5,0),true) and not fish.consumed,"Food stays held indefinitely")
	bbq.trigger(1)
	check(not fish.consumed,"Other hand trigger cannot eat held food")
	fish.global_transform = bbq.global_transform * Transform3D(Basis.IDENTITY,Vector3(0,1.0,0))
	bbq.release(0)
	check(fish.on_grill and fish.side == 0,"Food contacts grate on its first side")
	fish.advance(18,Vector3(0,5,0),true)
	check(is_equal_approx(fish.cook[0],1.0) and fish.cook[1] == 0,"Only touching side cooks")
	pose = fish.global_transform
	bbq.pickup(1,fish,pose)
	var turned := pose * Transform3D(Basis(Vector3.RIGHT,PI),Vector3.ZERO)
	fish.follow_hand(turned)
	bbq.release(1)
	check(fish.on_grill and fish.side == 1 and fish.global_basis.y.y < -.99,"Actual controller half-turn flips food on placement")
	fish.advance(18,Vector3(0,5,0),true)
	check(is_equal_approx(fish.cook[0],1.0) and is_equal_approx(fish.cook[1],1.0),"Flipped side cooks independently")
	bbq.pickup(0,fish,fish.global_transform); bbq.trigger(0)
	check(fish.consumed and bbq.held[0] == null,"Holding-hand trigger eats food exactly once")
	var count: int = bbq.consumed_count; bbq.consume(fish)
	check(bbq.consumed_count == count,"No double consumption")
	bbq.toggle_cooler()
	await create_timer(.35).timeout
	check(bbq.lid.rotation.x < -1.7,"Lid swings upward behind cooler")
	var can = cans[0]
	check(can.is_visible_in_tree() and bbq.pickup(1,can,can.global_transform),"Open cooler exposes grabbable can")
	bbq.toggle_cooler()
	check(can.is_visible_in_tree(),"Held can remains visible when cooler closes")
	check(not can.advance(2,can.global_position,true),"Sealed can cannot be consumed at face")
	bbq.trigger(1)
	check(can.opened and not can.consumed,"First trigger opens can without consuming")
	check(bbq.get_children().any(func(n):return n is AudioStreamPlayer3D and n != bbq.sizzle and n.playing),"Opening sound plays once")
	bbq.trigger(0); check(not can.consumed,"Other trigger cannot consume opened can")
	bbq.trigger(1); check(can.consumed,"Next holding-hand trigger drinks can")
	bbq.toggle_cooler(); can = cans[1]; bbq.pickup(0,can,can.global_transform); bbq.trigger(0)
	check(not can.advance(.1,can.global_position,true),"Face gesture has opening debounce")
	check(can.advance(.5,can.global_position,true),"Opened can can be drunk at the face")
	bbq.consume(can)
	var burger = bbq.items.filter(func(i):return i.kind == "fish")[0]
	bbq.pickup(1,burger,burger.global_transform)
	check(not burger.advance(1,burger.global_position,false),"Focus/menu guard prevents face consumption")
	bbq.stop()
	check(not bbq.active and bbq.held[1] == null and not burger.consumed,"Stopping returns food safely")
	g.current_location = "meadow_bend"; bbq.start()
	check(bbq.choices.size() == 2 and bbq.choices[1].latin == "Salmo trutta", "Changing water replaces local catch menu")
	check(bbq.items.filter(func(i):return i.kind == "beer").size() == 4,"New location stocks fresh hidden cooler")
	# Tongs clamp through the tracked trigger; wrist rotation flips the portion.
	var tool = bbq.tongs
	var portion = bbq.items[0]
	portion.position = Vector3(0,1.1,0)
	var tool_pose := Transform3D(bbq.global_basis,portion.global_position-bbq.global_basis*tool.TIP)
	check(bbq.pickup(1,tool,tool_pose),"Tracked hand can hold tongs")
	bbq.squeeze_tongs(1,true)
	check(tool.food==portion and not portion.consumed,"Trigger clamps without consuming")
	tool.rotate_object_local(Vector3.FORWARD,PI);tool.food.follow_hand(tool.global_transform)
	bbq.squeeze_tongs(1,false)
	check(portion.on_grill and portion.side==1 and bbq.held[1]==tool,"Wrist flip and trigger release put opposite side down")
	var beer = bbq.items.filter(func(i):return i.kind=="beer")[0]
	check(not tool.clamp_item(beer),"Tongs cannot clamp beer")
	# Face consumption of tong-held food preserves the tool and opens ownership.
	portion.position=Vector3(0,1.1,0)
	tool.global_transform=Transform3D(bbq.global_basis,portion.global_position-bbq.global_basis*tool.TIP)
	bbq.squeeze_tongs(1,true)
	check(tool.food==portion,"Food attached for face consumption")
	check(portion.advance(1,portion.global_position,true),"Food in tongs still supports face consumption")
	bbq.consume(portion)
	check(tool.food==null and bbq.held[1]==tool and not tool.consumed,"Eating clamped food retains tongs")
	bbq.consume(tool)
	check(not tool.consumed,"Tongs cannot be consumed")
	bbq.release(1)
	# The tool belongs to the activity, including while held. No detached
	# display/inspection copy may remain visible after a cookout ends.
	for cycle in range(3):
		bbq.stop()
		check(not tool.is_visible_in_tree(),"Ending BBQ hides the tongs")
		var visible_meshes := 0
		for mesh in bbq.find_children("*","MeshInstance3D",true,false):
			if mesh.is_visible_in_tree(): visible_meshes += 1
		check(visible_meshes == 0,"Ending BBQ hides every station, food and tool mesh")
		check(bbq.start(),"BBQ can restart after cleanup")
		var tools_in_game := 0
		for node in g.find_children("*","Node3D",true,false):
			if node.get_script() == BBQ.Tongs: tools_in_game += 1
		check(tools_in_game == 1 and bbq.tongs == tool,"Repeated cookouts keep exactly one pair of tongs")
		check(tool.get_parent() == bbq and tool.is_visible_in_tree(),"Tongs inherit the active BBQ visibility")
		check(tool.transform.is_equal_approx(BBQ.TONGS_REST),"Restart places tongs back on the prep board")
		check(bbq.pickup(cycle%2,tool,tool_pose),"Either hand can hold tongs before ending BBQ")
	bbq.stop(); g.game.state = Session.State.FIGHT
	check(not bbq.start(),"Cannot discard active fight by starting BBQ")
	print("BBQ: %d checks, %d failures" % [checks,failures])
	g.queue_free(); await process_frame
	quit(1 if failures else 0)
