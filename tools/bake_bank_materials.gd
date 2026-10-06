extends SceneTree
## GPU material bake from the original shader and exact runtime terrain triangles.
## Run with a real Mobile/Vulkan renderer, --xr-mode off and --reference-bank-shading.
const River = preload("res://scripts/river_foreground.gd")
const OUT = "res://assets/environment/rivers/baked/"
func _initialize(): run.call_deferred()
func run():
	if DisplayServer.get_name() == "headless": quit(1); return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var vp := SubViewport.new()
	vp.own_world_3d = true; vp.use_hdr_2d = true
	vp.size = Vector2i(8192, 4096)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color.BLACK
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	vp.add_child(environment)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 128.0
	camera.position = Vector3(0, 20, -14)
	camera.rotation_degrees.x = -90
	vp.add_child(camera)
	camera.current = true
	# Atlas covers x [-128,128], z [-78,50], with a margin around all banks.
	var code := FileAccess.get_file_as_string("res://assets/environment/rivers/bank.gdshader")
	code = code.replace("render_mode ambient_light_disabled;", "render_mode unshaded, cull_disabled;")
	code = code.replace("\n}\nvoid fragment", "\n VERTEX.y = 0.0;\n}\nvoid fragment")
	code = code.split("void light()")[0]
	for id in ["meadow_bend", "boulder_run", "cedar_creek", "glacier_run"]:
		var terrain := Node3D.new(); vp.add_child(terrain)
		var source := River.bank_material_reference(id)
		River.terrain(terrain, false, source, source)
		River.terrain(terrain, true, source, source)
		for channel in ["albedo", "normal_rough", "emission"]:
			# Temperate material layers are identical; only lighting differs by river.
			if channel != "emission" and id not in ["boulder_run", "glacier_run"]: continue
			var material: ShaderMaterial = source.duplicate()
			material.shader = Shader.new()
			var ending := "vec3 result = ALBEDO;"
			if channel == "normal_rough": ending = "vec3 result = vec3(NORMAL_MAP.xy, ROUGHNESS);"
			if channel == "emission": ending = "vec3 result = EMISSION;"
			if channel != "normal_rough":
				# sRGB encoding on the GPU before 8-bit quantization preserves dark detail.
				if channel == "emission": ending += " result *= .25;"
				ending += " result=max(result,vec3(0.0)); result=mix(result*12.92,1.055*pow(result,vec3(1.0/2.4))-.055,step(vec3(.0031308),result));"
			material.shader.code = code.left(code.rfind("}")) + ending + "\n ALBEDO=result; EMISSION=vec3(0.0); }\n"
			for mesh in terrain.find_children("*", "MeshInstance3D", true, false): mesh.material_override = material
			for frame in 8: await process_frame
			await RenderingServer.frame_post_draw
			var image := vp.get_texture().get_image()
			var probe := image.get_pixel(image.get_width()/2, int(image.get_height()*83.0/128.0))
			print("BANK_PROBE ", id, " ", channel, " ", probe, " camera=", camera.is_current())
			if probe.r + probe.g + probe.b < .00001:
				push_error("Empty bank atlas"); quit(1); return
			if image.get_format() not in [Image.FORMAT_RGBH, Image.FORMAT_RGBF, Image.FORMAT_RGBAH, Image.FORMAT_RGBAF]:
				push_error("Bake requires linear HDR readback, got " + str(image.get_format())); quit(1); return
			image.convert(Image.FORMAT_RGB8)
			image.save_png(OUT + id + "_" + channel + ".png")
			var config := ConfigFile.new()
			config.set_value("remap", "importer", "texture")
			config.set_value("remap", "type", "CompressedTexture2D")
			config.set_value("params", "compress/mode", 2)
			config.set_value("params", "compress/high_quality", true)
			config.set_value("params", "compress/normal_map", 0)
			config.set_value("params", "mipmaps/generate", true)
			config.set_value("params", "detect_3d/compress_to", 0)
			config.save(OUT + id + "_" + channel + ".png.import")
			print("BANK_BAKE ", id, " ", channel, " ", image.get_size())
		terrain.free()
	vp.queue_free(); await process_frame; quit()
