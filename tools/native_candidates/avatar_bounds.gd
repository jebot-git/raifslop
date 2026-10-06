extends SceneTree
## Uncached skinned bounds only; importing/decoding is outside timed samples.
func _initialize():run.call_deferred()
func run():
	var library=preload("res://scripts/avatar_library.gd").new()
	var results: Array=[]
	for path in library.DEFAULTS:
		var model=library.load_model(path)
		if model==null:push_error(library.error);quit(1);return
		var times: Array=[]
		var checksum:=Vector3.ZERO
		for i in 11:
			var start:=Time.get_ticks_usec()
			var bounds: AABB=preload("res://scripts/avatar_rest_bounds.gd").measure(model)
			if i>0:times.append(Time.get_ticks_usec()-start)
			checksum+=bounds.size
		times.sort()
		results.append({"model":path,"median_us":times[5],"max_us":times[-1],"checksum":str(checksum)})
		model.free();await process_frame
	print("BOUNDS_CANDIDATES ",JSON.stringify(results))
	await process_frame;quit()
