extends SceneTree
## Synthetic dual-view workload. Host GPU timings are NOT XR2 predictions.
const Fish = preload("res://scripts/fishing_session.gd")
var eyes: Array[SubViewport] = []
var cameras: Array[Camera3D] = []
var rows: Array = []
var output := "res://test-results/stereo-gpu.json"
var reverse_order := false
var ablation := false
var bank_only := false
var shading_review := false
var review_location := ""

func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--gpu-output="): output = arg.trim_prefix("--gpu-output=")
		if arg == "--reverse-order": reverse_order = true
		if arg == "--ablation": ablation = true
		if arg == "--bank-only": ablation = true; bank_only = true
		if arg == "--shading-review": shading_review = true
		if arg.begins_with("--review-location="): review_location = arg.trim_prefix("--review-location=")
	run.call_deferred()

func freeze(node: Node):
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D: node.stop()
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children(): freeze(child)

func percentile(values: Array, fraction: float) -> float:
	var ordered := values.duplicate()
	ordered.sort()
	return ordered[clampi(ceili(ordered.size() * fraction) - 1, 0, ordered.size() - 1)]

func save_report():
	var report := {
		"scope": "Synthetic static game scenery, two independent perspective views on the named host GPU. NOT an XR2 emulator or Quest FPS measurement. No OpenXR multiview, compositor, foveation, thermal model, gameplay or remote avatars.",
		"gpu": RenderingServer.get_video_adapter_name(),
		"cpu": OS.get_processor_name(),
		"utc": Time.get_datetime_string_from_system(true),
		"driver": RenderingServer.get_current_rendering_driver_name(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"engine": Engine.get_version_info().string,
		"target_frame_ms": 1000.0 / 72.0,
		"msaa": "disabled (project default)",
		"view_setup": "90 degree vertical FOV, 64 mm eye separation, fixed 12 degree downward pitch, location spawn, no dynamic resolution",
		"warmup_frames": 36, "sample_frames": 90,
		"reverse_order": reverse_order,
		"ablation": ablation,
		"water_animation_frozen": shading_review,
		"user_flags": OS.get_cmdline_user_args(),
		"ablation_notes": "Flat water retains vertex displacement and transparent ALPHA output but removes fragment shading/depth reads. Flat foreground replaces MeshInstance3D materials only; instanced foliage/stones remain, and material cutouts may change. Flat sky changes background only, preserving sky ambient. No sharpening affects sky and water only. Deltas are not additive pass timings.",
		"gpu_measurement": "Sum of two viewport GPU timestamp durations; excludes window/compositor and is not total headset frame time.",
		"samples": rows,
	}
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))

func run():
	if DisplayServer.get_name() == "headless" or RenderingServer.get_current_rendering_method() != "mobile":
		push_error("Requires a real display and the Mobile renderer")
		quit(1)
		return
	var adapter := RenderingServer.get_video_adapter_name().to_lower()
	if "llvmpipe" in adapter or "lavapipe" in adapter or "swiftshader" in adapter:
		push_error("Software rendering cannot supply hardware GPU benchmark results")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	await process_frame
	await physics_frame
	freeze(g)
	if shading_review:
		var still_water: Shader = g.water_material.shader.duplicate()
		still_water.code = still_water.code.replace("TIME", "0.0")
		g.water_material.shader = still_water
	g.hud.hide(); g.rod.hide(); g.avatar.hide(); g.fish_guide.hide()
	root.disable_3d = true
	for side in [-1.0, 1.0]:
		var eye := SubViewport.new()
		eye.world_3d = g.get_world_3d()
		eye.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(eye)
		var camera := Camera3D.new()
		eye.add_child(camera)
		camera.fov = 90.0
		camera.current = true
		eyes.append(eye); cameras.append(camera)
		RenderingServer.viewport_set_measure_render_time(eye.get_viewport_rid(), true)
	var locations := ["lakeside", "simons_town_rocks", "meadow_bend"]
	var resolutions := [Vector2i(1024, 1072), Vector2i(1440, 1584), Vector2i(1832, 1920)]
	if ablation: resolutions = [Vector2i(1440, 1584)]
	if bank_only: locations = ["meadow_bend"]
	if shading_review:
		locations = ["lakeside", "meadow_bend", "boulder_run", "cedar_creek", "glacier_run"]
		resolutions = [Vector2i(1440, 1584)]
		if not review_location.is_empty(): locations = [review_location]
	if reverse_order:
		locations.reverse(); resolutions.reverse()
	for id in locations:
		g.game.state = Fish.State.READY; g.casting = false
		if not g._select_location(id, false):
			push_error("Cannot load benchmark location " + id); quit(1); return
		await process_frame
		freeze(g)
		var foreground_meshes: Array = g.foreground.find_children("*", "MeshInstance3D", true, false)
		var foreground_materials: Array = []
		for mesh in foreground_meshes: foreground_materials.append(mesh.material_override)
		var flat_material := StandardMaterial3D.new()
		flat_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		flat_material.albedo_color = Color(.2, .25, .2)
		var water_override: Material = g.water_surface.material_override
		var flat_water := ShaderMaterial.new()
		flat_water.shader = Shader.new()
		# Retain the production vertex displacement, depth and transparency pipeline.
		flat_water.shader.code = g.water_material.shader.code.split("void fragment()")[0] + "void fragment() { ALBEDO = vec3(.03, .12, .16); ALPHA = 1.0; }"
		flat_water.set_shader_parameter("ripple_strength", g.water_material.get_shader_parameter("ripple_strength"))
		var water_detail = g.water_material.get_shader_parameter("detail_strength")
		var sky_detail = g.panorama_material.get_shader_parameter("detail_strength")
		var spawn: Vector3 = g.foreground.get_meta("spawn")
		for i in 2:
			cameras[i].position = spawn + Vector3((i * 2 - 1) * .032, 1.65, 0)
			cameras[i].rotation_degrees = Vector3(-12, 0, 0)
		for resolution in resolutions:
			for eye in eyes: eye.size = resolution
			# Alternate order between resolutions to reduce systematic ordering bias.
			var modes: Array = ["full", "cheap"] if resolution.x != 1440 else ["cheap", "full"]
			if ablation: modes = ["cheap", "flat_water", "flat_foreground", "flat_sky", "no_sharpen", "cheap_end"]
			if bank_only: modes = ["cheap", "flat_bank", "cheap_end"]
			if shading_review: modes = ["cheap"]
			if reverse_order: modes.reverse()
			for mode in modes:
				var low_cost: bool = mode != "full"
				g.water_surface.material_override = flat_water if mode == "flat_water" else water_override
				for i in foreground_meshes.size():
					foreground_meshes[i].material_override = flat_material if mode == "flat_foreground" else foreground_materials[i]
					if mode == "flat_bank" and foreground_materials[i] is ShaderMaterial and foreground_materials[i].shader.resource_path.ends_with("/rivers/bank.gdshader"):
						foreground_meshes[i].material_override = flat_material
				g.world_environment.background_mode = Environment.BG_COLOR if mode == "flat_sky" else Environment.BG_SKY
				g.water_material.set_shader_parameter("detail_strength", 0.0 if mode == "no_sharpen" else water_detail)
				g.panorama_material.set_shader_parameter("detail_strength", 0.0 if mode == "no_sharpen" else sky_detail)
				g.water_material.set_shader_parameter("low_cost_reflections", low_cost)
				for frame in 36: await process_frame
				var gpu: Array = []; var cpu: Array = []; var wall: Array = []
				var draws: Array = []; var primitives: Array = []
				var last := Time.get_ticks_usec()
				for frame in 90:
					await process_frame
					var gpu_ms := 0.0; var cpu_ms := 0.0
					for eye in eyes:
						gpu_ms += RenderingServer.viewport_get_measured_render_time_gpu(eye.get_viewport_rid())
						cpu_ms += RenderingServer.viewport_get_measured_render_time_cpu(eye.get_viewport_rid())
					gpu.append(gpu_ms); cpu.append(cpu_ms)
					var now := Time.get_ticks_usec()
					wall.append((now - last) / 1000.0); last = now
					draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
					primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
				if percentile(gpu, .5) <= 0:
					push_error("GPU timestamps unavailable"); quit(1); return
				var row := {"location": id, "camera_position": str(cameras[0].position), "camera_rotation_degrees": str(cameras[0].rotation_degrees), "width_per_eye": resolution.x, "height_per_eye": resolution.y,
					"mode": mode, "low_cost_reflections": low_cost, "gpu_ms_p50": percentile(gpu, .5), "gpu_ms_p95": percentile(gpu, .95),
					"render_cpu_ms_p50": percentile(cpu, .5), "wall_ms_p50": percentile(wall, .5), "wall_ms_p95": percentile(wall, .95),
					"draw_calls": percentile(draws, .5), "primitives": percentile(primitives, .5)}
				rows.append(row); save_report()
				print("STEREO_GPU_SAMPLE ", JSON.stringify(row))
				if (resolution.x == 1024 and low_cost) or ablation or shading_review:
					await RenderingServer.frame_post_draw
					eyes[0].get_texture().get_image().save_png(output.get_basename() + "-" + id + ("-" + mode if ablation else "") + ".png")
		g.water_surface.material_override = water_override
		g.world_environment.background_mode = Environment.BG_SKY
		g.water_material.set_shader_parameter("detail_strength", water_detail)
		g.panorama_material.set_shader_parameter("detail_strength", sky_detail)
	for eye in eyes: eye.queue_free()
	g.queue_free()
	await process_frame
	await create_timer(.1).timeout
	print("STEREO_GPU_COMPLETE ", output)
	quit()
