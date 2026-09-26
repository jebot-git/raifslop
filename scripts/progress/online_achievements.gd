extends Node
## Per-account idempotent unlock outbox, separate EOS and Meta acknowledgements.
const Catalog=preload("res://scripts/progress/achievement_catalog.gd")
var runtime:Node
var backend:Node
var meta:Node
var user:=""
var meta_user:=""
var path:=""
var wanted:Dictionary={}
var eos_done:Dictionary={}
var meta_done:Dictionary={}
var enabled:=false
var busy:=false
var generation:=0
var due:=0
var status:=""
var mirror_cursor:=0
func setup(owner_runtime:Node)->void:runtime=owner_runtime;name="OnlineAchievements"
func eligible()->bool:
	return enabled and is_instance_valid(runtime) and runtime.session.active and runtime.session.get("dedicated")!=true and not runtime.lobby.is_empty() and backend.product_user_id==user
func start(settings:Dictionary,eos_backend:Node,meta_provider:Node)->void:
	var account:String=JSON.stringify([settings.get("product_id",""),settings.get("sandbox_id",""),settings.deployment_id,eos_backend.product_user_id,settings.get("app_id",""),str(meta_provider.get("user_id"))]).sha256_text()
	var file_path:="user://online-achievements/"+account+".json"
	if enabled and file_path==path:return
	stop();wanted.clear();eos_done.clear();meta_done.clear();status=""
	if not settings.get("achievements_enabled",true):return
	backend=eos_backend;meta=meta_provider;user=backend.product_user_id;meta_user=str(meta.get("user_id"));path=file_path
	if FileAccess.file_exists(path):
		var file:=FileAccess.open(path,FileAccess.READ)
		if file==null or file.get_length()>16384:status="Online achievements could not be read.";return
		var data=JSON.parse_string(file.get_as_text())
		if not data is Dictionary or data.get("version")!=1:status="Invalid online achievement outbox.";return
		for key in ["wanted","eos","meta"]:
			if not valid_ids(data.get(key)):status="Invalid online achievement outbox.";return
		wanted=data.wanted;eos_done=data.eos;meta_done=data.meta
	enabled=true;due=0
static func valid_ids(value:Variant)->bool:
	if not value is Dictionary or value.size()>Catalog.ALL.size():return false
	for id in value:
		if not Catalog.ALL.has(id) or value[id]!=true:return false
	return true
func stop()->void:generation+=1;enabled=false
func save()->bool:
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir())!=OK:return false
	var file:=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null:return false
	file.store_string(JSON.stringify({"version":1,"wanted":wanted,"eos":eos_done,"meta":meta_done}));file.flush()
	var code:=file.get_error();file.close()
	return code==OK and DirAccess.rename_absolute(path+".tmp",path)==OK
func earn(id:String)->void:
	if not eligible() or not Catalog.ALL.has(id) or wanted.has(id):return
	wanted[id]=true
	if not save():stop();status="Online achievements could not be saved."
func _process(_delta:float)->void:
	if not eligible() or runtime.busy or runtime.leaderboards.busy or busy or Time.get_ticks_msec()<due:return
	if wanted.keys().all(func(id):return eos_done.has(id) and (not meta.enabled or meta_done.has(id))):return
	await synchronize()
func synchronize()->void:
	if not eligible() or busy or runtime.busy:return
	busy=true;runtime.busy=true
	var current:=generation
	var ids:Array=wanted.keys().filter(func(id):return not eos_done.has(id))
	if not ids.is_empty():
		var answer:Dictionary=await backend._call("achievements_interface_unlock_achievements",{"user_id":user,"achievement_ids":ids})
		if current==generation and answer.get("result_code")==0:
			for id in ids:eos_done[id]=true
	if current==generation and meta.enabled and meta.sdk!=null and str(meta.get("user_id"))==meta_user:
		var viewer:Object=await meta.requests.meta(meta.sdk.user_get_logged_in_user_async())
		if current==generation and viewer!=null and viewer.get_user()!=null and str(viewer.get_user().get_id())==meta_user:
			var attempted:=0
			var keys:Array=Catalog.ALL.keys()
			for _index in keys.size():
				var id:String=keys[mirror_cursor]
				mirror_cursor=(mirror_cursor+1)%keys.size()
				if not wanted.has(id):continue
				if not eos_done.has(id) or meta_done.has(id):continue
				var result:Object=await meta.requests.meta(meta.sdk.achievements_unlock_async(id))
				if current!=generation:break
				if result!=null:meta_done[id]=true
				attempted+=1
				if attempted>=2:break
	if current==generation:
		if not save():stop();status="Online achievements could not be saved."
		else:status="Achievement unlocks synchronized." if wanted.keys().all(func(id):return eos_done.has(id) and (not meta.enabled or meta_done.has(id))) else "Achievement unlocks awaiting synchronization."
	due=Time.get_ticks_msec()+60000;busy=false;runtime.busy=false
