extends Node3D
## Desktop material review without the VR-only gameplay startup.
var model=preload("res://addons/golfminus/scripts/golf/course_model.gd").new()
var world:Node3D
var camera:Camera3D
func _ready()->void:
	var environment:=WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_SKY
	var sky:=Sky.new();sky.sky_material=ProceduralSkyMaterial.new();environment.environment.sky=sky
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_SKY
	add_child(environment)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-42,-35,0);sun.light_energy=1.1;sun.shadow_enabled=true;add_child(sun)
	camera=Camera3D.new();camera.far=2500;camera.current=true;add_child(camera)
	show_course("spyglass",0)
	if "--capture" in OS.get_cmdline_user_args():
		for frame in 4:await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/golf-course-preview.png")
		get_tree().quit()
func show_course(id:String,hole:int)->void:
	if is_instance_valid(world):remove_child(world);world.queue_free()
	model.load_course(id,hole)
	world=preload("res://addons/golfminus/scripts/world/connected_course_world.gd").new();add_child(world);world.model=model
	# Preview only the active hole's tiles; use the production meshes/materials.
	var bounds:Rect2=model.map_bounds().grow(96)
	var mat:Material=world.terrain_material()
	for z in range(floori(bounds.position.y/96),ceili(bounds.end.y/96)):
		for x in range(floori(bounds.position.x/96),ceili(bounds.end.x/96)):
			world.mesh_node(world._tile_mesh(Vector2(x,z)*96),Vector3.ZERO,mat)
	world._shared_water();world._shared_scenery();world._all_holes()
	var tee:Vector3=model.tee();var target:Vector3=model.guide_target(tee)
	var forward:Vector3=(target-tee).normalized()
	camera.position=tee-forward*28+Vector3(0,28,0);camera.look_at(tee+forward*75)
