extends RefCounted
## Recent controller-only preparation can precede trigger-down. It establishes
## a backswing direction, never launch power or a completed cast.
const Sampler=preload("res://scripts/cast_pose_sampler.gd")
var sampler:=Sampler.new()
var history:Array[Dictionary]=[]
var age:=0.0
func clear()->void:
	history.clear();sampler.ready=false;age=0
func sample(pose:Transform3D,dt:float,tracked:bool)->void:
	var measured:=sampler.sample(pose,dt,tracked)
	if measured.is_empty():history.clear();age=0;return
	age+=dt
	history.append({"time":age,"tip":measured.tip})
	while history.size()>1 and age-float(history[0].time)>.6:history.pop_front()
func backswing()->Dictionary:
	if history.size()<6 or age-float(history[0].time)<.12:return {}
	var travel:Vector3=history[-1].tip-history[0].tip;travel.y=0
	var path:=0.0
	for i in range(1,history.size()):
		var step:Vector3=history[i].tip-history[i-1].tip;step.y=0;path+=step.length()
	# Reject stationary holds and a history containing opposing complete strokes.
	if travel.length()<.25 or travel.length()<path*.4:return {}
	return {"axis":-travel.normalized(),"back":travel}
