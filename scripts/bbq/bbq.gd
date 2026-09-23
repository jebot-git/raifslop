extends Node3D
const Tongs = preload("res://scripts/bbq/tongs.gd")
const Food = preload("res://scripts/bbq/food.gd")
const Session = preload("res://scripts/fishing_session.gd")
const COOK_SHADER = preload("res://shaders/bbq_food.gdshader")
const COOLER_POSITION := Vector3(.66, .48, 0)
const PREP := Vector3(-.65, .94, 0)
var game_root: Node3D
var active := false
var location_id := ""
var items: Array = []
var held := [null, null]
var grip_down := [true, true]
var choices: Array = []
var selected := 0
var cooler_open := false
var lid: Node3D
var contents := Node3D.new()
var title: Label3D
var hint: Label3D
var sizzle: AudioStreamPlayer3D
var consumed_count := 0
var was_stowed := false
var lid_tween: Tween
var tongs: Node3D
const TONGS_REST := Transform3D(Basis.IDENTITY,Vector3(-.65,.93,.37))
const LID_OPEN_ANGLE := -1.75

static func local_catches(journal: Array, location: String) -> Array:
	var result: Array = []
	var seen := {}
	for record in journal:
		if not record is Dictionary or record.get("location_id", "") != location: continue
		for species in Session.SPECIES:
			if species.latin == record.get("latin", "") and not seen.has(species.latin):
				seen[species.latin] = true
				result.append(species.duplicate())
	return result

func setup(g: Node3D) -> void:
	game_root = g
	name = "BBQ"
	add_child(model("station"))
	tongs = Tongs.new(); tongs.name = "GrillTongs"; add_child(tongs)
	tongs.transform = TONGS_REST
	var cooler := model("cooler")
	add_child(cooler); cooler.position = COOLER_POSITION
	lid = Node3D.new(); lid.name = "CoolerLid"; add_child(lid)
	# Player is on local +Z. Rear hinge is -Z; the lid extends +Z.
	# Negative X rotation lifts the front edge up and behind the cooler.
	lid.position = COOLER_POSITION + Vector3(0,.37,-.17)
	var lid_model := model("cooler_lid")
	lid.add_child(lid_model); lid_model.rotation.y = PI
	add_child(contents); contents.name = "CoolerContents"
	title = label("WATERSIDE / BBQ", Vector3(0,1.22,-.26), .0021, 27)
	hint = label("", Vector3(-.64,1.09,-.19), .0015, 22)
	label("GRIP · lift / turn / release\nTRIGGER · eat / open can",Vector3(0,.70,.254),.0011,22)
	var glow := OmniLight3D.new(); glow.position = Vector3(0,.85,0)
	glow.light_color = Color("ff8c3b"); glow.light_energy = .32; glow.omni_range = .85
	glow.shadow_enabled = false; add_child(glow)
	sizzle = AudioStreamPlayer3D.new(); add_child(sizzle)
	sizzle.stream = load("res://assets/audio/bbq/grill_sizzle.wav")
	sizzle.position = Vector3(0,.92,0); sizzle.unit_size = 1.0; sizzle.max_distance = 8; sizzle.volume_db = -24
	hide()

func model(asset: String) -> Node3D:
	return load("res://assets/models/bbq/" + asset + ".glb").instantiate()

func label(text: String, at: Vector3, pixels: float, font: int) -> Label3D:
	var n := Label3D.new(); n.text = text; n.position = at; n.pixel_size = pixels
	n.font_size = font; n.modulate = Color("fff0d5"); n.outline_size = 5
	add_child(n)
	if at.y > 1.0:
		var backing := BoxMesh.new(); backing.size = Vector3(.57 if at.x == 0 else .48,.105 if at.x == 0 else .16,.015)
		var board := MeshInstance3D.new(); board.mesh = backing; board.position = at + Vector3(0,0,-.012)
		var material := StandardMaterial3D.new(); material.albedo_color = Color("153b3d"); material.roughness = .65
		board.material_override = material; add_child(board)
		var support := MeshInstance3D.new(); var pole := CylinderMesh.new()
		pole.top_radius = .006; pole.bottom_radius = .006; pole.height = at.y - .87; pole.radial_segments = 8
		support.mesh = pole; support.material_override = material
		support.position = Vector3(at.x,(at.y+.87)/2,at.z-.023); add_child(support)
	return n

func start() -> bool:
	if active: return true
	var g = game_root
	if not g.game.state in [Session.State.READY, Session.State.LOST]:
		g.game.message = "Finish this cast and release your catch before BBQ."
		return false
	if g.fish_guide.held or g.shoulder_radio.held: return false
	if g.menu_open: g._toggle_avatar_menu()
	was_stowed = g.rod_holster.stowed
	g.rod_holster.set_stowed(true)
	active = true; show()
	var yaw := Basis(Vector3.UP, atan2(g.head.global_basis.z.x,g.head.global_basis.z.z))
	global_transform = Transform3D(yaw, Vector3(g.head.global_position.x,g.motor.global_position.y,g.head.global_position.z)+yaw*Vector3(0,0,-.85))
	if location_id != g.current_location or choices.is_empty():
		clear_items()
		location_id = g.current_location
		choices = [{"name":"Fish burger","kind":"burger"}]
		choices.append_array(local_catches(g.game.journal,location_id))
		selected = 0
		add_food()
		if choices.size() > 1:
			selected = 1; add_food()
		stock_cooler()
	else:
		# Include catches landed since the previous cookout at this water.
		choices = [{"name":"Fish burger","kind":"burger"}]
		choices.append_array(local_catches(g.game.journal,location_id))
		selected = mini(selected,choices.size()-1)
	if lid_tween and lid_tween.is_running(): lid_tween.kill()
	cooler_open = false; lid.rotation.x = 0; contents.hide()
	tongs.transform = TONGS_REST
	grip_down = [true,true]
	update_hint()
	g.game.message = "BBQ · grip food, turn your wrist, release onto the grill."
	return true

func stop() -> void:
	for hand in range(2):
		if is_instance_valid(held[hand]): return_to_prep(held[hand]); held[hand] = null
	active = false; hide(); sizzle.stop()
	game_root.motor.catch_controls = false
	if not was_stowed: game_root.rod_holster.set_stowed(false)

func clear_items() -> void:
	for item in items:
		if is_instance_valid(item): item.queue_free()
	items.clear(); held = [null,null]

func stock_cooler() -> void:
	for i in range(4):
		var item := Food.new(); item.kind = "beer"; item.display_name = "Lager"
		contents.add_child(item); item.add_child(model("beer_can"))
		item.position = COOLER_POSITION + Vector3(-.07 + (i%2)*.14,.20,-.065 + (i/2)*.13)
		item.in_cooler = true; item.home = item.transform; items.append(item)

func add_food() -> void:
	if not active: return
	var count := 0
	for item in items:
		if is_instance_valid(item) and item.kind != "beer" and not item.consumed: count += 1
	if count >= 4: game_root.game.message = "Serve some food before preparing more."; return
	var choice: Dictionary = choices[selected]
	var item := Food.new(); item.kind = choice.get("kind","fish"); item.display_name = choice.name
	add_child(item)
	var visual := Node3D.new(); item.add_child(visual)
	if item.kind == "burger": visual.add_child(model("fish_burger")); item.thickness = .052
	else:
		var path: String = choice.get("model", "res://assets/models/european_perch.glb")
		var fish: Node3D = load(path).instantiate()
		visual.add_child(fish); fish.rotation.y = float(choice.get("model_yaw",0))
		var bounds := preload("res://scripts/fish_size.gd").fit(visual,32.0)
		fish.position -= bounds.get_center()
		visual.rotation.x = PI/2
		item.thickness = maxf(.025, bounds.size.z/2)
	apply_cooking_material(visual,item)
	items.append(item); return_to_prep(item); item.home = item.transform
	update_hint()

func apply_cooking_material(node: Node3D, item: Node3D) -> void:
	if node is MeshInstance3D:
		for surface in node.mesh.get_surface_count():
			var original = node.get_active_material(surface)
			if not original is BaseMaterial3D: continue
			var material := ShaderMaterial.new(); material.shader = COOK_SHADER
			material.set_shader_parameter("world_to_food",item.global_transform.affine_inverse())
			material.set_shader_parameter("food_color",original.albedo_color)
			material.set_shader_parameter("food_roughness",original.roughness)
			if original.albedo_texture:
				material.set_shader_parameter("use_texture",true)
				material.set_shader_parameter("food_texture",original.albedo_texture)
			node.set_surface_override_material(surface,material); item.cook_materials.append(material)
	for child in node.get_children():
		if child is Node3D: apply_cooking_material(child,item)

func return_to_prep(item: Node3D) -> void:
	if item == tongs:
		if is_instance_valid(tongs.food): return_to_prep(tongs.food)
		tongs.food = null; tongs.squeezed = false; tongs.held_hand = -1
		tongs.jaw_angle = Tongs.REST_ANGLE; tongs.animate_jaws(0)
		tongs.transform = TONGS_REST; return
	if item.get_parent() != self: item.reparent(self)
	item.held_hand = -1; item.on_grill = false; item.in_cooler = false
	if item.kind == "beer":
		item.reparent(contents); item.transform = item.home; item.in_cooler = true; return
	var slot := 0
	for other in items:
		if other != item and is_instance_valid(other) and not other.consumed and other.held_hand < 0 and not other.on_grill and not other.in_cooler and other.kind != "beer": slot += 1
	item.transform = Transform3D(Basis.IDENTITY,PREP + Vector3(0,(slot/2)*.11,(slot%2)*.22-.11))

func update_hint() -> void:
	if choices.is_empty(): return
	hint.text = choices[selected].name + "\nA/X · choose   grip · prepare"
	if choices.size() == 1: hint.text += "\nCatch fish here to add them"

func toggle_cooler() -> void:
	cooler_open = not cooler_open
	if cooler_open: contents.show()
	if lid_tween and lid_tween.is_running(): lid_tween.kill()
	lid_tween = create_tween()
	lid_tween.tween_property(lid,"rotation:x",LID_OPEN_ANGLE if cooler_open else 0.0,.3)
	if not cooler_open: contents.hide()

func pickup(hand: int, item: Node3D, pose: Transform3D) -> bool:
	if is_instance_valid(held[hand]) or not item.is_visible_in_tree(): return false
	if item.in_cooler and not cooler_open: return false
	if not item.pickup(hand,pose): return false
	if item.get_parent() != self: item.reparent(self)
	held[hand] = item; return true

func release(hand: int) -> void:
	var item = held[hand]
	if not is_instance_valid(item): return
	if item == tongs:
		squeeze_tongs(hand,false)
		return_to_prep(tongs)
	else: place_item(item)
	held[hand] = null

func place_item(item: Node3D) -> void:
	var p: Vector3 = to_local(item.global_position)
	if item.kind != "beer" and absf(p.x) <= .30 and absf(p.z) <= .22 and p.y > .86 and p.y < 1.35:
		item.place_on_grill(to_global(Vector3(0,.912,0)).y)
	else: return_to_prep(item)

func nearest(p: Vector3, distance := .18, food_only := false) -> Node3D:
	var best: Node3D
	for item in items + ([tongs] if not food_only else []):
		if food_only and item.kind not in ["fish","burger"]: continue
		if not is_instance_valid(item) or item.consumed or item.held_hand >= 0 or not item.is_visible_in_tree(): continue
		if item.in_cooler and not cooler_open: continue
		var d: float = item.global_position.distance_to(p)
		if d < distance: distance = d; best = item
	return best

func trigger(hand: int) -> bool:
	if not active or game_root.menu_open: return false
	if game_root.xr and (not game_root.tracking_manager.focused or not (game_root.left if hand == 0 else game_root.right).get_has_tracking_data()): return true
	var item = held[hand]
	if item == tongs:
		if game_root.xr: tongs.follow_hand(game_root.controller_pose(hand))
		squeeze_tongs(hand,true); return true
	if is_instance_valid(item):
		if item.kind == "beer" and not item.opened:
			item.opened = true; item.opening_age = 0
			play_open(item.global_position)
		else: consume(item)
		return true
	var pose: Transform3D = game_root.controller_pose(hand)
	if pose.origin.distance_to(to_global(COOLER_POSITION+Vector3(0,.37,0))) < .30: toggle_cooler()
	return true

func squeeze_tongs(hand: int, down: bool) -> void:
	if held[hand] != tongs or tongs.squeezed == down: return
	tongs.squeezed = down
	if down:
		var item := nearest(tongs.to_global(Tongs.TIP),.09,true)
		if item: tongs.clamp_item(item)
	elif is_instance_valid(tongs.food):
		place_item(tongs.food)
		tongs.food = null

func play_open(at: Vector3) -> void:
	var sound := AudioStreamPlayer3D.new(); add_child(sound)
	sound.stream = load("res://assets/audio/bbq/can_open.wav")
	sound.global_position = at; sound.volume_db = -5; sound.max_distance = 8
	sound.finished.connect(sound.queue_free); sound.play()

func consume(item: Node3D) -> void:
	if item == tongs or item.consumed or item.held_hand < 0: return
	if item.kind == "beer" and not item.opened: return
	if tongs.food == item: tongs.food = null
	else: held[item.held_hand] = null
	item.held_hand = -1
	item.consumed = true; item.hide(); consumed_count += 1
	game_root.game.message = "Enjoy your " + item.display_name.to_lower() + "."
	items.erase(item); item.queue_free()

func button(hand: int, action: String) -> bool:
	if not active or game_root.menu_open: return false
	if action == "trigger_click": return trigger(hand)
	if action == "ax_button": selected = posmod(selected+1,choices.size()); update_hint(); return true
	return false

func tick(delta: float) -> void:
	if not active: return
	var g = game_root
	if location_id != g.current_location: stop(); return
	var valid: bool = not g.menu_open and g.tracking_manager.focused
	var face: Vector3 = g.head.global_transform * Vector3(0,-.075,-.08)
	var cooking := false
	for hand in range(2):
		if not valid:
			grip_down[hand] = true
			if is_instance_valid(held[hand]): return_to_prep(held[hand]); held[hand] = null
			continue
		var controller = g.left if hand == 0 else g.right
		if not controller.get_has_tracking_data():
			grip_down[hand] = true
			if is_instance_valid(held[hand]): return_to_prep(held[hand]); held[hand] = null
			continue
		var pose: Transform3D = g.controller_pose(hand)
		var down: bool = controller.get_float("grip") > (.35 if grip_down[hand] else .55)
		if down and not grip_down[hand]:
			var item := nearest(pose.origin)
			if item: pickup(hand,item,pose)
			elif pose.origin.distance_to(to_global(PREP+Vector3(0,.15,-.19))) < .20: add_food()
		# Release uses this frame's tracked pose, including a last-moment wrist turn.
		if is_instance_valid(held[hand]): held[hand].follow_hand(pose)
		if not down and grip_down[hand]: release(hand)
		grip_down[hand] = down
		if is_instance_valid(held[hand]): held[hand].follow_hand(pose)
		if held[hand] == tongs:
			squeeze_tongs(hand,controller.is_button_pressed("trigger_click") or controller.get_float("trigger") > (.35 if tongs.squeezed else .55))
	tongs.animate_jaws(delta)
	if is_instance_valid(tongs.food): tongs.food.follow_hand(tongs.global_transform)
	for item in items.duplicate():
		if not is_instance_valid(item): continue
		if item.on_grill: cooking = true
		if item.advance(delta,face,valid): consume(item)
	if cooking and not sizzle.playing: sizzle.play()
	elif not cooking: sizzle.stop()
	g.motor.catch_controls = false
