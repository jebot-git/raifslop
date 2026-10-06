extends SceneTree
const Destinations=preload("res://scripts/progress/destinations.gd")
class Intent extends RefCounted:
	var destination:="water_meadow_bend"
	var lobby:=""
	func get_destination_api_name()->String:return destination
	func get_lobby_session_id()->String:return lobby
class Host extends Node:
	var casting:=false
	var avatar_loading:=false
	var game:Dictionary={"state":0}
	var selected:=""
	func _select_location(id:String)->bool:
		selected=id;return true
func _initialize()->void:run.call_deferred()
func run()->void:
	var host=Host.new();root.add_child(host)
	var router=Destinations.new();root.add_child(router);router.setup(host);router.set_process(false)
	var intent=Intent.new()
	router.read_intent(intent)
	assert(router.pending==intent.destination and host.selected.is_empty())
	host.casting=true;await router.travel()
	assert(host.selected.is_empty() and not router.pending.is_empty())
	host.casting=false;await router.travel()
	assert(host.selected=="meadow_bend" and router.pending.is_empty())
	intent.destination="course_lake_pier";router.read_intent(intent);await router.travel()
	assert(host.selected=="meadow_bend" and router.pending.is_empty())
	intent.destination="water_lakeside";router.read_intent(intent);await router.travel()
	intent.destination="unknown";router.read_intent(intent,true);await process_frame
	assert(router.pending.is_empty())
	intent.destination="water_cedar_creek";intent.lobby="invited-lobby";router.read_intent(intent,true);await process_frame
	assert(host.selected=="lakeside" and router.pending=="water_cedar_creek")
	intent.lobby="";router.read_intent(intent,true);await process_frame
	assert(host.selected=="cedar_creek" and router.pending.is_empty())
	router.free();host.free()
	print("DESTINATIONS_RESULT warm/cold travel, busy guards and lobby consent passed")
	quit()
