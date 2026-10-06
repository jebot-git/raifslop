extends SceneTree
## CPU cost study of production functions, not an FPS or native speedup test.
const Codec=preload("res://scripts/network/pose_codec.gd")
const Fixture=preload("res://tests/network_fixture.gd")
const Fish=preload("res://scripts/fishing_session.gd")
var rows: Array=[]
var checksum:=0
func _initialize():run.call_deferred()
func freeze(node: Node):
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D:node.stop()
	node.set_process(false);node.set_physics_process(false)
	for child in node.get_children():freeze(child)
func bench(label:String,operation:Callable,count:=200,context:Dictionary={}):
	var times: Array=[]
	for block in 10:
		var start:=Time.get_ticks_usec()
		for i in count:operation.call(i)
		if block>0:times.append(float(Time.get_ticks_usec()-start)/count)
	times.sort()
	var row:=context.duplicate();row.merge({"operation":label,"median_us":times[4],"max_batch_mean_us":times[-1],"calls_per_batch":count,"measured_batches":9})
	rows.append(row);print("CANDIDATE_SAMPLE ",JSON.stringify(row))
func run():
	for body_count in [0,10]:
		var pose:=Fixture.player(body_count,true)
		var bytes:=Codec.encode(pose)
		bench("pose_validation",func(_i):checksum+=int(Codec.State.valid(pose)),500,{"body_transforms":body_count})
		bench("pose_encode",func(_i):checksum+=Codec.encode(pose).size(),500,{"body_transforms":body_count,"bytes":bytes.size()})
		bench("pose_decode",func(_i):checksum+=Codec.decode(bytes).size(),500,{"body_transforms":body_count,"bytes":bytes.size()})
	var population=preload("res://scripts/fish_population.gd").new();population.rng.seed=123
	population.ensure_location("lakeside",Fish.species_for_location("lakeside",false))
	bench("population_tick",func(_i):population.tick(1.0/72),500,{"visited_waters":1})
	for id in Fish.LOCATION_SPECIES:population.ensure_location(id,Fish.species_for_location(id,false))
	bench("population_tick",func(_i):population.tick(1.0/72),500,{"visited_waters":population.waters.size()})
	var fishing=Fish.new();fishing.prepare_population()
	bench("fishing_tick_ready",func(_i):fishing.tick(1.0/72,0,0),500)
	fishing.state=Fish.State.BITE;fishing.strike()
	bench("fishing_tick_fight",func(_i):
		fishing.state=Fish.State.FIGHT;fishing.distance=100;fishing.tension=.5;fishing.next_cue=100;fishing.next_submerge=100;fishing.next_jump=100
		fishing.tick(1.0/72,.6,0),500,{"scenario":"ordinary fight, transitions suppressed; includes field reset overhead"})
	var bbq=preload("res://scripts/bbq/model.gd").new();bbq.start("lakeside")
	bench("bbq_tick_idle",func(_i):bbq.tick(1.0/72,["lakeside"]),500,{"stations":1,"items":bbq.stations.lakeside.items.size()})
	for location in ["lakeside","meadow_bend"]:
		bench("bbq_throw_step",func(_i):
			for item in bbq.stations.lakeside.items:
				item.basis=Basis.IDENTITY;item.pos=Vector3(2,4,1);item.velocity=Vector3(1,2,1);item.spin=Vector3(2,1,3)
				bbq.advance_throw(item,1.0/72,location),200,{"location":location,"items":10,"scenario":"ten airborne items; includes field reset overhead"})
	var g=load("res://scenes/main.tscn").instantiate();root.add_child(g)
	await process_frame;await physics_frame
	freeze(g)
	bench("avatar_rest_bounds",func(_i):checksum+=int(preload("res://scripts/avatar_rest_bounds.gd").measure(g.avatar.model).size.y*100),2,{"model":g.avatars.selected_path,"frequency":"once per decoded model; cache bypassed intentionally"})
	for id in ["lakeside","simons_town_rocks","meadow_bend"]:
		g.game.state=Fish.State.READY;g.casting=false
		if not g._select_location(id,false):push_error("Cannot select benchmark water "+id);quit(1);return
		await physics_frame;freeze(g)
		var boundary=g.fish_boundary
		var origin_here:=Vector3(0,g.water_level,-12)
		var info:Dictionary={"location":id,"ground_faces":boundary.ground_faces.size(),"projected_triangles":boundary.triangles.size()}
		bench("boundary_blocked",func(i):checksum+=int(boundary.blocked(origin_here+Vector3(i%21-10,0,i%13-6),.5)),300,info)
		bench("boundary_near_geometry",func(i):
			var triangle:PackedVector2Array=boundary.triangles[i%boundary.triangles.size()]
			var point:Vector2=(triangle[0]+triangle[1]+triangle[2])/3
			checksum+=int(boundary.blocked(Vector3(point.x,g.water_level,point.y),.5)),300,info)
		bench("boundary_short_sweep",func(i):
			var start:Vector3=origin_here+Vector3(i%21-10,0,i%13-6)
			checksum+=int(boundary.clip_motion(start,start+Vector3(.12,0,.08),.5).is_finite()),100,info)
		bench("boundary_segment",func(i):checksum+=int(boundary.segment_obstructed(Vector3(0,1.65,0),origin_here+Vector3(i%21-10,0,i%13-6))),30,info)
		bench("fishing_grid_setup",func(_i):g._configure_fishing_grid(id),1,{"location":id,"frequency":"location change only"})
		g.game.state=Fish.State.WAITING;g.game.cast_position=origin_here;g.game.timer=10000
		bench("line_update_waiting",func(_i):g._update_line(),100,{"location":id,"frequency":"per rendered frame"})
		bench("avatar_update_targets",func(_i):g._update_avatar(1.0/72),200)
	var result:Dictionary={"engine":Engine.get_version_info().string,"scope":"Linux headless CPU microbenchmarks of production functions; batches exclude scene loading and automatic frame callbacks. No GPU, XR or real network traffic measured. Synthetic samples are not a frame-time breakdown.","samples":rows,"checksum":checksum,"native_kernels_enabled":Codec.native!=null}
	var f:=FileAccess.open("user://native-candidates.json",FileAccess.WRITE);f.store_string(JSON.stringify(result,"  "));f.close()
	print("CANDIDATE_REPORT ",ProjectSettings.globalize_path("user://native-candidates.json"))
	g.free();await process_frame;await create_timer(.1).timeout;quit()
