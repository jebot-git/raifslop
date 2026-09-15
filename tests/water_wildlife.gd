extends SceneTree
var failures: Array=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func run() -> void:
	var g=load("res://scenes/main.tscn").instantiate();root.add_child(g)
	await create_timer(.3).timeout
	g.set_process(false);g.motor.set_physics_process(false)
	var meshes: Array=[];var insect_kinds: Array=[];var flight_speeds: Array=[]
	for entry in g.Locations.CATALOG:
		g.game.reset();check(g._select_location(entry.id,false),"Visit "+entry.name)
		var life=g.foreground.get_node("EnvironmentalLife")
		check(life.bird_count==life.birds.multimesh.instance_count and life.insect_count==life.insects.multimesh.instance_count,"Wildlife counts match habitat: "+entry.id)
		meshes.append(life.birds.multimesh.mesh.get_aabb().size)
		insect_kinds.append(life.profile.insect);flight_speeds.append(life.profile.speed)
		var before: Transform3D=life.bird_transform(0)
		life._process(1.0)
		check(not before.is_equal_approx(life.bird_transform(0)),"Birds follow animated flight paths: "+entry.id)
		for i in life.insect_count:
			var insect: Transform3D=life.insect_transform(i)
			check(insect.origin.is_finite() and insect.origin.y>.3,"Insects stay above water: "+entry.id)
		if entry.id=="lake_pier":
			check(is_equal_approx(g.water_level,-.85) and is_equal_approx(g.water_surface.position.y,g.water_level),"Pier water and float share the harbour waterline")
			for body in g.foreground.get_children():
				if body is StaticBody3D and body.get_meta("role", "")=="floor":
					var size: Vector3=body.get_child(0).shape.size
					check(body.position.y-size.y*.5<g.water_level-.2,"Quay foundation extends below water without an air gap")
					check(is_zero_approx(body.position.y+size.y*.5),"Remodelling keeps the walkable deck at zero")
			for mesh in g.foreground.find_children("*distant*", "MeshInstance3D", true, false):
				check(mesh.get_aabb().end.y<=0,"Harbour mainland stays below deck height")
				var blend: Material=mesh.get_active_material(0).next_pass
				check(blend is ShaderMaterial and blend.get_shader_parameter("panorama")==g.panorama_material.panorama,"Ground transition shares the active panorama")
			check(g.water_material.get_shader_parameter("protect_panorama_foreground"),"Pier preserves photographed structures outside open-water region")
			check(life.insect_count==0 and not life.insects.visible,"Cool harbour has gulls without repeated insect swarm")
		else:
			check(is_equal_approx(g.water_level,-.35) and g.water_material.get_shader_parameter("protect_panorama_foreground")==entry.get("protect_panorama_foreground",false),"Travelling restores other water presets")
		g.rod.rotation=Vector3(.35,0,0);g._cast(22)
		check(g.game.state==g.Session.State.CASTING and is_equal_approx(g.cast_target.y,g.water_level+.05),"Float cast follows selected water height: "+entry.id)
		g.game.state=g.Session.State.WAITING;g._update_line()
		check(absf(g.bobber.position.y-g.water_level-.05)<.03,"Waiting float rests at selected water surface")
	check(meshes.size()==g.Locations.CATALOG.size() and meshes[0]!=meshes[1] and meshes[1]!=meshes[2] and meshes[2]!=meshes[3],"Bird species have distinct silhouettes")
	check(insect_kinds==["fly","none","midge","dragonfly","none","none"] and flight_speeds[0]!=flight_speeds[1] and flight_speeds[2]!=flight_speeds[3],"Waters vary insect species and flight speeds")
	g.queue_free();await process_frame;await create_timer(.3).timeout
	print("WATER_WILDLIFE_RESULT ",failures);quit(0 if failures.is_empty() else 1)
