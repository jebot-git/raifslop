extends SceneTree
const Head=preload("res://addons/golfminus/scripts/golf/club_head.gd")
const Tracker=preload("res://addons/golfminus/scripts/golf/swing_tracker.gd")
const Clubs=preload("res://addons/golfminus/scripts/golf/clubs.gd")
var failures:Array=[]
func check(ok:bool,label:String)->void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize()->void:
	var rotation:=Basis.from_euler(Vector3(.4,.7,-.3))
	var centre:=Vector3(2,1,-3)
	for index in 8:
		var shape=Head.for_club(index)
		var vertices:PackedVector3Array=shape.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var same:bool=vertices.size()==shape.triangles.size()
		for i in range(0,vertices.size(),3):
			same=same and vertices[i].is_equal_approx(shape.triangles[i]) and vertices[i+1].is_equal_approx(shape.triangles[i+2]) and vertices[i+2].is_equal_approx(shape.triangles[i+1])
		check(same,"Rendered and collision triangles match for club "+str(index))
		for axis in [Vector3.FORWARD,Vector3.BACK,Vector3.LEFT,Vector3.RIGHT,Vector3.UP,Vector3.DOWN]:
			var direction:Vector3=rotation*axis
			var start:=Transform3D(rotation,centre-direction*.25)
			var finish:=Transform3D(rotation,centre+direction*.25)
			var contact:Dictionary=shape.sweep(start,finish,centre)
			var impact:Dictionary=Clubs.impact(index,direction*10,Vector3.FORWARD, "fairway",contact) if contact.has("normal") else {}
			check(not contact.is_empty() and not impact.is_empty() and impact.velocity.dot(direction)>.03,"Full head surface has physical contact: %d / %s"%[index,axis])
		var tracker:=Tracker.new()
		var start:=Transform3D(Basis.IDENTITY,Vector3(0,0,.15))
		for i in 24:tracker.sample_pose(start,shape,Vector3.ZERO,1.0/72,false)
		var armed:Dictionary=tracker.sample_pose(Transform3D(Basis.IDENTITY,Vector3(0,0,-.12)),shape,Vector3.ZERO,1.0/72,true)
		check(not armed.is_empty(),"Grip press can register the immediately following contact: "+str(index))
		tracker=Tracker.new()
		var ball:=Vector3(0,0,-shape.depth*.5-.015)
		for i in 24:tracker.sample_pose(Transform3D.IDENTITY,shape,ball,1.0/72,false)
		var resting:Dictionary=tracker.sample_pose(Transform3D.IDENTITY,shape,ball,1.0/72,true)
		check(resting.is_empty(),"Stationary touching head does not launch the ball: "+str(index))
		var push:Dictionary=tracker.sample_pose(Transform3D(Basis.IDENTITY,Vector3(0,0,-.01)),shape,ball,1.0/72,true)
		check(not push.is_empty(),"A moving head can push from existing surface contact: "+str(index))
		tracker=Tracker.new()
		for i in 24:tracker.sample_pose(Transform3D.IDENTITY,shape,ball,1.0/72,false)
		tracker.sample_pose(Transform3D(Basis.IDENTITY,Vector3(0,0,.005)),shape,ball,.001,true)
		var reversed:Dictionary=tracker.sample_pose(Transform3D(Basis.IDENTITY,Vector3(0,0,.004)),shape,ball,.001,true)
		var response:Dictionary=Clubs.impact(index,reversed.velocity,reversed.normal,"fairway",reversed) if not reversed.is_empty() else {}
		check(not response.is_empty(),"Quick reversal retains a valid physical impulse despite filter history: "+str(index))
		tracker.reset()
		var jump:Dictionary=tracker.sample_pose(Transform3D(Basis.IDENTITY,Vector3(0,0,20)),shape,ball,.2,true)
		check(jump.is_empty(),"Tracking discontinuity cannot become a hit: "+str(index))
	print("GOLF_HEAD_CONTACT_RESULT ",failures);quit(0 if failures.is_empty() else 1)
