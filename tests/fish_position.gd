extends SceneTree
const S=preload("res://scripts/fishing_session.gd")
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func run():
	var g=load("res://scenes/main.tscn").instantiate();root.add_child(g)
	await create_timer(.3).timeout
	g.set_process(false);g.motor.set_physics_process(false)
	for cue in [0,1,2]:
		for success in [true,false]:
			g.game.reset();g.game.state=S.State.BITE;g.game.strike()
			g.game.distance=12;g.game.cue=cue;g.game.cue_time=S.COUNTER_WINDOW;g.game.resistance=.001
			g.cast_anchor=Vector3(8,-.3,5);g.cast_target=g.cast_anchor+Vector3(0,0,-12)
			g.escape_offset=g.fish_escape_direction()*1.1;g._update_line()
			var endpoint: Vector3=g.bobber.global_position
			if success:g.game.gesture(cue)
			else:g.game.cue_time=.001
			g.game.tick(.02,0,0);g._settle_fish_escape();g._update_line()
			check(g.game.cue==-1 and g.bobber.global_position.distance_to(endpoint)<.0001,"Counter keeps final fish position: cue %d, success %s"%[cue,success])
			check(g.escape_offset==Vector3.ZERO and absf(g.game.distance-(endpoint-Vector3(0,.02,0)-g.cast_anchor).length())<.0001,"New baseline carries actual line distance")
			for frame in 20:g.game.tick(.01,0,0);g._settle_fish_escape();g._update_line()
			check(g.bobber.global_position.distance_to(endpoint)<.0001,"Fish does not drift back after counter")
			g.game.tension=.5;g.game.tick(.1,.5,0);g._update_line()
			var after_reel: Vector3=g.bobber.global_position
			var expected: Vector3=(g.cast_anchor-(endpoint-Vector3(0,.02,0))).normalized()
			check(after_reel.distance_to(endpoint)>0 and (after_reel-endpoint).normalized().dot(expected)>.999,"Reeling follows the new fish-to-angler direction")
			g.game.cue=2;g._settle_fish_escape();g._update_line()
			check(g.bobber.global_position.distance_to(after_reel)<.0001,"Next counter begins at retained position")
	g.game.reset();g.game.state=S.State.BITE;g.game.strike();g.game.distance=12
	g.cast_anchor=Vector3.ZERO;g.cast_target=Vector3(0,0,-12)
	for counter in 2:
		g.game.cue=-1;g.escape_offset=Vector3.RIGHT*1.1;g._settle_fish_escape()
	g._update_line()
	check(absf(g.bobber.position.x-2.2)<.001,"Consecutive sideways runs accumulate instead of replacing earlier movement")
	g.queue_free();await process_frame;await create_timer(.3).timeout
	print("FISH_POSITION_RESULT ",failures);quit(0 if failures.is_empty() else 1)
