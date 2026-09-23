extends Node
## Prepare a hidden, collision-disabled course while the current activity runs.
signal finished(course_world:Node3D)
signal progress(value:float,label:String)
const World=preload("res://addons/golfminus/scripts/world/connected_course_world.gd")
const Model=preload("res://addons/golfminus/scripts/golf/course_model.gd")
const Job=preload("res://addons/golfminus/scripts/world/terrain_job.gd")
const ASSETS=["shaders/terrain.gdshader","shaders/foliage.gdshader","assets/shared/river_bank.png","assets/shared/grass.jpg","assets/shared/grass_normal.jpg","assets/shared/sand.jpg","assets/shared/sand_normal.jpg","assets/vegetation/river_alder.png","assets/models/pavilion.glb"]
var worker_count:=2
var frame_budget_usec:=2000
var error:=""
var cancelled:=false
var done:=false
var world:Node3D
var model:RefCounted
var job:RefCounted
var task:=-1
var key:=""
var course_id:=""
var resources:Dictionary={}
var requested:Array[String]=[]
var tiles:Array=[]
var pending:Array=[]
var pending_cursor:=0
var committed:=0
var ground:Node3D
var terrain_material:Material
var phase:=0
var cursor:=0
var groups:Array=[]
var prop_meshes:Array=[]
var cache_hit:=false
var started_usec:=0
var peak_step_usec:=0
var peak_frame_work_usec:=0
var metrics:Dictionary={}
func _ready()->void:set_process(false)
func asset_paths()->Array[String]:
	var paths:Array[String]=[]
	for path in ASSETS:paths.append("res://addons/golfminus/"+path)
	if not model.layout.data.get("rocks",[]).is_empty():paths.append("res://addons/golfminus/assets/models/schist.glb")
	return paths
func start(id:String,hole_index:=0)->void:
	started_usec=Time.get_ticks_usec();course_id=id
	if id not in preload("res://addons/golfminus/scripts/golf/catalog.gd").ACTIVE:
		error="Unknown mapped course.";set_process(true);return
	var text:=FileAccess.get_file_as_string("res://addons/golfminus/courses/%s.json"%id)
	var data:Variant=JSON.parse_string(text)
	if not data is Dictionary or not data.get("layout",{}).has("surface") or data.get("holes",[]).size()!=18:
		error="Course data could not be read.";set_process(true);return
	var surface:Dictionary=data.layout.surface
	var width:=int(surface.get("width",0));var height:=int(surface.get("height",0))
	for file in ["lies.bin","height.bin"]:
		var stream:=FileAccess.open("res://addons/golfminus/assets/course_data/%s/%s"%[id,file],FileAccess.READ)
		var expected:int=width*height if file=="lies.bin" else (((width-1)/2+1)*((height-1)/2+1))*4
		if width<3 or height<3 or stream==null or stream.get_length()!=expected:
			error="Course terrain is missing or incomplete.";set_process(true);return
	model=Model.new();model.configure(data,hole_index)
	key=JSON.stringify(model.course).sha256_text()
	tiles=World.mesh_cache.get(key,[]).duplicate();cache_hit=not tiles.is_empty()
	job=Job.new();job.model=model
	var bounds:Rect2=model.course_bounds()
	for z in range(floori(bounds.position.y/World.TILE),ceili(bounds.end.y/World.TILE)):
		for x in range(floori(bounds.position.x/World.TILE),ceili(bounds.end.x/World.TILE)):job.origins.append(Vector2(x*World.TILE,z*World.TILE))
	# Keep cache indices canonical while preparing arrival and the selected hole
	# first. The complete course still becomes playable in one final transfer.
	var arrival:Array=model.layout.data.get("clubhouse",[43,17])
	var at:=Vector2(arrival[0],arrival[1]);var hole_bounds:Rect2=model.map_bounds()
	var priorities:Array[float]=[]
	for i in job.origins.size():
		var center:Vector2=job.origins[i]+Vector2.ONE*World.TILE*.5
		var distance:=center.distance_squared_to(at)
		priorities.append(distance if distance<World.TILE*World.TILE*4 else 1e8+distance if hole_bounds.intersects(Rect2(job.origins[i],Vector2.ONE*World.TILE)) else 2e8+distance)
		job.order.append(i)
	job.order.sort_custom(func(a:int,b:int):return priorities[a]<priorities[b])
	if not cache_hit:
		tiles.resize(job.origins.size())
		task=WorkerThreadPool.add_group_task(job.run_tile,job.origins.size(),clampi(worker_count,1,4),false,"Golf terrain: "+id)
	for path in asset_paths():
		if not ResourceLoader.exists(path):error="A course resource is missing: "+path.get_file();break
		if ResourceLoader.load_threaded_request(path)!=OK:error="Unable to prepare "+path.get_file();break
		requested.append(path)
	set_process(true)
func cancel()->void:
	if done:return
	cancelled=true
	if job!=null:job.cancel()
func _collect_task()->void:
	if task>=0 and WorkerThreadPool.is_group_task_completed(task):
		WorkerThreadPool.wait_for_group_task_completion(task);task=-1
func _poll_resources()->bool:
	var complete:=true
	for path in requested.duplicate():
		var state:=ResourceLoader.load_threaded_get_status(path)
		if state==ResourceLoader.THREAD_LOAD_IN_PROGRESS:complete=false;continue
		if state==ResourceLoader.THREAD_LOAD_LOADED:
			var resource:=ResourceLoader.load_threaded_get(path)
			if not cancelled and error.is_empty():resources[path]=resource
		else:error="Unable to load "+path.get_file()
		requested.erase(path)
	return complete
func _process(_delta:float)->void:
	var frame_start:=Time.get_ticks_usec()
	_collect_task()
	var assets_ready:=_poll_resources()
	if cancelled or not error.is_empty():
		if job!=null:job.cancel()
		if task<0 and assets_ready:_finish(false)
		return
	if job!=null:pending.append_array(job.take_ready())
	if not assets_ready:return
	while not done and not cancelled:
		var step_start:=Time.get_ticks_usec()
		var advanced:=_step()
		peak_step_usec=maxi(peak_step_usec,Time.get_ticks_usec()-step_start)
		if not advanced or Time.get_ticks_usec()-frame_start>=frame_budget_usec:break
	peak_frame_work_usec=maxi(peak_frame_work_usec,Time.get_ticks_usec()-frame_start)
	if not done:
		progress.emit(.8*float(committed)/maxi(1,tiles.size()) if phase<=1 else .8+.19*(phase-2)/7.0,"Preparing terrain %d / %d"%[committed,tiles.size()] if phase<=1 else "Preparing clubhouse and scenery")
func _step()->bool:
	match phase:
		0:
			world=World.new();world.name="PreparedCourse";world.model=model;world.course_key=course_id
			world.staging=true;world.visible=false;world.process_mode=Node.PROCESS_MODE_DISABLED;add_child(world)
			terrain_material=world.terrain_material();ground=Node3D.new();ground.name="PlayableTerrain";world.add_child(ground);phase=1
		1:
			if committed==tiles.size():
				if task>=0:return false
				# Publish a complete cache only; cancelled/partial generations never appear.
				if not cache_hit:World.mesh_cache[key]=tiles.duplicate()
				pending.clear();pending_cursor=0;phase=2;return true
			var index:=committed
			if not cache_hit:
				if pending_cursor>=pending.size():
					if task<0 and job.completed_count()!=tiles.size():error="Terrain preparation did not complete.";cancel()
					return false
				var item:Array=pending[pending_cursor];pending[pending_cursor]=null;pending_cursor+=1;index=item[0]
				var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,item[1])
				tiles[index]={"mesh":mesh,"shape":mesh.create_trimesh_shape()}
			world.add_terrain_tile(ground,tiles[index],terrain_material);committed+=1
		2:world._shared_water();world.begin_foliage();phase=3;cursor=0
		3:
			var entries:Array=model.layout.data.get("trees",[])
			if cursor<entries.size():world.add_foliage_tree(entries[cursor]);cursor+=1
			else:groups=world.foliage_groups.keys();cursor=0;phase=4
		4:
			if cursor<groups.size():world.add_foliage_group(groups[cursor]);cursor+=1
			else:cursor=0;phase=5
		5:
			var rocks:Array=model.layout.data.get("rocks",[])
			if cursor<rocks.size():
				var rock=resources["res://addons/golfminus/assets/models/schist.glb"].instantiate();world.add_child(rock)
				rock.position=Vector3(rocks[cursor][0],0,rocks[cursor][1]);world.ground_prop(rock)
				prop_meshes.append_array(rock.find_children("*","MeshInstance3D",true,false));cursor+=1
			else:
				var pavilion:Node3D=world.add_pavilion();prop_meshes.append_array(pavilion.find_children("*","MeshInstance3D",true,false));cursor=0;phase=6
		6:
			if cursor<prop_meshes.size():world.prop_mesh_collision(prop_meshes[cursor]);cursor+=1
			else:cursor=0;phase=7
		7:
			if cursor<model.course.holes.size():world.add_hole(cursor);cursor+=1
			else:world.select_hole();phase=8
		8:_finish(true)
	return true
func _finish(success:bool)->void:
	done=true;set_process(false)
	metrics={"course":course_id,"cache_hit":cache_hit,"tiles":committed,"workers":worker_count,"cancelled":cancelled,"error":error,"peak_step_ms":peak_step_usec/1000.0,"peak_frame_work_ms":peak_frame_work_usec/1000.0,"elapsed_ms":(Time.get_ticks_usec()-started_usec)/1000.0}
	preload("res://scripts/client_diagnostics.gd").stage("golf_prepare",started_usec,metrics)
	if not success and is_instance_valid(world):world.queue_free();world=null
	finished.emit(world if success else null)
func _exit_tree()->void:
	# Only shutdown joins unfinished work. Workers own no nodes and check cancel
	# before/after a tile, so a cancelled group drains without building the rest.
	if job!=null:job.cancel()
	if task>=0:WorkerThreadPool.wait_for_group_task_completion(task);task=-1
	# Balance threaded resource requests even when the application closes before
	# polling them. Only shutdown is allowed to block on remaining requests.
	for path in requested:ResourceLoader.load_threaded_get(path)
	requested.clear()
	if not done:
		done=true;cancelled=true;finished.emit(null)
