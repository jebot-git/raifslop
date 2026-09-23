extends SceneTree
## Investigation harness. XR must be off; isolated saves are recommended.
## -- --profile-course cypress --profile-mode world|transition|threaded
const Model=preload("res://addons/golfminus/scripts/golf/course_model.gd")
const World=preload("res://addons/golfminus/scripts/world/connected_course_world.gd")
var builds:Array=[]
var seen_worlds:Array[int]=[]
var started:=0
class BenchmarkJob extends RefCounted:
	var model:RefCounted
	var origins:Array[Vector2]=[]
	var results:Array=[]
	func run_tile(i:int)->void:
		results[i]=preload("res://addons/golfminus/scripts/world/terrain_job.gd").tile_arrays(model,origins[i])
class ProfileWorld extends "res://addons/golfminus/scripts/world/connected_course_world.gd":
	var stages:Dictionary={}
	var tiles:=0
	func _tile_mesh(at:Vector2)->ArrayMesh:
		var start:=Time.get_ticks_usec()
		var mesh:=super._tile_mesh(at)
		stages.tile_mesh_us=stages.get("tile_mesh_us",0)+Time.get_ticks_usec()-start
		tiles+=1
		return mesh
	func _terrain()->void:
		var start:=Time.get_ticks_usec();super._terrain();stages.terrain_us=Time.get_ticks_usec()-start
	func _shared_water()->void:
		var start:=Time.get_ticks_usec();super._shared_water();stages.water_us=Time.get_ticks_usec()-start
	func _shared_scenery()->void:
		var start:=Time.get_ticks_usec();super._shared_scenery();stages.scenery_us=Time.get_ticks_usec()-start
	func _all_holes()->void:
		var start:=Time.get_ticks_usec();super._all_holes();stages.markers_us=Time.get_ticks_usec()-start
func option(name:String,fallback:String)->String:
	var args:=OS.get_cmdline_user_args();var at:=args.find(name)
	return args[at+1] if at>=0 and at+1<args.size() else fallback
func _initialize()->void:run.call_deferred()
func emit(data:Dictionary)->void:
	data.course=option("--profile-course","cypress");data.renderer=RenderingServer.get_current_rendering_method()
	data.headless=DisplayServer.get_name()=="headless"
	print("GOLF_LOAD_PROFILE ",JSON.stringify(data))
func course_added(node:Node)->void:
	if node.name=="PreparedCourse" and node.get_instance_id() not in seen_worlds:
		seen_worlds.append(node.get_instance_id())
		builds.append({"course":node.course_key,"since_start_ms":(Time.get_ticks_usec()-started)/1000.0})
func threaded_profile(id:String)->void:
	var workers:=int(option("--profile-workers","2"))
	var commit_budget_ms:=float(option("--profile-commit-budget-ms","0"))
	var model:=Model.new();model.load_course(id)
	var job:=BenchmarkJob.new();job.model=model
	var bounds:Rect2=model.course_bounds()
	for z in range(floori(bounds.position.y/96),ceili(bounds.end.y/96)):
		for x in range(floori(bounds.position.x/96),ceili(bounds.end.x/96)):job.origins.append(Vector2(x*96,z*96))
	job.results.resize(job.origins.size())
	var start:=Time.get_ticks_usec();var previous:=start
	var frame_gaps:Array[float]=[]
	if workers==0:
		for i in job.origins.size():job.run_tile(i)
	else:
		var task:=WorkerThreadPool.add_group_task(job.run_tile,job.origins.size(),workers,false,"Course CPU tile prototype")
		while not WorkerThreadPool.is_group_task_completed(task):
			await process_frame
			var now:=Time.get_ticks_usec();frame_gaps.append((now-previous)/1000.0);previous=now
		WorkerThreadPool.wait_for_group_task_completion(task)
	var data_ms:=(Time.get_ticks_usec()-start)/1000.0
	var meshes:Array=[];var shapes:Array=[]
	var commit_busy_us:=0;var commit_slice_us:=0;var commit_peak_us:=0
	var commit_frames:=0
	start=Time.get_ticks_usec()
	for arrays in job.results:
		var tile_start:=Time.get_ticks_usec()
		var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		meshes.append(mesh);shapes.append(mesh.create_trimesh_shape())
		var tile_us:=Time.get_ticks_usec()-tile_start
		commit_busy_us+=tile_us;commit_slice_us+=tile_us
		commit_peak_us=maxi(commit_peak_us,commit_slice_us)
		if commit_budget_ms>0 and commit_slice_us>=commit_budget_ms*1000:
			await process_frame;commit_frames+=1;commit_slice_us=0
	var commit_ms:=(Time.get_ticks_usec()-start)/1000.0
	var reference:=World.new();reference.model=model
	var expected:Array=reference._tile_mesh(job.origins[0]).surface_get_arrays(0)
	var actual:Array=meshes[0].surface_get_arrays(0)
	for key in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_INDEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_COLOR,Mesh.ARRAY_TANGENT]:
		assert(expected[key]==actual[key],"Threaded tile differs from production terrain")
	reference.free();frame_gaps.sort()
	emit({"mode":"threaded","workers":workers,"tiles":job.origins.size(),"cpu_arrays_ms":data_ms,"main_thread_mesh_and_shape_ms":commit_ms,"commit_busy_ms":commit_busy_us/1000.0,"commit_peak_slice_ms":commit_peak_us/1000.0,"commit_budget_ms":commit_budget_ms,"commit_yield_frames":commit_frames,"cpu_phase_main_frame_count":frame_gaps.size(),"cpu_phase_main_frame_max_ms":frame_gaps.back() if not frame_gaps.is_empty() else data_ms,"cpu_phase_main_frame_p95_ms":frame_gaps[int((frame_gaps.size()-1)*.95)] if not frame_gaps.is_empty() else data_ms,"reference_tile_identical":true})
func run()->void:
	var id:=option("--profile-course","cypress")
	var mode:=option("--profile-mode","world")
	if mode=="threaded":
		await threaded_profile(id);quit();return
	if mode=="world":
		for pass_name in ["cold","warm"]:
			var start:=Time.get_ticks_usec();var model:=Model.new();model.load_course(id)
			var model_ms:=(Time.get_ticks_usec()-start)/1000.0
			var before:=OS.get_static_memory_usage()
			var world:=ProfileWorld.new();root.add_child(world)
			start=Time.get_ticks_usec();world.build(model)
			var row:Dictionary={"mode":mode,"pass":pass_name,"model_ms":model_ms,"world_ms":(Time.get_ticks_usec()-start)/1000.0,"stages_us":world.stages.duplicate(),"generated_tiles":world.tiles,"static_memory_delta_mb":(OS.get_static_memory_usage()-before)/1048576.0}
			var bounds:Rect2=model.course_bounds();row.total_tiles=int(bounds.size.x/96)*int(bounds.size.y/96)
			# Isolate guide raster construction (same code as the real tablet).
			var game:=Node3D.new();var script:=GDScript.new();script.source_code="extends Node3D\nvar model\n";script.reload();game.set_script(script);game.model=model
			var guide=load("res://addons/golfminus/scripts/golf/course_guide.gd").new();guide.game=game
			var screen=load("res://addons/golfminus/scripts/golf/course_guide_screen.gd").new();screen.guide=guide
			start=Time.get_ticks_usec();screen._build_map(id);row.guide_map_ms=(Time.get_ticks_usec()-start)/1000.0
			emit(row)
			screen.free();guide.free();game.free();world.queue_free();await process_frame
	else:
		var host=load("res://scenes/main.tscn").instantiate();root.add_child(host)
		await create_timer(.4).timeout
		node_added.connect(course_added)
		for pass_name in ["cold","warm"]:
			builds.clear();seen_worlds.clear();started=Time.get_ticks_usec()
			host.golf_activity.join_course(id)
			var request_ms:=(Time.get_ticks_usec()-started)/1000.0
			var previous:=started;var gaps:Array[float]=[]
			while not host.golf_activity.loading_course.is_empty():
				await process_frame
				var now:=Time.get_ticks_usec();gaps.append((now-previous)/1000.0);previous=now
			assert(host.golf_activity.active and host.golf_activity.golf.course_id==id)
			var elapsed_ms:=(Time.get_ticks_usec()-started)/1000.0
			gaps.sort()
			emit({"mode":mode,"pass":pass_name,"request_ms":request_ms,"elapsed_ms":elapsed_ms,"load":host.golf_activity.last_load_metrics.duplicate(),"frames":gaps.size(),"frame_max_ms":gaps.back(),"frame_p95_ms":gaps[int((gaps.size()-1)*.95)],"built_courses":builds.duplicate(true),"static_memory_mb":OS.get_static_memory_usage()/1048576.0})
			host.golf_activity.leave()
			for frame in 3:await process_frame
		host.queue_free();await process_frame;await create_timer(.1).timeout
	quit()
