extends SceneTree
const Provider=preload("res://scripts/network/eos/meta_provider.gd")
const Config=preload("res://scripts/network/eos/config.gd")
class Intent extends RefCounted:
 var destination:="eos_game"
 var message:=""
 var lobby:=""
 func get_destination_api_name()->String:return destination
 func get_deeplink_message()->String:return message
 func get_lobby_session_id()->String:return lobby
func _initialize()->void:
 var provider=Provider.new();provider.destination="eos_game";provider.settings={"deployment_id":"test"}
 var received:Array=[];provider.join_requested.connect(func(value:String):received.append(value))
 var intent=Intent.new();intent.lobby="existing-lobby"
 provider._read_intent(intent)
 assert(received.size()==1 and Config.parse_reference(provider.settings,received[0])=="existing-lobby")
 intent.message=Config.join_reference(provider.settings,"other-lobby");provider._read_intent(intent)
 assert(received.size()==2 and Config.parse_reference(provider.settings,received[1])=="other-lobby")
 intent.destination="other_destination";provider._read_intent(intent)
 assert(received.size()==2)
 intent.destination="eos_game";intent.message="";intent.lobby="";provider._read_intent(intent)
 assert(received.size()==2) # Destination-only links do not invent a lobby target.
 intent.destination="water_meadow_bend";intent.lobby="river-lobby";provider._read_intent(intent)
 assert(received.size()==3 and Config.parse_reference(provider.settings,received[2])=="river-lobby")
 intent.destination="course_spyglass";intent.lobby="course-lobby";provider._read_intent(intent)
 assert(received.size()==4 and Config.parse_reference(provider.settings,received[3])=="course-lobby")
 provider.requests.free();provider.free()
 print("META_LOBBY_INVITES_RESULT intent routing passed; no live Meta calls")
 quit()
