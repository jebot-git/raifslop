extends RefCounted
signal changed
var hole := 0
var strokes := 0
var scores: Array[int] = []
var finished := false
var last_safe := Vector3.ZERO
var penalties := 0
var progress_path := "user://golf_round.cfg"
func start() -> void:
	hole=0;strokes=0;scores.clear();finished=false;penalties=0;changed.emit()
func shot(p: Vector3) -> void:
	last_safe=p;strokes+=1;changed.emit()
func penalty() -> Vector3:
	strokes+=1;penalties+=1;changed.emit();return last_safe
func complete_hole() -> void:
	if scores.size()==hole: scores.append(strokes)
	finished=scores.size()==18
	changed.emit()
func advance() -> bool:
	if scores.size()!=hole+1 or finished: return false
	hole+=1;strokes=0;changed.emit();return true
func total() -> int:
	var n:=0
	for s in scores:n+=maxi(0,s)
	return n
func save_result(course_id: String) -> Error:
	var cfg:=ConfigFile.new()
	cfg.load("user://golf_records.cfg")
	cfg.set_value(course_id,"last_scores",scores)
	cfg.set_value(course_id,"last_completed",Time.get_datetime_string_from_system())
	if finished and not scores.has(-1):
		cfg.set_value(course_id,"best",mini(total(),int(cfg.get_value(course_id,"best",999))))
	return cfg.save("user://golf_records.cfg")
func save_progress(course_id: String,tee: String,ball: RefCounted) -> Error:
	var cfg:=ConfigFile.new()
	cfg.set_value("round","course",course_id);cfg.set_value("round","tee",tee)
	cfg.set_value("round","hole",hole);cfg.set_value("round","strokes",strokes);cfg.set_value("round","scores",scores)
	cfg.set_value("round","last_safe",last_safe);cfg.set_value("round","penalties",penalties);cfg.set_value("round","finished",finished)
	for key in ["position","velocity","spin","origin","moving","holed","hazard","grounded","carry","peak","air_time","rest_time"]:cfg.set_value("ball",key,ball.get(key))
	return cfg.save(progress_path)
func read_progress() -> ConfigFile:
	var cfg:=ConfigFile.new()
	if cfg.load(progress_path)!=OK:return null
	if not cfg.get_value("round","course","") in ["spyglass","pebble","dalkey","alpine"]:return null
	var hs=cfg.get_value("round","hole",-1)
	var ss=cfg.get_value("round","scores",[])
	if not hs is int or hs<0 or hs>17 or not ss is Array or (ss.size()!=hs and ss.size()!=hs+1):return null
	for score in ss:
		if not score is int or score < -1 or score>100:return null
	for key in ["strokes","penalties"]:
		var value=cfg.get_value("round",key,0)
		if not value is int or value<0 or value>100:return null
	if not cfg.get_value("round","tee","") in ["club","forward","back"]:return null
	var safe=cfg.get_value("round","last_safe",null)
	if not safe is Vector3 or not safe.is_finite():return null
	for key in ["moving","holed","hazard","grounded"]:
		if not cfg.get_value("ball",key,null) is bool:return null
	for key in ["carry","peak","air_time","rest_time"]:
		var value=cfg.get_value("ball",key,null)
		if not (value is float or value is int) or not is_finite(float(value)):return null
	for key in ["position","velocity","spin","origin"]:
		var v=cfg.get_value("ball",key,null)
		if not v is Vector3 or not v.is_finite():return null
	return cfg
func restore(cfg: ConfigFile,ball: RefCounted) -> void:
	hole=cfg.get_value("round","hole");strokes=clampi(cfg.get_value("round","strokes",0),0,100)
	scores.assign(cfg.get_value("round","scores",[]));last_safe=cfg.get_value("round","last_safe",Vector3.ZERO)
	penalties=cfg.get_value("round","penalties",0);finished=cfg.get_value("round","finished",false)
	for key in cfg.get_section_keys("ball"):
		if key in ["position","velocity","spin","origin","moving","holed","hazard","grounded","carry","peak","air_time","rest_time"]:ball.set(key,cfg.get_value("ball",key))
	changed.emit()
