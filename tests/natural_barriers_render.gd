extends SceneTree
## Visual review of the inland rope barriers; run with the Mobile renderer.
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var g=load("res://scenes/main.tscn").instantiate();root.add_child(g)
	await create_timer(.4).timeout
	g.set_process(false);g.motor.set_physics_process(false)
	for item in [g.hud,g.rod,g.avatar,g.fish_guide,g.rod_status,g.bobber]: item.hide()
	var failures := 0
	for id in ["lakeside","gray_pier"]:
		if not g._select_location(id,false):failures+=1;continue
		g.line_mesh.clear_surfaces()
		var rope_found := false
		for mesh in g.foreground.find_children("*","MeshInstance3D",true,false):
			for surface in mesh.mesh.get_surface_count():
				if mesh.mesh.surface_get_material(surface).resource_name.begins_with("FG_rope"):
					var material: Material=mesh.get_active_material(surface)
					if not (material is StandardMaterial3D and material.albedo_color==Color("9b8158") and material.shading_mode==BaseMaterial3D.SHADING_MODE_UNSHADED):
						push_error("Rope is not uniform tan: "+id);failures+=1
					for vertex in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
						if vertex.y>.45: rope_found=true
		if not rope_found:push_error("Missing raised rope barrier: "+id);failures+=1
		var output: String="res://test-results/natural-barriers/"+id
		DirAccess.make_dir_recursive_absolute(output)
		var views: Array=[
			["front",Vector3(0,1.65,-4.6) if id=="gray_pier" else Vector3(5.5,1.65,2),Vector3(-.2,0 if id=="gray_pier" else -PI/2,0)],
			["rear",Vector3(0,1.65,-1) if id=="gray_pier" else Vector3(0,1.65,8),Vector3(-.2,PI,0)],
		]
		for view in views:
			g.head.global_position=view[1];g.head.rotation=view[2]
			for i in 12: await process_frame
			await RenderingServer.frame_post_draw
			if root.get_texture().get_image().save_png(output+"/"+view[0]+".png")!=OK:failures+=1
	print("NATURAL_BARRIERS_RESULT ",failures)
	g.queue_free();await process_frame;await create_timer(.3).timeout
	quit(0 if failures==0 else 1)
