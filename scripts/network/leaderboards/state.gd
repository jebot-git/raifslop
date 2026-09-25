extends RefCounted
## Bounded, atomic per-account outbox. MIN/MAX retries survive ambiguous acknowledgements.
const Catalog=preload("res://scripts/network/leaderboards/catalog.gd")
var targets:Dictionary={}
var confirmed:Dictionary={}
var mirrored:Dictionary={}
var path:=""
var scope:=""
var error:=""
func open(file_path:String,account_scope:String)->void:
 path=file_path;scope=account_scope;targets.clear();confirmed.clear();mirrored.clear();error=""
 if not FileAccess.file_exists(path):return
 var file:=FileAccess.open(path,FileAccess.READ)
 if file==null or file.get_length()>16384:error="Online leaderboard outbox could not be read.";return
 var parser:=JSON.new()
 if parser.parse(file.get_as_text())!=OK:error="Online leaderboard outbox is invalid.";return
 var data=parser.data
 if not data is Dictionary or data.get("version")!=1 or data.get("scope")!=scope or not valid_scores(data.get("targets")) or not valid_scores(data.get("confirmed")):
  error="Online leaderboard outbox is invalid or belongs to another account.";return
 targets=data.targets;confirmed=data.confirmed
 # Reconcile Meta again on each login; an acknowledgement is not proof it still exists.
static func valid_scores(values:Variant)->bool:
 if not values is Dictionary or values.size()>Catalog.boards().size():return false
 for key in values:
  if not Catalog.boards().has(key) or not Catalog.valid_score(values[key]):return false
 return true
func offer(key:String,score:int)->bool:
 if not error.is_empty() or not Catalog.boards().has(key) or not Catalog.valid_score(score):return false
 if not Catalog.better(key,score,int(targets.get(key,0))):return false
 targets[key]=score;return true
func pending()->Dictionary:
 var result:Dictionary={}
 for key in targets:
  if Catalog.better(key,int(targets[key]),int(confirmed.get(key,0))):result[key]=int(targets[key])
 return result
func observe(values:Dictionary)->void:
 for key in values:
  if Catalog.boards().has(key) and Catalog.valid_score(values[key]) and Catalog.better(key,int(values[key]),int(confirmed.get(key,0))):confirmed[key]=int(values[key])
func mirror_jobs(values:Dictionary)->Dictionary:
 var result:Dictionary={}
 for key in values:
  if Catalog.boards().has(key) and Catalog.valid_score(values[key]) and int(mirrored.get(key,0))!=int(values[key]):result[key]=int(values[key])
 return result
func save()->Error:
 if not error.is_empty():return ERR_FILE_CORRUPT
 var code:=DirAccess.make_dir_recursive_absolute(path.get_base_dir())
 if code!=OK:return code
 var file:=FileAccess.open(path+".tmp",FileAccess.WRITE)
 if file==null:return FileAccess.get_open_error()
 file.store_string(JSON.stringify({"version":1,"scope":scope,"targets":targets,"confirmed":confirmed}));file.flush()
 code=file.get_error();file.close()
 if code==OK:code=DirAccess.rename_absolute(path+".tmp",path)
 return code
