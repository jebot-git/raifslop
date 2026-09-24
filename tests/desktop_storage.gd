extends Node
const Paths=preload("res://scripts/data_paths.gd")
var failures:Array[String]=[]
func check(ok:bool,label:String)->void:
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func _ready()->void:
 var args:=OS.get_cmdline_user_args()
 if args.has("--missing-xr"):
  var refused:=not preload("res://scripts/xr_startup.gd").require_session(self)
  print("XR_STARTUP_GUARD_RESULT ",refused and process_mode==Node.PROCESS_MODE_DISABLED)
  return
 var expected:=ProjectSettings.globalize_path("user://data")
 if args.has("--asset-root"):expected=args[args.find("--asset-root")+1]
 check(Paths.root()==expected,"Released desktop uses writable user storage or explicit override")
 var destination:=Paths.folder("vrm")
 check(DirAccess.make_dir_recursive_absolute(destination)==OK,"Cache can be created outside read-only install")
 var existing:=destination.path_join("same.vrm")
 var file:=FileAccess.open(existing,FileAccess.WRITE);file.store_string("existing user avatar");file.close()
 var legacy:=OS.get_executable_path().get_base_dir().path_join("data/vrm")
 var old:=legacy.path_join("same.vrm")
 var migrated:=Paths.migrate_vrms(destination)
 check(FileAccess.get_file_as_string(existing)=="existing user avatar","Migration never overwrites a conflicting user avatar")
 check(migrated.has(old) and migrated[old]!=existing,"Conflicting legacy selection receives a distinct destination")
 if migrated.has(old):check(FileAccess.get_sha256(old)==FileAccess.get_sha256(migrated[old]),"Selected legacy avatar bytes preserved")
 check(migrated.has(legacy.path_join("unique.vrm")),"Legacy install-folder avatar copied")
 check(not FileAccess.file_exists(destination.path_join("ignore.txt")),"Unrelated legacy files excluded")
 var repeated:=Paths.migrate_vrms(destination)
 check(migrated==repeated,"Migration is idempotent and selection mapping stays stable")
 check(FileAccess.get_file_as_string(old)=="legacy selected avatar","Read-only original retained")
 print("DESKTOP_STORAGE_RESULT ",failures)
 get_tree().quit(0 if failures.is_empty() else 1)
