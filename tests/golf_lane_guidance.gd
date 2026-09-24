extends SceneTree
const Model=preload("res://addons/golfminus/scripts/golf/course_model.gd")
var failures:Array[String]=[]
var checked:=0
class LaneFixture extends Model:
	var hazard:="rough"
	func lie(x:float,z:float)->String:
		return hazard if absf(x)<1.0 and z<=-2.0 and z>=-3.0 else "fairway"
	func height(_x:float,_z:float)->float:return 0.0
	func pin()->Vector3:return Vector3(0,0,-5)
func check(ok:bool,label:String)->void:
	checked+=1
	if not ok:failures.append(label);push_error(label)
func _initialize()->void:
	var fixture:=LaneFixture.new()
	fixture.hole={"routing":{"play_path":[[0,0],[4,0],[4,-5],[0,-5]]}}
	for hazard in ["rough","sand","water","out"]:
		fixture.hazard=hazard
		check(not fixture.guide_clear(Vector3.ZERO,fixture.pin()),hazard+" blocks direct pin aim")
		var length:float=fixture.guide_length(Vector3.ZERO,Vector3.FORWARD)
		check(length>1.7 and length<2.0,hazard+" clips the guide before its boundary")
		var target:Vector3=fixture.guide_target(Vector3.ZERO)
		check(target.x>1.0 and fixture.guide_clear(Vector3.ZERO,target),hazard+" routes aim around the dogleg")
		check(fixture.guide_length(Vector3(0,0,-2.5),Vector3.RIGHT)==0,hazard+" hides guide outside lane")
	fixture.hazard="fairway"
	check(is_equal_approx(fixture.guide_length(Vector3.ZERO,Vector3.FORWARD),5.4),"Clear lane retains full guide length")
	check(fixture.guide_target(Vector3.ZERO)==fixture.pin(),"Clear shot aims directly at pin")
	for id in ["spyglass","pebble","cypress","poppy"]:
		var m:=Model.new();m.load_course(id)
		for hole in 18:
			m.load_course(id,hole)
			for tee in ["back","club","forward"]:
				var p:Vector3=m.tee(tee);var target:Vector3=m.guide_target(p)
				check(Vector2(p.x,p.z).distance_to(Vector2(target.x,target.z))>1.0,"%s %d %s advances"%[id,hole,tee])
				check(m.guide_clear(p,target),"%s %d %s aims along playable terrain"%[id,hole,tee])
			var path:Array=m.hole.routing.play_path
			for i in range(1,path.size(),maxi(1,path.size()/4)):
				var p:=Vector3(path[i-1][0],0,path[i-1][1]).lerp(Vector3(path[i][0],0,path[i][1]),.5)
				var target:Vector3=m.guide_target(p)
				check(m.guide_clear(p,target),"%s %d route midpoint has safe aim"%[id,hole])
				for direction in [Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]:
					var length:float=m.guide_length(p,direction)
					check(m.guide_clear(p,p+direction*length),"Guide stops before lane edge")
			var pin:Vector3=m.pin()
			check(m.guide_target(pin+Vector3(.25,0,0)).distance_to(pin)<.001,"Nearby clear putt points at cup")
		var outside:=Vector3(m.course_bounds().end.x+5,0,m.course_bounds().end.y+5)
		check(m.guide_length(outside,Vector3.FORWARD)==0,"Out-of-bounds guide is hidden")
		print("GUIDANCE checked ",id)
	print("GOLF_LANE_GUIDANCE_RESULT ",JSON.stringify({"checks":checked,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
