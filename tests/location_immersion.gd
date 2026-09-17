extends SceneTree
## Runtime travel, geometry and native stereo captures for the scenery pass.
var failures:Array=[]
var checks:=0
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize():run.call_deferred()
func run():
	var g=load("res://scenes/main.tscn").instantiate();root.add_child(g)
	await create_timer(.5).timeout
	g.set_process(false);g.motor.set_physics_process(false)
	for item in [g.hud,g.rod,g.avatar,g.fish_guide,g.rod_status,g.bobber]:item.hide()
	g.line_mesh.clear_surfaces()
	var capture=preload("res://tests/xr_capture.gd").new()
	if g.xr:
		var compositor:=Compositor.new();compositor.compositor_effects=[capture];g.head.compositor=compositor
	var folder:="res://test-results/immersion"
	DirAccess.make_dir_recursive_absolute(folder)
	for id in ["meadow_bend","boulder_run","lake_pier","simons_town_rocks"]:
		check(g._select_location(id,false),"Travel "+id)
		check(g.water_material.get_shader_parameter("boulder_pockets")== (id=="boulder_run"),"Rock wake state resets on travel")
		if id in ["meadow_bend","boulder_run"]:
			var path:String="res://assets/textures/lighting/"+id+"_irradiance.exr"
			var config:=ConfigFile.new();check(config.load(path+".import")==OK,"River bake import settings available")
			var imported:String=config.get_value("remap","path","")
			check(preload("res://addons/fishing_export/hdr.gd").export_path(path,imported,true)==imported,"River HDR atlas bypasses desktop block compression")
			check(config.get_value("params","mipmaps/generate",false),"River lightmap has mipmaps")
			var banks:=0
			for node in g.foreground.find_children("*","MeshInstance3D",true,false):
				var mat:Material=node.material_override
				if mat is ShaderMaterial and mat.shader.resource_path.ends_with("bank.gdshader"):
					banks+=1
					check(mat.get_shader_parameter("has_bake"),"HDR river bank bake loaded")
					check(mat.get_shader_parameter("irradiance").get_width()==1024,"Full precision atlas available")
					check(node.mesh.surface_get_arrays(0)[Mesh.ARRAY_TANGENT]!=null,"Bank has normal-map tangents")
			check(banks==4,"Both terrain strips on both banks retained")
			var stones:MultiMeshInstance3D=g.foreground.get_node("InstancedRiverStones")
			check(stones.multimesh.instance_count==(30 if id=="meadow_bend" else 65),"Shore rocks share an instanced mesh")
			var reeds=g.foreground.get_node("RiverMarginReeds")
			check(reeds.get_child_count()==1,"Reeds use one instanced draw")
			check(reeds.get_meta("instances")>40,"River shoreline reed population")
			check(reeds.find_children("*","StaticBody3D",true,false).is_empty(),"Reeds do not block fly casts")
			for plant in reeds.get_meta("plant_footprints"):
				check(absf(plant.at.x)>3.8 or plant.at.z<-15,"Arrival casting gap clear")
		if "--capture" in OS.get_cmdline_user_args():
			for pose in ["standing","seated","side"]:
				g.origin.position=g.foreground.get_meta("spawn")+Vector3(0,-.5 if pose=="seated" else 0,0)
				if pose=="side":g.origin.position.x+=1.5
				if not g.xr:g.head.rotation=Vector3(-.16,.45 if pose=="side" else 0,0)
				for i in 20:await process_frame
				var label:String=id+"_"+pose
				if g.xr:
					capture.request_capture(label)
					for i in 120:
						await process_frame
						if capture.completed==label:break
					check(capture.completed==label and capture.views==2,"Native two-eye capture "+label)
					for eye in capture.results.size():
						var frame:Image=capture.results[eye]
						frame.save_exr(folder+"/"+label+"_eye%d.exr"%eye)
						frame.convert(Image.FORMAT_RGBA8);frame.linear_to_srgb()
						frame.save_png(folder+"/"+label+"_eye%d.png"%eye)
				else:
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png(folder+"/"+label+".png")
	print("IMMERSION_RESULT ",checks," checks, ",failures.size()," failures: ",failures)
	g.queue_free();await process_frame
	quit(0 if failures.is_empty() else 1)
