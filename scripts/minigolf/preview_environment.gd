extends RefCounted
## Preview lighting uses the same location preset as the production environment.
static func setup(scene:Node3D,id:String)->void:
	var entry:Dictionary=preload("res://scripts/locations.gd").find_location(id)
	var env:=WorldEnvironment.new();var environment:=Environment.new();env.environment=environment;scene.add_child(env)
	var sky:=Sky.new();var sky_material:=preload("res://scripts/panorama_material.gd").new();var panorama:=Image.load_from_file(entry.panorama);panorama.resize(4096,2048,Image.INTERPOLATE_LANCZOS);panorama.generate_mipmaps();sky_material.panorama=ImageTexture.create_from_image(panorama);sky.sky_material=sky_material;sky.radiance_size=Sky.RADIANCE_SIZE_128
	environment.sky=sky;environment.background_mode=Environment.BG_SKY
	environment.sky_rotation=Vector3(0,deg_to_rad(entry.yaw),0)
	environment.background_energy_multiplier=entry.get("sky_energy",1.0)
	environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_SKY;environment.ambient_light_energy=entry.ambient
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=entry.sun_rotation;sun.light_color=entry.sun_color;sun.light_energy=entry.sun_energy;sun.shadow_enabled=true;scene.add_child(sun)
	# Show actual land beneath courses so ground-based sites never appear offshore.
	scene.add_child(preload("res://scripts/shore.gd").create(id))
	var water:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(1000,1000);water.mesh=plane
	water.material_override=preload("res://scripts/minigolf/world.gd").material(entry.water,entry.roughness);water.position.y=entry.get("water_level",0.0);scene.add_child(water)
