extends Control
## Shared guide/status state; gameplay uses spatial indicators and the handheld guide.
var calibration_message := ""
var game
var location_mood := "Open water · Bright morning"
var tracking_lost := false

func _ready()->void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE

func _draw()->void:
	if tracking_lost and preload("res://scripts/ui/pictograms.gd").enabled:
		draw_set_transform(Vector2.ZERO,0,size/Vector2(1000,640))
		draw_texture_rect(preload("res://scripts/ui/pictograms.gd").texture("tracking"),Rect2(468,288,64,64),false)
