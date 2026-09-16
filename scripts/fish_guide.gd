extends Node3D
## Journal-backed species collection and a grabbable field-guide device.
const GRIP_ANCHOR := Vector3(0, -0.225, -0.006)
# OpenXR grip -Z points toward the thumb. The guide extends above the fist,
# with its screen toward the palm side, rather than along the wrist axis.
const GRIP_BASIS := Basis(Vector3.RIGHT, -PI / 2.0)
const GRIP_OFFSET := -(GRIP_BASIS * GRIP_ANCHOR)
const BUTTON_CENTERS := [Vector3(-0.052, -0.128, 0.031), Vector3(0.052, -0.128, 0.031)]
var button_nodes: Array[MeshInstance3D] = []
var button_armed := [false, false]
var button_down := [false, false]
var touch_source := ""
var previous_touch := Vector3(INF, INF, INF)
const Session = preload("res://scripts/fishing_session.gd")
const DESCRIPTIONS = {
 "Thymallus thymallus": "A slender silver fish with a tall, colourful dorsal fin and a small adipose fin. It feeds mainly on aquatic invertebrates.",
 "Barbus barbus": "A bronze river fish with a low mouth and four barbels used to find food near the riverbed.",
 "Leuciscus leuciscus": "A slim silver shoaling fish with yellow eyes and concave dorsal and anal fin edges.",
 "Alburnus alburnus": "A small silver fish with a slightly upturned mouth and a long anal fin. It often feeds near the surface.",
 "Gobio gobio": "A small bottom-feeding fish with dark blotches along its flanks and a pair of barbels at the mouth.",
 "Salvelinus fontinalis": "A char with pale wavy markings, red spots with blue halos, and white leading edges on its lower fins.",

 "Perca fluviatilis": "A striped freshwater predator with spiny dorsal fins and reddish lower fins.",
 "Cyprinus carpio": "A sturdy freshwater fish with mouth barbels. It feeds on a mixture of plants and small animals.",
 "Esox lucius": "An elongated ambush predator with a broad snout and sharp teeth, often found near vegetation.",
 "Rutilus rutilus": "A silver-bodied fish with reddish eyes and fins, commonly found in shoals.",
 "Tinca tinca": "An olive-green freshwater fish with small red eyes and rounded fins.",
 "Abramis brama": "A deep-bodied, flattened fish with a long anal fin and a mouth adapted for feeding near the bottom.",
 "Sander lucioperca": "A freshwater predator with two dorsal fins, a pale belly and prominent canine teeth.",
 "Scardinius erythrophthalmus": "A deep-bodied fish with golden flanks, bright red fins and a small upturned mouth.",
 "Carassius carassius": "A bronze, deep-bodied carp relative with a rounded dorsal fin and no mouth barbels.",
 "Squalius cephalus": "A broad-headed river fish with large dark-edged scales and orange-red lower fins.",
 "Oncorhynchus mykiss": "A streamlined trout with dark spots, a pink stripe along its sides and a small adipose fin.",
 "Salmo trutta": "A trout with golden-brown flanks, dark and red spots, and a small adipose fin.",
 "Diplodus capensis": "A silver coastal seabream identified by the broad black band at the base of its tail. It feeds around rocky shores.",
 "Dichistius capensis": "A deep-bodied grey fish of rocky and sandy surf zones. It grazes food from submerged rocks.",
 "Pachymetopon blochii": "A bronze-grey seabream with a small mouth and forked tail, associated with rocky reefs and kelp along the west coast.",
 "Chrysoblephus laticeps": "A red reef seabream with a pale vertical band across its flank. Adults are closely associated with their home reefs.",
 "Lithognathus lithognathus": "A silvery seabream with dark vertical bars and a long blunt snout. It searches sand for invertebrates.",
 "Pomatomus saltatrix": "A streamlined blue-green and silver predator with a large toothed mouth. Also called shad, it pursues small fish along the coast.",
 "Seriola lalandi": "A powerful schooling predator with a yellow flank stripe and deeply forked yellow tail. It hunts fish and squid in coastal waters.",
 "Chelon richardsonii": "A silver mullet with a blunt head, fine horizontal stripes and two separate dorsal fins. It feeds in shallow coastal and estuarine water.",
 "Silurus glanis":"A huge scaleless catfish with a broad head, six barbels and a long anal fin. A rare predator that can seize a smaller freshwater fish during retrieval.",
 "Carcharhinus brachyurus":"A bronze-grey coastal shark with five gill slits and a long upper tail lobe. A rare predator that can take a hooked mullet or other small coastal fish."
}
var entries: Dictionary = {}
var selected := -1
var held := false
var grip_was_down := false
var stick_latched := false
var belt_transform := Transform3D.IDENTITY
var viewport: SubViewport
var screen: Control
var device: Node3D
var photo_camera: Node
var game_root: Node3D

func ingest(journal: Array) -> bool:
	var changed := false
	for record in journal:
		if not record is Dictionary: continue
		var id := str(record.get("latin", ""))
		var species := {}
		for candidate in Session.SPECIES:
			if candidate.latin == id or (id.is_empty() and candidate.name == record.get("name", "")):
				species = candidate
				id = candidate.latin
				break
		if species.is_empty(): continue
		var raw_length = record.get("length", 0.0)
		if not (raw_length is float or raw_length is int): continue
		var length := float(raw_length)
		if not is_finite(length) or length <= 0: continue
		if not entries.has(id):
			entries[id] = {"name": species.name, "latin": id, "description": DESCRIPTIONS[id], "length": length}
			changed = true
		elif length > float(entries[id].length):
			entries[id].length = length
			changed = true
	if changed and is_instance_valid(screen): screen.queue_redraw()
	return changed

func ordered_entries() -> Array:
	var result := []
	for species in Session.SPECIES:
		if entries.has(species.latin): result.append(entries[species.latin])
	return result

func page(direction: int) -> void:
	if is_instance_valid(photo_camera) and photo_camera.active: return
	if entries.is_empty(): return
	selected = posmod(selected + 1 + direction, entries.size() + 1) - 1
	screen.queue_redraw()

func _ready() -> void:
	device = Node3D.new()
	add_child(device)
	# Authored low-poly field instrument: housing, raised screen and buttons.
	var shell := StandardMaterial3D.new()
	shell.albedo_color = Color("c86337")
	shell.roughness = 0.65
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("172e29")
	var button := StandardMaterial3D.new()
	button.albedo_color = Color("a7d9b5")
	_box(Vector3(0, 0, 0), Vector3(0.205, 0.305, 0.035), shell)
	_box(Vector3(0, 0.015, 0.022), Vector3(0.183, 0.247, 0.014), dark)
	for center in BUTTON_CENTERS:
		button_nodes.append(_box(center - Vector3(0, 0, 0.006), Vector3(0.045, 0.028, 0.012), button))
		var label := Label3D.new()
		label.text = "‹" if button_nodes.size() == 1 else "›"
		label.font_size = 48
		label.pixel_size = 0.00045
		label.position = center + Vector3(0, 0, 0.001)
		label.modulate = Color("172e29")
		device.add_child(label)
	# Dedicated lower grip keeps fingers below both navigation buttons and screen.
	_box(Vector3(0, -0.225, -0.006), Vector3(0.065, 0.16, 0.045), dark)
	_box(Vector3(0, -0.29, -0.006), Vector3(0.075, 0.025, 0.052), shell)
	_box(Vector3(0.078, 0.16, 0), Vector3(0.017, 0.055, 0.02), dark)
	# Visible front/rear lenses share the exact mounts used by the photo camera.
	for front in [false, true]:
		var lens := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.006; cylinder.bottom_radius = 0.006; cylinder.height = 0.004
		lens.mesh = cylinder
		lens.material_override = dark
		lens.transform = preload("res://scripts/guide_camera.gd").lens_pose(front)
		lens.rotate_object_local(Vector3.RIGHT, PI / 2.0)
		device.add_child(lens)
	viewport = SubViewport.new()
	viewport.size = Vector2i(640, 840)
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	screen = preload("res://scripts/fish_guide_screen.gd").new()
	screen.guide = self
	viewport.add_child(screen)
	var surface := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.169, 0.222)
	surface.mesh = quad
	surface.position = Vector3(0, 0.018, 0.031)
	var display := StandardMaterial3D.new()
	display.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	display.albedo_texture = viewport.get_texture()
	display.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	surface.material_override = display
	device.add_child(surface)
	photo_camera = preload("res://scripts/guide_camera.gd").new()
	add_child(photo_camera)
	photo_camera.setup(self)

func _box(position_: Vector3, size_: Vector3, material_: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size_
	node.mesh = box
	node.material_override = material_
	node.position = position_
	device.add_child(node)
	return node

func dock() -> void:
	held = false
	if is_instance_valid(photo_camera):
		photo_camera.view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	stick_latched = false
	reset_touch()
	screen.queue_redraw()

func dock_grip_position() -> Vector3:
	return belt_transform * GRIP_ANCHOR

func reset_touch() -> void:
	previous_touch = Vector3(INF, INF, INF)
	button_armed = [false, false]
	button_down = [false, false]

func press_buttons(point: Vector3) -> void:
	if not point.is_finite(): reset_touch(); return
	var local := to_local(point)
	var continuous := previous_touch.is_finite() and local.distance_to(previous_touch) < 0.15
	for i in BUTTON_CENTERS.size():
		var p: Vector3 = local - BUTTON_CENTERS[i]
		var before: Vector3 = previous_touch - BUTTON_CENTERS[i]
		var inside := absf(p.x) < 0.032 and absf(p.y) < 0.025
		# A short withdrawal rearms the physical button, even if the finger stays over it.
		if not inside or p.z > 0.018:
			button_down[i] = false
		button_armed[i] = inside and p.z > 0.010
		# Sweep through the front contact plane: fast/diagonal pokes cannot skip it.
		if continuous and before.z > 0.010 and p.z <= 0.010 and not button_down[i]:
			var contact := before.lerp(p, (before.z - 0.010) / (before.z - p.z))
			if absf(contact.x) < 0.032 and absf(contact.y) < 0.025:
				button_down[i] = true
				button_armed[i] = false
				if photo_camera.active:
					if i == 0: photo_camera.toggle_selfie()
					else: photo_camera.capture()
				else: page(-1 if i == 0 else 1)
				if game_root.xr and game_root.right.get_has_tracking_data(): game_root.right.trigger_haptic_pulse("haptic", 0, 0.25, 0.04, 0)
		if i < button_nodes.size(): button_nodes[i].position.z = BUTTON_CENTERS[i].z - (0.010 if button_down[i] else 0.006)
	previous_touch = local

func _touch_from(source: String, point: Variant) -> Variant:
	if source != touch_source:
		reset_touch()
		touch_source = source
	return point

func touch_position() -> Variant:
	var g = game_root
	var hand := XRServer.get_tracker("/user/hand_tracker/right") as XRHandTracker
	if hand and hand.has_tracking_data:
		var joint := XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP
		if hand.get_hand_joint_flags(joint) & XRHandTracker.HAND_JOINT_FLAG_POSITION_VALID:
			var point := hand.get_hand_joint_transform(joint).origin
			if point.is_finite(): return _touch_from("native", g.origin.to_global(point * XRServer.world_scale))
	if g.right.get_has_tracking_data() and is_instance_valid(g.avatar):
		var point = g.avatar.index_touch_position()
		if point is Vector3 and point.is_finite(): return _touch_from("avatar", point)
	return _touch_from("none", null)

func can_grab() -> bool:
	return game_root.game.state not in [game_root.Session.State.BITE, game_root.Session.State.FIGHT]

func update_device() -> void:
	if held and not can_grab(): dock()
	if held: screen.queue_redraw()
	var g = game_root
	var facing := Basis(Vector3.UP, atan2(g.head.global_basis.z.x, g.head.global_basis.z.z))
	var belt := Vector3(g.head.global_position.x, maxf(g.motor.global_position.y + 0.55, g.head.global_position.y - 0.70), g.head.global_position.z)
	if is_instance_valid(g.tracking_manager) and g.tracking_manager.body.has("hips"):
		var hips: Transform3D = g.motor.global_transform * g.tracking_manager.body.hips
		belt = hips.origin
		facing = Basis(Vector3.UP, atan2(hips.basis.z.x, hips.basis.z.z))
	belt += facing * Vector3(-0.24, 0, -0.02)
	# The handle is at hip height, screen faces outward, and the body hangs below it.
	var holster_basis := facing * Basis(Vector3.FORWARD, Vector3.DOWN, Vector3.LEFT)
	belt_transform = Transform3D(holster_basis, belt - holster_basis * GRIP_ANCHOR)
	if g.xr:
		var tracked: bool = g.left.get_has_tracking_data()
		var down: bool = tracked and g.left.get_float("grip") > 0.55
		if held and not down: dock()
		if not held and can_grab() and down and not grip_was_down and not g.menu_open and not (is_instance_valid(g.shoulder_radio) and g.shoulder_radio.held) and g.left.global_position.distance_to(dock_grip_position()) < 0.22:
			held = true
			screen.queue_redraw()
		grip_was_down = down
		if held:
			# Fixed grip-relative pose: the player can naturally turn the screen over.
			global_transform = g.left.global_transform * Transform3D(GRIP_BASIS, GRIP_OFFSET)
			var touch = touch_position()
			if touch is Vector3: press_buttons(touch)
			else: reset_touch()
			var axes: Vector2 = g.left.get_vector2("primary") + g.right.get_vector2("primary")
			var axis: float = axes.x if absf(axes.x) >= absf(axes.y) else axes.y
			if absf(axis) > 0.65 and not stick_latched:
				page(1 if axis > 0 else -1)
				stick_latched = true
			if absf(axis) < 0.25: stick_latched = false
		else: global_transform = belt_transform
	else:
		global_transform = g.head.global_transform * Transform3D(Basis.IDENTITY, Vector3(0, -0.04, -0.48)) if held else belt_transform
	visible = g.xr or held
