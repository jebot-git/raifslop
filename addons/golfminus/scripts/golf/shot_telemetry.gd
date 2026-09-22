extends Node
## Local, opt-in JSONL. A short swing window is retained only while capture is enabled.
## Poll times describe engine observations, not unique hardware pose timestamps.
signal capture_changed(enabled:bool)
const MAX_BYTES:=8*1024*1024
const MAX_QUEUE:=1024
var enabled:=false
var path:=""
var session_id:=""
var sequence:=0
var bytes_written:=0
var dropped_events:=0
var pending:Dictionary={}
var window:Array[Dictionary]=[]
var swing_segment:Dictionary={}
var queue:Array[Dictionary]=[]
var file:FileAccess
var flush_elapsed:=0.0
func _ready()->void:
	session_id="%s-%d-%d"%[Time.get_datetime_string_from_system(true).replace(":","-"),OS.get_process_id(),Time.get_ticks_usec()]
func start_capture()->bool:
	if enabled:return true
	DirAccess.make_dir_recursive_absolute("user://golf_analytics")
	path="user://golf_analytics/%s-%d.jsonl"%[session_id,Time.get_ticks_usec()]
	file=FileAccess.open(path,FileAccess.WRITE)
	if file==null:return false
	bytes_written=0;dropped_events=0;enabled=true;window.clear()
	record("capture_started",{"schema_version":1,"utc":Time.get_datetime_string_from_system(true),"physics_hz":Engine.physics_ticks_per_second,"pose_clock":"render polling with monotonic elapsed time","pending_shot_id":pending.get("shot_id","")})
	capture_changed.emit(true);return true
func stop_capture(reason:="user")->void:
	if not enabled:return
	end_swing("capture_"+reason)
	record("capture_stopped",{"reason":reason,"dropped_events":dropped_events})
	flush();enabled=false;window.clear()
	if file!=null:file.close();file=null
	capture_changed.emit(false)
func record(kind:String,payload:Dictionary)->void:
	if not enabled:return
	if queue.size()>=MAX_QUEUE:dropped_events+=1;return
	queue.append({"type":kind,"session_id":session_id,"monotonic_us":Time.get_ticks_usec(),"data":serializable(payload)})
func sample_swing(sample:Dictionary)->void:
	if not enabled:return
	window.append(sample.duplicate(true))
	if window.size()>24:window.pop_front()
	var state:String=sample.get("status","")
	if not sample.get("active",false) or state in ["discontinuity","invalid_interval"]:
		end_swing(sample.get("inactive_reason",state));return
	if swing_segment.is_empty():
		swing_segment={"started_us":Time.get_ticks_usec(),"club":sample.get("club",-1),"samples":0,"peak_raw_speed_m_s":0.0,"peak_filtered_speed_m_s":0.0,"nearest_head_ball_m":float(sample.head.distance_to(sample.ball)),"contacts":0,"accepted_contacts":0}
		window.clear();window.append(sample.duplicate(true))
	swing_segment.samples+=1
	swing_segment.peak_raw_speed_m_s=maxf(swing_segment.peak_raw_speed_m_s,Vector3(sample.get("raw_velocity",Vector3.ZERO)).length())
	swing_segment.peak_filtered_speed_m_s=maxf(swing_segment.peak_filtered_speed_m_s,Vector3(sample.get("filtered_velocity",Vector3.ZERO)).length())
	swing_segment.nearest_head_ball_m=minf(swing_segment.nearest_head_ball_m,float(sample.get("contact_distance_m",sample.head.distance_to(sample.ball))))
func end_swing(reason:String)->void:
	if swing_segment.is_empty():return
	swing_segment.end_reason=reason
	swing_segment.elapsed_s=(Time.get_ticks_usec()-int(swing_segment.started_us))/1000000.0
	record("swing_segment_finished",swing_segment);swing_segment.clear()
func contact(payload:Dictionary)->void:
	if not enabled:return
	if not swing_segment.is_empty():
		swing_segment.contacts+=1
		if payload.get("accepted",false):swing_segment.accepted_contacts+=1;swing_segment.shot_id=payload.get("shot_id","")
	var event:=payload.duplicate(true);event["swing_window"]=window.duplicate(true)
	record("contact_attempt",event)
func begin_shot(payload:Dictionary)->String:
	sequence+=1
	var id:="%s/shot-%d"%[session_id,sequence]
	pending=payload.duplicate(true);pending.shot_id=id;pending.started_us=Time.get_ticks_usec()
	record("shot_launched",pending)
	return id
func finish_shot(outcome:Dictionary)->Dictionary:
	if pending.is_empty():return {}
	var result:=pending.duplicate(true);result.merge(outcome,true)
	result.elapsed_s=(Time.get_ticks_usec()-int(pending.started_us))/1000000.0
	record("shot_completed",result);pending.clear();return result
func _process(dt:float)->void:
	if not enabled:return
	flush_elapsed+=dt
	if flush_elapsed>=1.0:
		flush_elapsed=0;flush()
		if bytes_written>=MAX_BYTES:stop_capture("size_limit")
func flush()->void:
	if file==null:return
	for event in queue:
		var line:=JSON.stringify(event)
		file.store_line(line);bytes_written+=line.to_utf8_buffer().size()+1
	queue.clear();file.flush()
func _exit_tree()->void:stop_capture("activity_exit")
static func serializable(value:Variant)->Variant:
	if value is float and not is_finite(value):return null
	if value is Vector3:return serializable([value.x,value.y,value.z])
	if value is Vector2:return serializable([value.x,value.y])
	if value is Basis:return serializable([value.x,value.y,value.z])
	if value is Transform3D:return {"basis":serializable(value.basis),"origin":serializable(value.origin)}
	if value is Dictionary:
		var result:Dictionary={}
		for key in value:result[str(key)]=serializable(value[key])
		return result
	if value is Array:
		var result:Array=[]
		for item in value:result.append(serializable(item))
		return result
	return value
