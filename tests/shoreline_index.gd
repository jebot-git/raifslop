extends SceneTree
const Boundary=preload("res://scripts/fish_water_boundary.gd")
var failures:=0
func check(ok:bool,message:String):
	if not ok:failures+=1;push_error(message)
func _initialize():run.call_deferred()
func brute(faces:Array,start:Vector3,end:Vector3)->bool:
	for f in faces:
		if Geometry3D.segment_intersects_triangle(start,end,f[0],f[1],f[2])!=null:return true
	return false
func run():
	var g=load("res://scenes/main.tscn").instantiate();root.add_child(g);await process_frame
	g.set_process(false);g.motor.set_physics_process(false)
	var rng:=RandomNumberGenerator.new();rng.seed=2718
	for id in ["lakeside","simons_town_rocks","meadow_bend"]:
		g.game.reset();g.casting=false
		check(g._select_location(id,false),"Select shoreline fixture")
		var boundary=g.cast_water_boundary
		var native=boundary.native
		for i in 150:
			var start:=Vector3(rng.randf_range(-25,25),rng.randf_range(-1,3),rng.randf_range(-25,10))
			var end:=Vector3(rng.randf_range(-25,25),rng.randf_range(-1,3),rng.randf_range(-25,10))
			if i%5==0:end=start+Vector3.DOWN*5
			var expected:=brute(boundary.ground_faces,start,end)
			check(boundary.segment_obstructed(start,end)==expected,"Native authored geometry parity "+id)
			boundary.native=null
			check(boundary.segment_obstructed(start,end)==expected,"Fallback indexed geometry parity "+id)
			boundary.native=native
		var layout:Array=g.game.population.layouts[id].duplicate()
		# Recreate the original exhaustive implementation, then compare all nine
		# selected sectors, including geometry-height changes during placement.
		var original=load("res://tests/shoreline_reference.gd")
		var fast=g.cast_water_boundary
		var reference=original.new();reference.ground_faces=fast.ground_faces
		# Only the visibility predicate changes; projected blocked queries stay indexed.
		reference.triangles=fast.triangles;reference.bounds=fast.bounds;reference.cells=fast.cells
		g.cast_water_boundary=reference
		g._configure_fishing_grid(id)
		check(g.game.population.layouts[id]==layout,"Every fishing sector unchanged "+id)
		g.cast_water_boundary=fast
	g.free();print("SHORELINE_INDEX failures=",failures);quit(1 if failures else 0)
