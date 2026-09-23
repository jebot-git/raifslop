extends SceneTree
## Check the actual lie raster and canopy footprints, not just routed metadata.
const Model=preload("res://addons/golfminus/scripts/golf/course_model.gd")
var failures:Array[String]=[]
var samples:=0
func check(ok:bool,message:String)->void:
	if not ok:failures.append(message);push_error(message)
func point(p:Array)->Vector2:return Vector2(p[0],p[1])
func clean_core(model:RefCounted,path:Array)->bool:
	for i in range(1,path.size()):
		var a:=point(path[i-1]);var b:=point(path[i])
		for step in ceili(a.distance_to(b))+1:
			var at:=a.lerp(b,float(step)/maxi(1,ceili(a.distance_to(b))))
			for offset in [Vector2.ZERO,Vector2(2,0),Vector2(-2,0),Vector2(0,2),Vector2(0,-2),Vector2(1.414,1.414),Vector2(-1.414,1.414),Vector2(1.414,-1.414),Vector2(-1.414,-1.414)]:
				samples+=1
				if model.lie(at.x+offset.x,at.y+offset.y) not in ["fairway","fringe","green"]:return false
	return true
func distance_to_path(at:Vector2,path:Array)->float:
	var nearest:=INF
	for i in range(1,path.size()):
		nearest=minf(nearest,at.distance_to(Geometry2D.get_closest_point_to_segment(at,point(path[i-1]),point(path[i]))))
	return nearest
func _initialize()->void:
	for id in ["spyglass","pebble","cypress","poppy"]:
		var m:=Model.new();m.load_course(id)
		check(m.course.layout.has("play_lanes"),id+" contains baked play lanes")
		if not m.course.layout.has("play_lanes"):continue
		var paths:Array=[]
		for i in 18:
			var route:Dictionary=m.course.holes[i].routing
			var label:="%s hole %d"%[id,i+1]
			check(route.has("play_path") and route.has("tee_paths"),label+" has main and tee paths")
			if not route.has("play_path") or not route.has("tee_paths"):continue
			var main:Array=route.play_path
			check(point(main[0]).is_equal_approx(point(route.tees.back)) and point(main[-1]).is_equal_approx(point(route.pin)),label+" connects back tee to pin")
			check(clean_core(m,main),label+" has a continuous 4 m core without rough, sand or water")
			paths.append(main)
			for kind in ["club","forward"]:
				var branch:Array=route.tee_paths[kind]
				check(point(branch[0]).is_equal_approx(point(route.tees[kind])) and distance_to_path(point(branch[-1]),main)<.01,label+" "+kind+" tee joins the main lane")
				check(clean_core(m,branch),label+" "+kind+" connector has a clear core")
				paths.append(branch)
			var bounds:Rect2=m.layout.hole_bounds(m.course,i)
			for p in main:check(bounds.has_point(point(p)),label+" map includes the playing route")
		var canopy_clear:=true
		var radius:float=m.course.layout.play_lanes.preferred_width*.5
		for tree in m.course.layout.trees:
			for path in paths:
				if distance_to_path(point(tree),path)<=radius+3.75*float(tree[2])+2:canopy_clear=false
		check(canopy_clear,id+" tree canopies and collisions stay outside every playing lane")
		print("PLAY LANES checked ",id," 18 holes / 54 tees")
	print("GOLF_COURSE_LANES_RESULT ",JSON.stringify({"samples":samples,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
