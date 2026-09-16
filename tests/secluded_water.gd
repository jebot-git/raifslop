extends SceneTree
var failures: Array = []
func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures.append(label)
func _initialize() -> void: run.call_deferred()
func settle() -> void:
	for i in 12: await process_frame
	await RenderingServer.frame_post_draw
func run() -> void:
	root.size=Vector2i(1400,900)
	var g=load("res://scenes/main.tscn").instantiate();root.add_child(g)
	await create_timer(.4).timeout
	g.set_process(false);g.motor.set_physics_process(false);g.fishing_feedback.set_process(false)
	g._select_location("secluded_beach",false)
	for item in [g.hud,g.rod,g.avatar,g.fish_guide,g.rod_status,g.bobber]:item.hide()
	g.line_mesh.clear_surfaces()
	var suffix := "after"
	DirAccess.make_dir_recursive_absolute("res://test-results/secluded-water")
	for view in [["front",Vector3(0,1.65,.65),Vector3(-.17,0,0)],["edge",Vector3(0,1.65,-3),Vector3(-.28,0,0)],["seated",Vector3(0,1.1,.65),Vector3(-.17,0,0)]]:
		g.head.global_position=view[1];g.head.rotation=view[2]
		await settle()
		root.get_texture().get_image().save_png("res://test-results/secluded-water/"+view[0]+"-"+suffix+".png")
	# Isolate the water surface from every opaque object. Missing depth must
	# still draw ocean, rather than punch a transparent hole into the panorama.
	g.foreground.hide()
	g.head.global_position=Vector3(0,1.65,-3);g.head.look_at(Vector3(0,g.water_level,-18))
	var original: ShaderMaterial=g.water_material
	var diagnostic: ShaderMaterial=original.duplicate()
	var shader:=Shader.new()
	shader.code=original.shader.code.replace("vec3 near_water = mix(deep_color*.32, reflection, fresnel);","vec3 near_water = vec3(1.0,0.0,1.0);").replace("vec3 photograph = panorama_sample(sky_inverse * incident, true) * sky_energy;","vec3 photograph = vec3(0.0);")
	diagnostic.shader=shader;g.water_surface.material_override=diagnostic
	await settle()
	var frame:Image=root.get_texture().get_image()
	frame.save_png("res://test-results/secluded-water/depth-gap-"+suffix+".png")
	var point:Vector2=g.head.unproject_position(Vector3(0,g.water_level,-18))
	var pixel:=frame.get_pixelv(Vector2i(point))
	print("WATER_COVERAGE_PIXEL ",pixel)
	check(pixel.r>.7 and pixel.b>.7 and pixel.g<.15,"Animated water covers the front fishing area even without opaque depth")
	g.water_surface.material_override=original
	g.queue_free();await process_frame;await create_timer(.2).timeout
	print("SECLUDED_WATER_RESULT ",failures);quit(0 if failures.is_empty() else 1)
