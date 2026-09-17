extends SceneTree
## Functional coastal travel plus optional standing/seated/rear/foundation captures.
var failures: Array[String] = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label); push_error(label)
func run() -> void:
	var g=load("res://scenes/main.tscn").instantiate();root.add_child(g)
	await create_timer(.4).timeout
	g.set_process(false);g.motor.set_physics_process(false)
	for item in [g.hud,g.rod,g.avatar,g.fish_guide,g.rod_status,g.bobber]: item.hide()
	for id in ["simons_town_rocks","blouberg_sunrise_2","secluded_beach","fish_hoek_beach"]:
		check(g._select_location(id,false),"Travel "+id)
		await physics_frame
		var entry: Dictionary=g.Locations.find_location(id)
		check(g.water_material.get_shader_parameter("protect_panorama_foreground")==entry.get("protect_panorama_foreground",false),"Coastal water preset "+id)
		check(g.water_material.get_shader_parameter("coastal_foreground")== (id=="simons_town_rocks"),"Foreground water coverage resets on travel")
		check(g.water_material.get_shader_parameter("coastal_shallows")==entry.get("coastal_shallows",false),"Shallow sand transition resets on travel")
		if id=="simons_town_rocks":
			var rear=g.foreground.get_node("RearRockTransitions")
			var rocks:MultiMesh=rear.get_node("CurvedRockCards").multimesh
			check(rocks.instance_count==6,"Rear reconstruction has three paired depth tiers")
			# The headless renderer does not retain MultiMesh transform buffers.
			var bases:Array=rear.get_meta("bases")
			check(bases[4].z-bases[0].z>10,"Rear layers provide spatial depth")
		check(g.foreground.get_node("EnvironmentalLife").insect_count==0,"Coastal birds without inland insect swarm")
		if id in ["secluded_beach","fish_hoek_beach"]:
			check(g.foreground.has_node("CoastalShoreDetails/DuneGrass"),"Generated shoreline details loaded "+id)
			check(g.water_material.get_shader_parameter("beach_sides"),"Side surf joins the panorama "+id)
			# Sand must intercept rays just inland of the waterline, beyond the dry floor proxy.
			var slope=g.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0,1,-4),Vector3(0,-2,-4),1))
			check(not slope.is_empty() and slope.position.y<0 and slope.position.y>g.water_level,"Landing rays hit the sand slope "+id)
		check(g.ambience.voices[id].player.stream.get_length()>120,"Long recorded surf bed "+id)
		for point in [Vector3(0,.1,.65),Vector3(0,.1,-2.5),Vector3(2,.1,-2)]:
			var hit=g.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point,point-Vector3.UP,1))
			check(not hit.is_empty(),"Supported fishing area "+id+str(point))
		for mesh in g.foreground.find_children("*BakedForeground*","MeshInstance3D",true,false):
			check(mesh.get_aabb().position.y<g.water_level-.5,"Foundation or sand slope extends beneath water "+id)
			var preserved := false
			for surface in mesh.mesh.get_surface_count():
				var material:Material=mesh.get_active_material(surface)
				var blend: Material=material.next_pass
				# Hoek's opaque baked shader now performs the projection itself.
				if id=="fish_hoek_beach" and material is ShaderMaterial and mesh.mesh.surface_get_material(surface).resource_name.begins_with("FG_sand"):
					check(material.get_shader_parameter("ground_projection")==true,"Hoek sand uses integrated projection")
					blend=material
				preserved = preserved or (blend != null and blend.get_shader_parameter("ground_bounds")==entry.ground_bounds)
				if mesh.mesh.surface_get_material(surface).resource_name.begins_with("FG_stone"):
					check(blend==null,"Boulders remain opaque at the photographic ground transition")
			check(preserved,"Photographic transition preserves playable footprint")
			if id=="blouberg_sunrise_2":
				for surface in mesh.mesh.get_surface_count():
					check(mesh.mesh.surface_get_material(surface).resource_name.begins_with("FG_sand"),"Sunrise walkable model is sand, with no pier structures")
		for bait in range(g.Session.BAITS.size()):
			g.game.reset();g.game.select_bait(bait);g.game.cast(15);g.game.tick(1,0,0)
			check(g.game.fish_index in g.Session.species_for_location(id),"Playable marine roster "+id)
		g.game.reset()
		g.line_mesh.clear_surfaces()
		if "--capture" in OS.get_cmdline_user_args():
			var output: String = "res://test-results/coastal-locations/"+id
			DirAccess.make_dir_recursive_absolute(output)
			for view in [["front",Vector3(0,1.65,.65),Vector3(-.12,0,0)],
				["seated",Vector3(0,1.1,.65),Vector3(-.12,0,0)],
				["rear",Vector3(0,1.65,.65),Vector3(-.18,PI,0)],
				["edge",Vector3(2,1.65,-2.5),Vector3(-.65,-.45,0)],
				["foundation",Vector3(8,.2,-8),Vector3.ZERO]]:
				g.head.global_position=view[1];g.head.rotation=view[2]
				if view[0]=="foundation": g.head.look_at(Vector3(0,-.3,0))
				for i in 12: await process_frame
				await RenderingServer.frame_post_draw
				check(root.get_texture().get_image().save_png(output+"/"+view[0]+".png")==OK,"Capture "+id+" "+view[0])
	print("COASTAL_LOCATIONS_RESULT ",failures)
	g.queue_free();await process_frame;await create_timer(.3).timeout
	quit(0 if failures.is_empty() else 1)
