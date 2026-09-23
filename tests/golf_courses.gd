extends SceneTree
const Model=preload("res://addons/golfminus/scripts/golf/course_model.gd")
const Locations=preload("res://addons/golfminus/scripts/golf/host_locations.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if ok:print("PASS ",message)
	else:failures+=1;push_error(message)
func _initialize()->void:
	for id in ["spyglass","pebble","cypress","poppy"]:
		var m:=Model.new();m.load_course(id)
		check(m.connected and m.surface!=null and m.course.holes.size()==18,id+" has 18 mapped holes on one terrain")
		var greens:=true;var tees:=true;var independent:=true
		for i in 18:
			var pin:Vector3=m.pin_for(i);var at:Vector3=m.tee_for(i)
			greens=greens and m.lie(pin.x,pin.z)=="green"
			tees=tees and m.lie(at.x,at.z) in ["fairway","fringe","green"] and m.course_bounds().has_point(Vector2(at.x,at.z))
			var before:float=m.height(at.x,at.z);m.load_course(id,(i+1)%18)
			independent=independent and is_equal_approx(before,m.height(at.x,at.z))
		check(greens,id+" every pin lies on its mapped green")
		check(tees,id+" all tees are playable and inside shared bounds")
		check(independent,id+" terrain is independent of the scoring hole")
		check(Locations.same_world(Locations.location(id,0),Locations.location(id,17)),id+" different-hole players share visibility")
		check(Locations.same_world(Locations.location(id,5),Locations.clubhouse(id)),id+" clubhouse and BBQ share the course")
		check(not Locations.same_world(Locations.location(id,0),"lakeside"),id+" fishing stays a separate world")
		var safe_water:=true
		for water in m.course.layout.water_polygons:
			var p:Array=water.points[0]
			safe_water=safe_water and m.height(p[0],p[1])<=float(water.level)+.25
		check(safe_water,id+" water basins lie below their visible surfaces")
	var records={"tester":{"name":"Tester","golf":{}}}
	var record_api=load("res://addons/golfminus/scripts/golf/server_records.gd")
	var rules=load("res://addons/golfminus/scripts/golf/course_session.gd").new()
	for id in load("res://addons/golfminus/scripts/golf/catalog.gd").ALL:
		check(record_api.finish(records,"tester",id,[4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4]),id+" records retain independent course scores")
	check(record_api.valid(records.tester.golf),"All six current and legacy course records survive validation")
	for id in ["cypress","poppy"]:
		check(rules.command(id,id,"join",{"course":id},0),id+" accepted by authoritative course session")
		check(record_api.snapshot(records)[id].size()==1,id+" appears in server leaderboard snapshots")
		check(Locations.pose(Locations.clubhouse(id)).origin.is_finite(),id+" clubhouse and BBQ pose resolves on the server")
	print("REFERENCE COURSES %d/%d passed"%[checks-failures,checks]);quit(0 if failures==0 else 1)
