extends SceneTree
const Loader=preload("res://addons/golfminus/scripts/golf/course_loader.gd")
const World=preload("res://addons/golfminus/scripts/world/connected_course_world.gd")
const Job=preload("res://addons/golfminus/scripts/world/terrain_job.gd")
class MissingAssetLoader extends "res://addons/golfminus/scripts/golf/course_loader.gd":
	func asset_paths()->Array[String]:return ["res://missing_course_test_asset.tres"]
var failures:Array=[]
var frames:=0
var previous_usec:=0
var peak_frame_ms:=0.0
func check(ok:bool,label:String)->void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize()->void:
	process_frame.connect(func():
		frames+=1
		var now:=Time.get_ticks_usec()
		if previous_usec>0:peak_frame_ms=maxf(peak_frame_ms,(now-previous_usec)/1000.0)
		previous_usec=now)
	run.call_deferred()
func until(predicate:Callable)->bool:
	var deadline:=Time.get_ticks_msec()+20000
	while not predicate.call() and Time.get_ticks_msec()<deadline:await process_frame
	return predicate.call()
func run()->void:
	var host=load("res://scenes/main.tscn").instantiate();root.add_child(host)
	await create_timer(.3).timeout
	var a=host.golf_activity
	var original:String=host.current_location
	var rig_ids:=[host.motor.get_instance_id(),host.head.get_instance_id(),host.avatar.get_instance_id()]
	World.mesh_cache.clear()
	var start:=Time.get_ticks_usec();a.join_course("cypress")
	check(Time.get_ticks_usec()-start<250000,"Starting a load returns promptly")
	check(not a.active and a.loading_course=="cypress" and a.cancel_load_button.visible,"Fishing remains active with cancellable course progress")
	var first=a.pending_loader;var initial_frames:=frames
	check(await until(func():return first.committed>=8),"Terrain arrives incrementally from workers")
	check(frames>initial_frames+5 and host.current_location==original,"Main loop and fishing location survive preparation")
	var isolated:bool=not first.world.visible
	for body in first.world.find_children("*","CollisionObject3D",true,false):isolated=isolated and body.collision_layer==0 and body.collision_mask==0
	check(isolated,"Prepared terrain is hidden and cannot collide with fishing")
	a.cancel_load_button.pressed.emit()
	var first_ref:WeakRef=weakref(first)
	check(await until(func():return first_ref.get_ref()==null or first_ref.get_ref().done),"Cancellation drains worker tasks asynchronously")
	await process_frame
	check(not a.active and a.loading_course.is_empty() and World.mesh_cache.is_empty(),"Cancelled partial terrain never activates or enters the cache")
	a.join_course("cypress");await process_frame
	var stale=a.pending_loader
	a.join_course("poppy")
	check(await until(func():return a.active),"Replacement course finishes loading")
	check(a.golf.course_id=="poppy" and (not is_instance_valid(stale) or stale.done),"Stale completion cannot replace the latest course selection")
	check(rig_ids==[host.motor.get_instance_id(),host.head.get_instance_id(),host.avatar.get_instance_id()],"Transfer preserves rig, head and avatar identities")
	var course_world=a.golf.world
	check(course_world.visible and not course_world.staging and course_world.staged_collisions.is_empty(),"Ready course is activated once")
	check(course_world.hole_markers.size()==18,"All hole markers are ready before transfer")
	check(World.mesh_cache.size()==1,"First entry builds only the selected course, without default Spyglass")
	var m=a.golf.model
	var key:String=JSON.stringify(m.course).sha256_text();var tiles:Array=World.mesh_cache[key]
	var origins:Array[Vector2]=[];var bounds:Rect2=m.course_bounds()
	for z in range(floori(bounds.position.y/96),ceili(bounds.end.y/96)):
		for x in range(floori(bounds.position.x/96),ceili(bounds.end.x/96)):origins.append(Vector2(x*96,z*96))
	var equal_tiles:=true
	for i in tiles.size():
		var expected:=ArrayMesh.new();expected.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,Job.tile_arrays(m,origins[i]))
		var expected_arrays:Array=expected.surface_get_arrays(0);var actual:Array=tiles[i].mesh.surface_get_arrays(0)
		for field in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_INDEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_TANGENT,Mesh.ARRAY_COLOR,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_TEX_UV2]:equal_tiles=equal_tiles and expected_arrays[field]==actual[field]
	check(equal_tiles,"Every concurrent tile equals sequential geometry, normals, tangents and lies")
	await physics_frame;await physics_frame
	var tee:Vector3=m.tee()
	var hit:Dictionary=course_world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(tee+Vector3.UP*20,tee-Vector3.UP*5,1))
	check(not hit.is_empty() and absf(hit.position.y-course_world.surface_height(tee.x,tee.z))<.025,"Activated collision agrees with the playable terrain height")
	var cold_metrics:Dictionary=a.last_load_metrics.duplicate()
	a.leave();await process_frame
	check(host.current_location==original and not a.active,"Return to fishing restores the original location")
	await a.join_course("poppy")
	check(a.last_load_metrics.cache_hit,"Warm return uses completed mesh/shape cache")
	a.leave();await process_frame
	var missing:=MissingAssetLoader.new();root.add_child(missing);missing.start("poppy")
	var failed:Node3D=await missing.finished
	check(failed==null and not missing.error.is_empty() and not a.active,"Missing resources fail safely without changing the live activity")
	missing.queue_free();await process_frame
	host.set_process(false);host.casting=true
	await a.join_course("poppy")
	check(not a.active and host.current_location==original,"A cast begun before transfer is never silently discarded")
	host.casting=false;host.set_process(true)
	a.join_course("cypress");await process_frame
	a.leave()
	check(await until(func():return a.get_child_count()<=1),"Return to fishing drains a pending load and its resources")
	check(not a.active and a.loading_course.is_empty(),"Leaving during preparation cancels activation")
	await a.join_course("not-a-course")
	check(not a.active and a.pending_loader==null,"Invalid course selection is rejected")
	# Mirror the normal quit path's audio stop before tearing down scene nodes.
	host.ambience.stop()
	a.join_course("cypress");await process_frame
	host.queue_free();await process_frame;await create_timer(.15).timeout
	check(true,"Shutdown with pending workers completes")
	print("GOLF_LOADING_RESULT ",JSON.stringify({"failures":failures,"frames":frames,"peak_frame_ms":peak_frame_ms,"cold_load":cold_metrics}))
	quit(0 if failures.is_empty() else 1)
