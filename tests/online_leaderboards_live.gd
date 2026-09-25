extends SceneTree
## Explicit desktop SDK probe. Authenticates a test device, but never submits scores.
const Backend=preload("res://scripts/network/eos/eos_backend.gd")
const Meta=preload("res://scripts/network/eos/meta_provider.gd")
const Providers=preload("res://scripts/network/leaderboards/providers.gd")
var backend:Node
var meta:Node
func arg(key:String)->String:
 var args:=OS.get_cmdline_user_args();var i:=args.find(key)
 return args[i+1] if i>=0 and i+1<args.size() else ""
func _initialize()->void:run.call_deferred()
func run()->void:
 if not "--eos-device-test" in OS.get_cmdline_user_args() or arg("--eos-config").is_empty() or arg("--result").is_empty():
  push_error("Pass --eos-device-test --eos-config <local file> --result <report file>.");quit(2);return
 var config:Dictionary=Backend.Config.read(arg("--eos-config"))
 config.provider="device"
 var error:String=Backend.Config.validate(config)
 if not error.is_empty():await finish(false,"configuration");return
 backend=Backend.new();meta=Meta.new();root.add_child(backend);root.add_child(meta)
 error=backend.initialize(config)
 if not error.is_empty():await finish(false,"initialize");return
 error=await backend.login({"type":10})
 if not error.is_empty():await finish(false,"login");return
 var providers=Providers.new();providers.bind(backend,meta)
 if not await providers.verify_definitions():await finish(false,"definitions");return
 var scores:Dictionary=await providers.read_scores()
 if scores.has("error"):await finish(false,"stats_query");return
 var page:Dictionary=await providers.page("heaviest",0)
 if page.has("error"):await finish(false,"rank_query");return
 await finish(true,"definitions_stats_and_ranks",{"definitions":Providers.Catalog.boards().size(),"start_time":Providers.Catalog.START_TIME,"personal_stat_count":scores.scores.size(),"rank_rows":page.rows.size()})
func finish(ok:bool,stage:String,details:Dictionary={})->void:
 var report:Dictionary={"ok":ok,"stage":stage,"score_writes":false,"meta_calls":false}
 report.merge(details)
 var file:=FileAccess.open(arg("--result"),FileAccess.WRITE)
 if file!=null:file.store_string(JSON.stringify(report,"  "));file.close()
 if is_instance_valid(backend):backend.queue_free()
 if is_instance_valid(meta):meta.queue_free()
 await process_frame
 print("ONLINE_LEADERBOARDS_LIVE_RESULT ",JSON.stringify(report));quit(0 if ok else 1)
