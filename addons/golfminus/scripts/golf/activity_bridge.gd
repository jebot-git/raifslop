extends Node
## Host-owned services stay outside golf. Bind existing Real AI Fishing services here.
signal activity_started(id: String)
signal shot_recorded(payload: Dictionary)
signal shot_completed(payload: Dictionary)
signal hole_completed(payload: Dictionary)
signal activity_finished(payload: Dictionary)
var services: Dictionary = {}
func configure(host_services: Dictionary) -> void:
	services=host_services
func wind(fallback: Vector3) -> Vector3:
	var weather=services.get("weather")
	if is_instance_valid(weather) and weather.has_method("get_wind_velocity"):
		var v=weather.get_wind_velocity()
		if v is Vector3 and v.is_finite():return v
	return fallback
func record_shot(payload: Dictionary) -> void:
	shot_recorded.emit(payload)
	var analytics=services.get("activities")
	if is_instance_valid(analytics) and analytics.has_method("record_activity_event"):
		analytics.record_activity_event("golf_shot",payload)

func record_shot_outcome(payload:Dictionary)->void:
	shot_completed.emit(payload)
	var analytics=services.get("activities")
	if is_instance_valid(analytics) and analytics.has_method("record_activity_event"):
		analytics.record_activity_event("golf_shot_outcome",payload)
