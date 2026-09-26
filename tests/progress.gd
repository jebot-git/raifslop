extends SceneTree
const Progress=preload("res://scripts/progress/service.gd")
const Places=preload("res://scripts/progress/destination_catalog.gd")
const Sync=preload("res://scripts/progress/online_achievements.gd")
var failures:Array=[]
func check(ok:bool,label:String)->void:
	if not ok:failures.append(label);push_error(label)
class Session extends Node:
	var active:=true
	var dedicated:=false
class Runtime extends Node:
	var session=Session.new()
	var lobby:="test-lobby"
	var busy:=false
class Backend extends Node:
	var product_user_id:="test-user"
	var calls:Array=[]
	var success:=false
	var hold:=false
	signal release
	func _call(method:String,options:Dictionary)->Dictionary:
		calls.append([method,options])
		if hold:await release
		return {"result_code":0 if success else 5}
class Meta extends Node:
	var enabled:=false
	var user_id:=""
	var sdk:Object
func _initialize()->void:run.call_deferred()
func run()->void:
	var progress:=Progress.new();root.add_child(progress);progress.path="user://test-achievements.json"
	DirAccess.remove_absolute(progress.path);progress.setup(null)
	for i in 10:progress.caught({"length":20,"rarity":1},20)
	check(progress.unlocked.has("ubs_first_catch") and progress.unlocked.has("ubs_ten_catches"),"Fishing milestones")
	check(not progress.unlocked.has("ubs_exceptional_catch"),"Ordinary catch is not exceptional")
	progress.caught({"length":20,"rarity":4},20)
	check(progress.unlocked.has("ubs_exceptional_catch"),"Rare predator uses dedicated-server exceptional rule")
	progress.visit("lakeside");progress.visit("lakeside");progress.visit("meadow_bend");progress.visit("golf_spyglass_clubhouse")
	check(progress.visits.size()==3 and progress.unlocked.has("ubs_explorer"),"Distinct playable destinations unlock explorer")
	var scores:Array=[]
	for i in 18:scores.append(4)
	progress.golf("spyglass",scores,true,[0])
	check(not progress.unlocked.has("ubs_first_round"),"Forfeit cannot unlock clean completed round")
	progress.golf("spyglass",scores,true)
	check(progress.unlocked.has("ubs_first_round") and progress.unlocked.has("ubs_birdie"),"Golf milestones from completed holes")
	var restored:=Progress.new();root.add_child(restored);restored.path=progress.path;restored.setup(null)
	check(restored.error.is_empty() and restored.unlocked==progress.unlocked and restored.catches==11,"Achievements survive restart")
	check(Places.all().size()==Places.Waters.CATALOG.size()+Places.Courses.ACTIVE.size(),"Every playable water and course has a destination")
	check(Places.for_location("golf_spyglass_hole_03")=="course_spyglass" and Places.for_location("../../bad").is_empty(),"Destination routing is allowlisted")
	var portal=JSON.parse_string(FileAccess.get_file_as_string("res://docs/DESTINATIONS.example.json"))
	check(portal.destinations.size()==Places.all().size(),"Provisioning catalog covers every destination")
	for entry in portal.destinations:check(Places.all().has(entry.api_name),"Provisioned destination exists")
	var runtime:=Runtime.new();root.add_child(runtime);runtime.add_child(runtime.session)
	var backend:=Backend.new();runtime.add_child(backend)
	var meta:=Meta.new();runtime.add_child(meta)
	var sync:=Sync.new();runtime.add_child(sync);sync.setup(runtime);sync.set_process(false)
	var config:Dictionary={"product_id":"fixture","deployment_id":"fixture-progress","app_id":""}
	var account:=JSON.stringify(["fixture","","fixture-progress","test-user","",""]).sha256_text()
	DirAccess.remove_absolute("user://online-achievements/"+account+".json")
	sync.start(config,backend,meta);sync.earn("ubs_first_catch");sync.earn("ubs_first_catch")
	check(sync.wanted.size()==1,"Duplicate unlocks collapse in account outbox")
	await sync.synchronize();check(sync.eos_done.is_empty(),"Denied EOS unlock stays pending")
	backend.success=true;await sync.synchronize()
	check(sync.eos_done.has("ubs_first_catch") and backend.calls.back()[1]=={"user_id":"test-user","achievement_ids":["ubs_first_catch"]},"Native EOS unlock targets only authenticated user")
	sync.earn("ubs_ten_catches");backend.hold=true;sync.synchronize();await process_frame
	sync.stop();backend.release.emit();await process_frame
	check(not sync.eos_done.has("ubs_ten_catches") and not sync.busy and not runtime.busy,"Late unlock acknowledgement cannot affect stopped account")
	progress.free();restored.free();runtime.free()
	print("PROGRESS_RESULT ",failures);quit(0 if failures.is_empty() else 1)
