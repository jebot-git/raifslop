extends SceneTree
const Boundary = preload("res://scripts/fish_water_boundary.gd")
const S = preload("res://scripts/fishing_session.gd")
var failures: Array = []
var checks := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var g = load("res://scenes/main.tscn").instantiate(); root.add_child(g)
	await create_timer(.4).timeout
	g.set_process(false); g.motor.set_physics_process(false); g.fishing_feedback.set_process(false)
	g.xr = true
	g.right.transform = Transform3D(Basis.IDENTITY, Vector3(.3,1.3,-.3))
	g.head.rotation = Vector3(-.15,0,0)
	var target: Vector3 = g._projected_cast_target()
	check(target.is_finite() and target.z < -5, "Head aim projects onto water")
	g.right.rotation = Vector3(.5, .7, .2)
	check(g._projected_cast_target().is_equal_approx(target), "Wrist rotation cannot steer head aim")
	g.head.rotation.y = .25
	check(g._projected_cast_target().distance_to(target)>1, "Head yaw steers marker")
	g._begin_cast(); target = g._projected_cast_target(); g.right.rotation.x += .5
	check(g._projected_cast_target().is_equal_approx(target), "Trigger-down freezes head aim for the swing")
	g.casting = false; g.right.rotation = Vector3.ZERO
	g.avatar_menu.calibration_sliders[6].value = 6
	g.avatar_menu.calibration_sliders[9].value = -5
	g.avatar_menu.calibration_sliders[1].value = -3
	check(g.controller_pose(1).origin.distance_to(g.right.to_global(Vector3(.06,0,0)))<.0001, "Controller translation is local to its tracked grip")
	check(g.controller_calibration.angles[1].x == -5 and is_equal_approx(g.controller_calibration.offsets[0].y,-.03), "Independent controller rotation and offset controls work")
	var saved_pose: Transform3D = g.controller_pose(1)
	g.controller_calibration.offsets[1] = Vector3.ZERO; g.controller_calibration.angles[1] = Vector3.ZERO
	g._load_player_preferences()
	check(g.controller_pose(1).is_equal_approx(saved_pose), "Controller calibration persists across reload")
	check(g.calibrated_hands[1].global_transform.is_equal_approx(saved_pose), "Avatar grip and casting use the same corrected pose")
	g.avatar_menu.calibration_reset.pressed.emit()
	check(g.controller_calibration.pose(0).is_equal_approx(Transform3D.IDENTITY) and g.controller_calibration.pose(1).is_equal_approx(Transform3D.IDENTITY), "Reset restores both controllers")
	var bad := ConfigFile.new(); bad.set_value("controls","left_offset",Vector3(INF,0,0));bad.set_value("controls","right_rotation","bad")
	g.controller_calibration.load_config(bad)
	check(g.controller_calibration.pose(0).is_equal_approx(Transform3D.IDENTITY) and g.controller_calibration.pose(1).is_equal_approx(Transform3D.IDENTITY), "Malformed calibration cannot corrupt tracking")
	g.xr = false
	g.fish_guide.entries.clear(); g.fish_guide.selected = -1; g.fish_guide.page(1)
	var rows: Array = g.fish_guide.ordered_entries()
	check(g.fish_guide.selected == 0 and rows.size() == S.SPECIES.size(), "Empty journal can browse every undiscovered species")
	for row in rows:
		check(row.name == "?" and row.latin == "" and not row.discovered and row.length == 0, "Unknown species hides identity and silhouette key")
		check(not row.habitat.is_empty() and not row.bait.is_empty() and not row.methods.is_empty() and not row.waters.is_empty(), "Unknown species has habitat, bait, methods and actual waters")
	g.fish_guide.ingest([S.SPECIES[28]])
	rows = g.fish_guide.ordered_entries()
	check(rows[28].discovered and rows[28].name == "Dusky kob" and rows[28].habitat == "Sea" and rows[28].bait == "Sardine", "Catch reveals only its original catalogue page")
	check(not rows[27].discovered and not rows[29].discovered and g.fish_guide.entries.size()==1, "Unknown pages do not count as discoveries")
	# Thin pier and large fish: sweep cannot teleport across a blocked footprint.
	var boundary := Boundary.new()
	boundary.add_triangle(PackedVector2Array([Vector2(-2,-.05),Vector2(2,-.05),Vector2(2,.05)]))
	boundary.add_triangle(PackedVector2Array([Vector2(-2,-.05),Vector2(2,.05),Vector2(-2,.05)]))
	var stopped := boundary.clip_motion(Vector3(0,-3,-2),Vector3(0,-3,2),.6)
	check(stopped.z < -.64 and not boundary.blocked(stopped,.6), "Swept whole-body boundary blocks narrow deck even deep underwater")
	check(boundary.blocked(Vector3(0,-100,0),.2), "Boundary holds at every dive depth")
	check(boundary.clip_motion(Vector3(3,0,-2),Vector3(3,0,2),.2).z == 2, "Open-water movement stays free")
	for predator in [false,true]:
		var sim := S.new(); sim.fish_index = S.BRONZE_WHALER if predator else 11; sim.state=S.State.BITE;sim.strike()
		sim.cue=0;sim.submerge=S.Submerge.SLACK;sim.submerge_time=2;sim.jump_time=1
		sim.set_ground_boundary(true)
		check(sim.cue==2 and sim.submerge==S.Submerge.PULL and sim.jump_time==0, "Boundary converts lateral/rush/jump to outward or dive")
		for i in 800:
			sim.tension=.5;sim.stamina=.9;sim.distance=20;sim.failed_counters=0
			sim.gesture(sim.cue);sim.tick(.05,0,0)
			check(sim.cue in [-1,2] and sim.submerge!=S.Submerge.SLACK and sim.jump_time==0, "Only outward counters and deep pulls selected at ground")
		if not predator:
			sim.set_ground_boundary(false);sim.submerge=S.Submerge.NONE;sim.cue=-1;sim.next_cue=0;sim.fight_step=0;sim.counter_rest=0;sim.next_submerge=100;sim.next_jump=100
			sim.tick(.01,0,0)
			check(sim.cue in [0,1], "Ordinary lateral fights resume away from ground")
	# Inspect and exercise each real mesh, including sloping beaches and river rocks.
	for entry in g.Locations.CATALOG:
		g.game.reset();g._select_location(entry.id,false)
		for player in g.find_children("*","AudioStreamPlayer",true,false): player.stop()
		await physics_frame;await physics_frame
		check(not g.fish_boundary.triangles.is_empty(), "Boundary built from actual ground: " + entry.id)
		g.cast_anchor=Vector3(g.rod.global_position.x,g.water_level+.05,g.rod.global_position.z)
		g.cast_target=g.cast_anchor+Vector3.FORWARD*15
		g.game.state=S.State.BITE;g.game.fish_index=11 if g.game.is_fly_fishing() else 28 if S.is_marine_location(entry.id) else 1;g.game.strike()
		g.game.distance=15;g.fish_safe_position=Vector3(INF,INF,INF)
		g._constrain_fish_to_water()
		var radius: float=g._fish_clearance()
		check(not g.fish_boundary.blocked(g.fish_safe_position,radius),"Initial fish fits open water: "+entry.id)
		g.game.distance=0.01;g.game.cue=0
		g._constrain_fish_to_water()
		check(not g.fish_boundary.blocked(g.fish_safe_position,radius) and g.game.at_ground_boundary and g.game.cue==2,"Retrieval cannot put fish beneath ground: "+entry.id)
		var direction: Vector3=(g.cast_target-g.cast_anchor).normalized()
		g.game.landing_distance=g._landing_distance(g.cast_anchor,direction,15)
		check(g.game.distance<=g.game.landing_distance+.05, "Boundary remains reachable for landing: "+entry.id)
		g.game.cue=-1;g.game.stamina=0;g.game.next_cue=100;g.game.next_submerge=100;g.game.phase=0;g.game.tick(.02,1,0)
		check(g.game.state==S.State.LANDED,"Exhausted fish lands at safe mesh edge: "+entry.id)
	if "--capture" in OS.get_cmdline_user_args():
		g.fish_guide.entries.clear();g.fish_guide.selected=28;g.fish_guide.screen.queue_redraw()
		for i in 12:await process_frame
		await RenderingServer.frame_post_draw
		g.fish_guide.viewport.get_texture().get_image().save_png("res://docs/guide_undiscovered.png")
		g.fish_guide.ingest([S.SPECIES[28]])
		for i in 8:await process_frame
		await RenderingServer.frame_post_draw
		g.fish_guide.viewport.get_texture().get_image().save_png("res://docs/guide_discovered.png")
	g.queue_free(); await process_frame; await create_timer(.2).timeout
	print("FISHING_COMFORT_RESULT ",checks," checks: ",failures);quit(0 if failures.is_empty() else 1)
