extends Node3D
## Journal-backed species collection and a grabbable field-guide device.
const GRIP_OFFSET := Vector3(0, 0.265, -0.035)
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
 "Salmo trutta": "A trout with golden-brown flanks, dark and red spots, and a small adipose fin."
}
var entries: Dictionary = {}
var selected := 0
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
	selected = posmod(selected + direction, entries.size())
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
	_box(Vector3(-0.052, -0.128, 0.025), Vector3(0.040, 0.020, 0.012), button)
	_box(Vector3(0.052, -0.128, 0.025), Vector3(0.040, 0.020, 0.012), button)
	# Dedicated lower grip keeps fingers below both navigation buttons and screen.
	_box(Vector3(0, -0.225, -0.006), Vector3(0.065, 0.16, 0.045), dark)
	_box(Vector3(0, -0.29, -0.006), Vector3(0.075, 0.025, 0.052), shell)
	_box(Vector3(0.078, 0.16, 0), Vector3(0.017, 0.055, 0.02), dark)
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

func _box(position_: Vector3, size_: Vector3, material_: Material) -> void:
	var node := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size_
	node.mesh = box
	node.material_override = material_
	node.position = position_
	device.add_child(node)

func dock() -> void:
	held = false
	if is_instance_valid(photo_camera):
		photo_camera.view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	stick_latched = false
	screen.queue_redraw()

func dock_grip_position() -> Vector3:
	return belt_transform * -GRIP_OFFSET

func update_device() -> void:
	var g = game_root
	var facing: Basis = g.origin.global_basis.orthonormalized()
	var belt := Vector3(g.head.global_position.x, maxf(g.motor.global_position.y + 0.55, g.head.global_position.y - 0.70), g.head.global_position.z)
	belt += facing * Vector3(-0.26, 0, 0.04)
	belt_transform = Transform3D(facing, belt)
	if g.xr:
		var tracked: bool = g.left.get_has_tracking_data()
		var down: bool = tracked and g.left.get_float("grip") > 0.55
		if held and not down: dock()
		if not held and down and not grip_was_down and not g.menu_open and g.left.global_position.distance_to(dock_grip_position()) < 0.22:
			held = true
			screen.queue_redraw()
		grip_was_down = down
		if held:
			# Fixed grip-relative pose: the player can naturally turn the screen over.
			global_transform = g.left.global_transform * Transform3D(Basis.IDENTITY, GRIP_OFFSET)
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
