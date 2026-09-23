extends RefCounted
## Worker-owned CPU preparation. Never touches the scene tree, rendering or physics.
const TILE:=96.0
const STEP:=2.0
const COLORS=preload("res://addons/golfminus/scripts/world/course_world.gd").COLORS
var model:RefCounted
var origins:Array[Vector2]=[]
var order:Array[int]=[]
var mutex:=Mutex.new()
var cancelled:=false
var completed:=0
var ready:Array=[]
func cancel()->void:
	mutex.lock();cancelled=true;ready.clear();mutex.unlock()
func run_tile(task_index:int)->void:
	mutex.lock();var stop:=cancelled;mutex.unlock()
	if stop:return
	var index:int=order[task_index] if not order.is_empty() else task_index
	var arrays:=tile_arrays(model,origins[index])
	mutex.lock()
	if not cancelled:ready.append([index,arrays]);completed+=1
	mutex.unlock()
func take_ready()->Array:
	mutex.lock();var batch:=ready;ready=[];mutex.unlock();return batch
func completed_count()->int:
	mutex.lock();var count:=completed;mutex.unlock();return count
static func tile_arrays(model:RefCounted,origin:Vector2)->Array:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count:=int(TILE/STEP)
	for iz in count+1:
		for ix in count+1:
			var x:=origin.x+ix*STEP;var z:=origin.y+iz*STEP
			var lie:String=model.lie(x,z)
			var color:Color=COLORS[lie]
			if model.course.kind=="alpine" and lie=="rough":color=Color("58633e")
			if lie=="fairway":color=color.lightened(.055 if int(floor(z/9))%2==0 else 0)
			color.a=0.0 if lie=="sand" else .2 if lie=="green" else .5 if lie=="fairway" else 1.0
			st.set_color(color.srgb_to_linear());st.set_normal(model.normal_at(x,z));st.set_uv(Vector2(x,z));st.set_uv2(Vector2.ZERO)
			st.add_vertex(Vector3(x,model.height(x,z),z))
	for z in count:
		for x in count:
			var a:=z*(count+1)+x
			for i in [a,a+1,a+count+1,a+1,a+count+2,a+count+1]:st.add_index(i)
	st.generate_tangents();return st.commit_to_arrays()
