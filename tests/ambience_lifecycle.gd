extends SceneTree
const Ambience=preload("res://scripts/ambience.gd")
const Locations=preload("res://scripts/locations.gd")
const CourseLife=preload("res://addons/golfminus/scripts/golf/course_life.gd")
class Motor extends Node3D:
	var safe_spawn:=Vector3.ZERO
class Host extends Node3D:
	var current_location:="lake_pier"
	var motor:=Motor.new()
var failures:Array=[]
func check(ok:bool,label:String)->void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize()->void:run.call_deferred()
func run()->void:
	var host:=Host.new();root.add_child(host);host.add_child(host.motor)
	var ambience:=Ambience.new();host.add_child(ambience);ambience.setup(host)
	ambience.set_muted(false);ambience.set_volume(.65)
	await create_timer(2.2).timeout
	check(ambience.voices.lake_pier.player.playing and ambience.voices.lake_pier.player.volume_db>-10,"Water ambience fades up using actual scene processing")
	for cycle in 3:
		ambience.stop();await process_frame
		check(not ambience.is_processing() and ambience.voices.is_empty(),"Golf suspension stops and releases water beds %d"%cycle)
		check(ambience.get_children().filter(func(n):return n is AudioStreamPlayer).is_empty(),"Suspension does not leak silent audio players %d"%cycle)
		ambience.select_location("lake_pier")
		await create_timer(2.2).timeout
		check(ambience.is_processing() and ambience.voices.lake_pier.player.playing and ambience.voices.lake_pier.player.volume_db>-10,"Same-water return becomes audible without manually ticking the mixer %d"%cycle)
		check(ambience.detail.stream!=null,"Timber detail restored after golf %d"%cycle)
	ambience.set_muted(true);ambience.stop();ambience.select_location("lake_pier")
	await create_timer(.1).timeout
	check(ambience.muted and ambience.voices.lake_pier.player.volume_db<=-79,"Returning to water preserves intentional mute")
	ambience.set_muted(false);await create_timer(2.2).timeout
	check(ambience.voices.lake_pier.player.volume_db>-10,"Unmuting resumed ambience becomes audible")
	var player:AudioStreamPlayer=ambience.voices.lake_pier.player
	player.stop();ambience.select_location("lake_pier");await process_frame
	check(player.playing,"Reselecting the same water restarts an interrupted player")
	var paths:Dictionary={}
	for entry in Locations.CATALOG:
		ambience.select_location(entry.id);ambience._process(2.1)
		var stream:AudioStreamOggVorbis=ambience.voices[entry.id].player.stream
		var path:="res://assets/audio/ambience/%s.ogg"%entry.id
		paths[path]=Locations.water_type(entry.id)
		check(stream!=null and stream.loop and stream.get_length()>29,"Water has its own looping bed: %s / %s"%[Locations.water_type(entry.id),entry.id])
	for course in ["spyglass","pebble","cypress","poppy"]:
		var path:=CourseLife.soundscape_path(course)
		var stream:=load(path) as AudioStreamOggVorbis
		check(not paths.has(path) and stream!=null and stream.get_length()>127,"Golf never borrows a fishing-water bed: "+course)
	check(CourseLife.soundscape_path("pebble")!=CourseLife.soundscape_path("poppy"),"Open coastal courses differ from woodland courses")
	ambience.stop();host.queue_free();await process_frame
	print("AMBIENCE_LIFECYCLE_RESULT ",failures);quit(0 if failures.is_empty() else 1)
