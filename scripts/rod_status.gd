extends Node3D
## Small tackle details and a brief world-space confirmation at the rod handle.
var game_root: Node3D
var bait_visual: Node3D
var label: Label3D
var remaining := 0.0
var previous_bait := -1
func _ready() -> void:
	bait_visual=preload("res://scripts/bait_visual.gd").new();add_child(bait_visual)
	label=Label3D.new();add_child(label)
	label.layers=preload("res://scripts/guide_camera.gd").UI_LAYER
	label.font_size=30;label.pixel_size=.0015;label.outline_size=8
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test=false;label.hide()
	update_bait()
func update_bait() -> void:
	if previous_bait==game_root.game.bait:return
	previous_bait=game_root.game.bait
	bait_visual.set_bait(previous_bait)
func show_bait() -> void:
	update_bait();label.text=game_root.game.BAITS[game_root.game.bait]
	remaining=2.2;label.show()
func _process(delta: float) -> void:
	update_bait()
	remaining=maxf(0,remaining-delta)
	label.visible=remaining>0 and not game_root.rod_holster.stowed
	label.global_position=game_root.rod.to_global(Vector3(0,.16,-.78))
