extends SceneTree
const World=preload("res://addons/golfminus/scripts/world/connected_course_world.gd")
const Ball=preload("res://addons/golfminus/scripts/golf/ball_physics.gd")
class Ground extends RefCounted:
	var slope:=0.0
	func height(x:float,_z:float)->float:return x*slope
	func normal_at(_x:float,_z:float)->Vector3:return Vector3(-slope,1,0).normalized()
	func lie(_x:float,_z:float)->String:return "fairway"
	func wind()->Vector3:return Vector3.ZERO
	func pin()->Vector3:return Vector3(100,0,100)
var failures:Array=[]
func check(ok:bool,label:String)->void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize()->void:run.call_deferred()
func run()->void:
	for size in [.7,1.0,1.6]:
		for slope in [-.3,0.0,.3]:
			var ground:=Ground.new();ground.slope=slope
			var world:=World.new();world.model=ground;root.add_child(world);world.add_foliage_tree([0.0,0.0,size])
			await physics_frame;await physics_frame
			var radius:float=.3*size
			for x in [0.0,radius*.5,radius-.01,radius+Ball.RADIUS*.5]:
				var y:float=ground.height(x,0)+Ball.RADIUS
				var hit:=world.sweep_ball(Vector3(x,y,-1),Vector3(x,y,1))
				check(not hit.is_empty(),"Ground-level finite-radius trunk hit %s/%s/%s"%[size,slope,x])
			var miss:=world.sweep_ball(Vector3(radius+Ball.RADIUS+.01,1,-1),Vector3(radius+Ball.RADIUS+.01,1,1))
			check(miss.is_empty(),"Clearance outside sphere radius is a genuine miss")
			var overlap:=world.sweep_ball(Vector3(0,1,0),Vector3(0,1,.01))
			check(not overlap.is_empty() and Vector2(overlap.center.x,overlap.center.z).length()>=radius+Ball.RADIUS-.002,"Initial overlap recovers outside trunk")
			for speed in [1.0,80.0]:
				var ball:=Ball.new();ball.model=ground;ball.collision_query=world.sweep_ball
				ball.place(Vector3(radius*.65,ground.height(radius*.65,0)+Ball.RADIUS,-sqrt(pow(radius+Ball.RADIUS,2)-pow(radius*.65,2))-.04));ball.launch(Vector3(0,0,speed),Vector3.ZERO)
				var hit_seen:=false;var safe:=true
				for i in 100:
					ball.step(1.0/72)
					if absf(ball.velocity.x)>.01:hit_seen=true
					safe=safe and Vector2(ball.position.x,ball.position.z).length()>=radius+Ball.RADIUS-.003
				check(safe and hit_seen,"Rolling/fast glancing ball stays outside trunk %s/%s/%s"%[size,slope,speed])
			world.queue_free();await process_frame
	print("GOLF_TREE_COLLISION_RESULT ",failures);quit(0 if failures.is_empty() else 1)
