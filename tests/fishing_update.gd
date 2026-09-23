extends SceneTree
const S = preload("res://scripts/fishing_session.gd")
var failures: Array = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures.append(label)

func run() -> void:
	var g = load("res://scenes/main.tscn").instantiate(); root.add_child(g)
	await create_timer(.4).timeout
	g.set_process(false); g.motor.set_physics_process(false); g.fishing_feedback.set_process(false)
	g._select_location("lakeside", false)
	await physics_frame
	for kind in [S.Submerge.PULL, S.Submerge.SLACK]:
		g.game.reset(); g.game.fish_index = 0; g.game.state = S.State.BITE; g.game.strike()
		g.game.distance = 12; g.game.next_cue = 100; g.game.next_submerge = 100
		g.game.submerge = kind; g.game.submerge_time = 2.0; g.game.tension = .5
		g.cast_anchor = Vector3(0, g.water_level + .05, 0); g.cast_target = g.cast_anchor + Vector3(0, 0, -12)
		g._update_line(); g.fishing_feedback._process(.02)
		var material: ShaderMaterial = g.fishing_feedback.water_fx
		if kind == S.Submerge.PULL:
			check(g.bobber.position.y < g.water_level - .12, "Dive visibly sinks the bobber")
			check(not material.get_shader_parameter("directional"), "Dive does not show an inward rush wake")
		else:
			check(g.bobber.position.y > g.water_level, "Rush keeps the bobber on the surface")
			var heading: Vector2 = material.get_shader_parameter("heading")
			check(material.get_shader_parameter("directional") and heading.dot(Vector2(0, 1)) > .99, "Rush waves point toward the angler")
			g.game.tick(.2, 0, 0); g._update_line()
			check(g.game.distance < 12 and g.game.tension < .5, "Rushing fish moves inward and creates slack without reeling")
		if "--capture" in OS.get_cmdline_user_args():
			g.hud.hide(); g.head.rotation.x = -.19
			for i in 8: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://test-results/fishing-update/" + ("dive" if kind == S.Submerge.PULL else "rush") + ".png")
	g.game.reset(); g.game.prepare_population()
	var stocks: Dictionary = g.game.population.waters[g.game.location_id]
	for stock in stocks.values(): stock.abundance = 0.0
	stocks[0].abundance = 1.0; stocks[0].sector = 0
	g.game.select_bait(0); g.fishing_feedback.update_feeding_ripples()
	check(g.fishing_feedback.feeding_surfaces[0].visible and not g.fishing_feedback.feeding_surfaces[1].visible, "Subtle ripples appear only in sectors with bait-responsive fish")
	stocks[0].sector = 2; g.fishing_feedback.update_feeding_ripples()
	check(not g.fishing_feedback.feeding_surfaces[0].visible and g.fishing_feedback.feeding_surfaces[2].visible, "Ripple moves with the shoal")
	g.game.state=S.State.WAITING
	g.fish_guide.held=true
	var feeding_mat: ShaderMaterial=g.fishing_feedback.feeding_surfaces[2].material_override
	var phase: float=feeding_mat.get_shader_parameter("clock")
	var fight_clock: float=g.fishing_feedback.clock
	g.fishing_feedback._process(.2)
	check(g.fishing_feedback.feeding_surfaces[2].visible and not is_equal_approx(phase,feeding_mat.get_shader_parameter("clock")),"Presence ripples keep animating with a cast line and the Guide held")
	check(is_equal_approx(fight_clock,g.fishing_feedback.clock) and not g.fishing_feedback.reel_player.playing,"Guide still pauses active fishing feedback")
	g.fish_guide.held=false
	g.game.state=S.State.READY
	g.game.select_bait(2); g.fishing_feedback.update_feeding_ripples()
	check(g.fishing_feedback.feeding_surfaces.all(func(mesh): return not mesh.visible), "Changing bait removes unrelated feeding signals")
	if "--capture" in OS.get_cmdline_user_args():
		g.game.select_bait(0); stocks[0].sector = 1; g.fishing_feedback.feeding_clock = .5 - 1.7 + 4.5; g.fishing_feedback._process(.02)
		g._update_line(); g.head.rotation.x = -.15
		for i in 8: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://test-results/fishing-update/feeding.png")
	g.queue_free(); await process_frame; await create_timer(.3).timeout
	print("FISHING_UPDATE_RESULT ", failures); quit(0 if failures.is_empty() else 1)
