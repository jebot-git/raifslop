extends SceneTree
const Visual=preload("res://scripts/bait_visual.gd")
const S=preload("res://scripts/fishing_session.gd")
var failures: Array=[]
func _initialize():run.call_deferred()
func run():
	var world:=Node3D.new();root.add_child(world)
	var env:=WorldEnvironment.new();world.add_child(env);env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("172e36")
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.7
	var light:=DirectionalLight3D.new();world.add_child(light);light.rotation_degrees=Vector3(-35,-25,0);light.light_energy=1.5
	var camera:=Camera3D.new();world.add_child(camera);camera.position=Vector3(0,0,5);camera.current=true;camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=6.5
	var markers:=["WormSegment","CornKernel","MetalBlade","MaggotSegment","BreadCrust","FeatherWing"]
	for index in 6:
		var bait=Visual.new();world.add_child(bait);bait.set_bait(index)
		var expected: String=markers[index]
		var matches: bool=bait.find_children(expected+"*","MeshInstance3D",true,false).size()>0
		print("PASS " if matches else "FAIL ",S.BAITS[index]," has distinct modeled geometry")
		if not matches:failures.append(expected)
		bait.scale=Vector3.ONE*18; bait.position=Vector3((index%3-1)*2,1.55-floor(index/3.0)*1.8,0)
		var label:=Label3D.new();world.add_child(label);label.text=S.BAITS[index];label.position=bait.position+Vector3(0,.25,0);label.font_size=44;label.pixel_size=.0025
	if "--capture" in OS.get_cmdline_user_args():
		for frame in 8:await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://test-results/live-analytics/bait-types.png")
	world.queue_free();await process_frame
	print("BAIT_VISUALS_RESULT ",failures);quit(0 if failures.is_empty() else 1)
