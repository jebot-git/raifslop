extends SceneTree
const Destinations=preload("res://scripts/progress/destinations.gd")
class Intent extends RefCounted:
	var destination:="water_meadow_bend"
	var lobby:=""
	func get_destination_api_name()->String:return destination
	func get_lobby_session_id()->String:return lobby
class Activity extends Node:
	var active:=false
	var member:=false
	var golf:Dictionary={"course_id":""}
	func enrolled()->bool:return member
	func leave()->void:active=false
	func enter(id:String)->void:active=true;golf.course_id=id
class Host extends Node:
	var casting:=false
	var avatar_loading:=false
	var game:Dictionary={"state":0}
	var golf_activity=Activity.new()
	var selected:=""
	func _select_location(id:String)->bool:
		selected=id;golf_activity.leave();return true
func _initialize()->void:run.call_deferred()
func run()->void:
	var host=Host.new();root.add_child(host);host.add_child(host.golf_activity)
	var router=Destinations.new();root.add_child(router);router.setup(host);router.set_process(false)
	var intent=Intent.new()
	router.read_intent(intent)
	assert(router.pending==intent.destination and host.selected.is_empty())
	host.casting=true;await router.travel()
	assert(host.selected.is_empty() and not router.pending.is_empty())
	host.casting=false;await router.travel()
	assert(host.selected=="meadow_bend" and router.pending.is_empty())
	intent.destination="course_spyglass";router.read_intent(intent);await router.travel()
	assert(host.golf_activity.active and host.golf_activity.golf.course_id=="spyglass")
	host.golf_activity.member=true;intent.destination="water_lakeside";router.read_intent(intent);await router.travel()
	assert(router.pending=="water_lakeside" and host.golf_activity.active)
	host.golf_activity.member=false;await router.travel()
	assert(host.selected=="lakeside" and not host.golf_activity.active)
	intent.destination="unknown";router.read_intent(intent,true);await process_frame
	assert(router.pending.is_empty())
	intent.destination="water_cedar_creek";intent.lobby="invited-lobby";router.read_intent(intent,true);await process_frame
	assert(host.selected=="lakeside" and router.pending=="water_cedar_creek")
	intent.lobby="";router.read_intent(intent,true);await process_frame
	assert(host.selected=="cedar_creek" and router.pending.is_empty())
	router.free();host.free()
	print("DESTINATIONS_RESULT warm/cold travel, busy guards and lobby consent passed")
	quit()
