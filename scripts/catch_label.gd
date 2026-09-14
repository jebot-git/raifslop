extends Label3D
## A label attached to the held catch, never a floating status window.
var game_root: Node
func _ready() -> void:
	name = "HeldCatchLabel"
	font_size = 48
	pixel_size = .0008
	outline_size = 8
	modulate = Color("f0eee1")
	outline_modulate = Color("13251f")
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = false
	shaded = false
	hide()
func _process(_delta: float) -> void:
	var g = game_root
	visible = g.xr and g.game.state == g.Session.State.LANDED and g.fish_display.visible and g.catch_in_hand and not g.menu_open and not g.fish_guide.held and g.left.get_has_tracking_data() and g.tracking_manager.focused
	if not visible: return
	var record: Dictionary = g.game.journal.back() if not g.game.journal.is_empty() else g.Session.SPECIES[g.game.fish_index]
	text = "%s\n%.0f cm · %.2f kg" % [record.name, record.length, record.weight]
	var bounds: AABB = g.fish_display.global_transform * g.catch_bounds
	global_position = Vector3(bounds.get_center().x, bounds.end.y + .13, bounds.get_center().z)
