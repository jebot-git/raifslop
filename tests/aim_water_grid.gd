extends SceneTree
const S=preload("res://scripts/fishing_session.gd")
var failures: Array=[]
var checks:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize()->void:run.call_deferred()
func run()->void:
	var g=load("res://scenes/main.tscn").instantiate();root.add_child(g)
	await create_timer(.4).timeout
	g.set_process(false);g.motor.set_physics_process(false);g.fishing_feedback.set_process(false)
	g.xr=true
	for entry in g.Locations.CATALOG:
		g.game.reset();g.casting=false;g._select_location(entry.id,false)
		await physics_frame;await physics_frame
		check(g.game.population.layouts.has(entry.id),"Configured open-water grid: "+entry.id)
		var length_:=0.0
		for index in S.species_for_location(entry.id,false):length_=maxf(length_,float(S.SPECIES[index].length)*.01)
		g.fish_boundary.set_minimum_height(g.water_level-(maxf(.18,length_*.36)+length_*.30+.36))
		var moved:=0
		for sector in S.Population.SECTOR_COUNT:
			var centre:Vector3=g.game.population.center_for(entry.id,sector,g.water_level+.05)
			if not centre.is_equal_approx(S.Population.sector_center(sector,g.water_level+.05)):moved+=1
			check(not g.fish_boundary.blocked(centre,maxf(1.25,length_*.60+.35)),"Sector clears largest regular fish and dive: "+entry.id+str(sector))
			check(g.game.population.sector_for(entry.id,centre)==sector,"Bite lookup matches relocated sector: "+entry.id+str(sector))
			check(g._cast_target_valid(centre),"Relocated feeding centre accepts aim: "+entry.id+str(sector))
			g.head.look_at(centre)
			var aimed:Vector3=g._projected_cast_target()
			check(aimed.distance_to(centre)<.01,"Head can target every relocated sector: "+entry.id+str(sector))
			var axis:Vector3=g._cast_direction()
			g.right.rotation=Vector3(.2,1.2,.1)
			check(g._projected_cast_target().is_equal_approx(aimed) and g._cast_direction().is_equal_approx(axis),"Wrist does not redirect aim or swing axis")
			g._begin_cast();g.head.rotate_y(.3)
			check(g._projected_cast_target().is_equal_approx(aimed),"Target freezes throughout casting gesture")
			g._cast(15)
			check(g.game.state==S.State.CASTING and g.cast_target.distance_to(centre)<.01,"Valid grid target casts without boundary rejection: "+entry.id+str(sector))
			g.casting=false;g.game.reset()
			g.fish_boundary.set_minimum_height(g.water_level-(maxf(.18,length_*.36)+length_*.30+.36))
		g.fishing_feedback.update_feeding_ripples()
		for sector in S.Population.SECTOR_COUNT:
			check(g.fishing_feedback.feeding_surfaces[sector].global_position.is_equal_approx(g.game.population.center_for(entry.id,sector,g.water_level+.025)),"Feeding ripples share configured grid")
		print("GRID_LAYOUT ",entry.id," moved=",moved," centres=",g.game.population.layouts[entry.id])
	# Returning after moving the rod/head far from the arrival point must not
	# shift the population or make its centres unreachable on travel.
	var layout: Array = g.game.population.layouts["boulder_run"].duplicate()
	g.head.position.x+=40;g.rod.position.x+=40
	g._configure_fishing_grid("boulder_run")
	check(g.game.population.layouts["boulder_run"]==layout,"Grid placement is stable across room movement and travel")
	g.head.position.x-=40;g.rod.position.x-=40
	# A fish collision envelope is allowed to overlap shallow water. It must
	# not remove that water from casting aim, even for a large predator.
	g.game.reset();g._select_location("secluded_beach",false);await physics_frame;await physics_frame
	var shallow_count:=0
	g.fish_boundary.set_minimum_height(g.water_level-1.0)
	for x in range(-4,5):
		for z in range(-12,-5):
			var target:=Vector3(float(x),g.water_level+.05,float(z))
			if g.fish_boundary.blocked(target,.5) and not g.cast_water_boundary.blocked(target,.05):
				if not g.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(g.head.global_position,target,1)).is_empty():continue
				check(g._cast_target_valid(target),"Fish clearance never masks unobstructed shallow-water aim")
				shallow_count+=1
	check(shallow_count>0,"Tested real shallow water outside dry ground but inside fish envelope")
	# Beyond the old global z cutoff, water beside a quay remains targetable.
	g.game.reset();g._select_location("lake_pier",false);await physics_frame;await physics_frame
	var side_count:=0
	for x in [-10.0,10.0]:
		for z in [2.0,4.0]:
			var target:=Vector3(x,g.water_level+.05,z)
			if not g.cast_water_boundary.blocked(target,.05) and g.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(g.head.global_position,target,1)).is_empty():
				check(g._cast_target_valid(target),"Open water is not cut off at world z=1.5")
				side_count+=1
	check(side_count>0,"Tested actual side water beyond old world-axis aiming cutoff")
	g.xr=false;g.ambience.stop();g.fishing_feedback.set_process(false)
	for type in ["AudioStreamPlayer","AudioStreamPlayer3D"]:
		for player in g.find_children("*",type,true,false):player.stop()
	await create_timer(.3).timeout
	g.queue_free();await process_frame;await create_timer(.3).timeout
	print("AIM_WATER_GRID_RESULT ",checks," checks: ",failures);quit(0 if failures.is_empty() else 1)
