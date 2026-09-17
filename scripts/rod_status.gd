extends Node3D
## Small tackle details and a brief world-space confirmation at the rod handle.
var game_root: Node3D
var bait_visual: Node3D
var label: Label3D
var remaining := 0.0
var notice_remaining:=0.0
var notice_icon:=""
var pictogram:Sprite3D
var shown_icon:=""
var previous_bait := -1
var previous_marine := false
var previous_fly := false
var previous_feeder:=false
var feeder_visual:Node3D
func _ready() -> void:
	feeder_visual=load("res://assets/models/rods/cage_feeder.glb").instantiate();add_child(feeder_visual);feeder_visual.hide()
	bait_visual=preload("res://scripts/bait_visual.gd").new();add_child(bait_visual)
	label=Label3D.new();add_child(label)
	label.layers=preload("res://scripts/guide_camera.gd").UI_LAYER
	label.font_size=30;label.pixel_size=.0015;label.outline_size=8
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test=false;label.hide()
	pictogram=Sprite3D.new();add_child(pictogram)
	pictogram.layers=preload("res://scripts/guide_camera.gd").UI_LAYER
	pictogram.billboard=BaseMaterial3D.BILLBOARD_ENABLED;pictogram.pixel_size=.0007
	pictogram.no_depth_test=false;pictogram.hide()
	update_bait()
func update_bait() -> void:
	var marine: bool = game_root.game.is_marine_location(game_root.game.location_id)
	var fly:bool=game_root.game.is_fly_fishing()
	if previous_bait==game_root.game.bait and previous_marine==marine and previous_fly==fly and previous_feeder==game_root.game.is_feeder_fishing():return
	previous_feeder=game_root.game.is_feeder_fishing()
	previous_fly=fly
	previous_marine=marine
	previous_bait=game_root.game.bait
	bait_visual.set_bait(game_root.game.bait_model(),marine,fly)
	label.text=game_root.game.bait_name(previous_bait)
func show_bait() -> void:
	update_bait();label.text=game_root.game.bait_name(game_root.game.bait)
	remaining=2.2;label.show()
func show_notice(icon:String) -> void:
	notice_icon=icon;notice_remaining=1.5
func active_icon()->String:
	if notice_remaining>0:return notice_icon
	var g=game_root.game
	if g.state==g.State.BITE:return "up"
	if g.state==g.State.FIGHT:
		if g.jump_time>0 and g.cue>=0:return ["left","right"][mini(g.cue,1)]
		if g.cue>=0:return ["left","right","up"][g.cue]
		if g.is_running() or g.submerge==g.Submerge.PULL:return "stop"
		if g.submerge==g.Submerge.SLACK:return "reel"
		if g.tension>.8 or g.tension<.12:return "warning"
	return ""
func _process(delta: float) -> void:
	update_bait()
	remaining=maxf(0,remaining-delta)
	notice_remaining=maxf(0,notice_remaining-delta)
	var clear:bool=not game_root.rod_holster.stowed and not game_root.menu_open and not game_root.fish_guide.held
	label.visible=remaining>0 and clear
	var icon:=active_icon()
	pictogram.visible=preload("res://scripts/ui/pictograms.gd").enabled and not icon.is_empty() and clear and not label.visible
	if icon!=shown_icon and not icon.is_empty():
		pictogram.texture=preload("res://scripts/ui/pictograms.gd").texture(icon);shown_icon=icon
	pictogram.global_position=game_root.rod.to_global(Vector3(0,.13,-.62))
	label.global_position=game_root.rod.to_global(Vector3(0,.16,-.78))
