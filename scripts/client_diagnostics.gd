extends Node
## Opt-in aggregate diagnostics; never records microphone audio or player poses.
var previous_usec := 0
var next_usec := 0
var frames: Array[float] = []
var game_root: Node
var last_state := -1
static func enabled() -> bool:
	return "--client-metrics" in OS.get_cmdline_user_args() or "--network-metrics" in OS.get_cmdline_user_args()
static func stage(label: String, started: int, context: Dictionary = {}) -> void:
	if not enabled():return
	var row:=context.duplicate()
	row.merge({"stage":label,"duration_ms":(Time.get_ticks_usec()-started)/1000.0,"ticks_usec":Time.get_ticks_usec()},true)
	print("CLIENT_STAGE ",JSON.stringify(row))
func _ready() -> void:
	set_process(enabled())
	previous_usec=Time.get_ticks_usec();next_usec=previous_usec+2_000_000
func _process(_delta: float) -> void:
	var now:=Time.get_ticks_usec()
	frames.append((now-previous_usec)/1000.0);previous_usec=now
	if is_instance_valid(game_root):
		var g=game_root.game
		if g.state!=last_state:
			print("FISHING_EVENT ",JSON.stringify({"ticks_usec":now,"state":g.state,"previous":last_state,"species":g.fish_index,"bait":g.bait,"water":g.location_id,"reason":g.message}))
			last_state=g.state
	if now<next_usec:return
	next_usec=now+2_000_000
	frames.sort()
	print("CLIENT_METRICS ",JSON.stringify({"ticks_usec":now,"platform":OS.get_name(),"headless":DisplayServer.get_name()=="headless","xr":is_instance_valid(game_root) and game_root.xr,"frames":frames.size(),"wall_frame_p50_ms":frames[int((frames.size()-1)*.5)],"wall_frame_p95_ms":frames[int((frames.size()-1)*.95)],"wall_frame_max_ms":frames.back(),"sampled_process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000.0,"tracked_memory_bytes":Performance.get_monitor(Performance.MEMORY_STATIC)}))
	frames.clear()
