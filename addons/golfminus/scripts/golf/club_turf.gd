extends RefCounted
## Dissipative work against terrain before ball contact. SI units.
## Depth-proportional cutting resistance is an initial engineering model,
## not measured agronomy. Tracked poses stay authoritative; only impact energy
## is reduced because software cannot physically stop a player's controller.
const STIFFNESS:={"green":600.0,"fringe":800.0,"fairway":1000.0,"rough":1800.0,"sand":2600.0}
var work_j:=0.0
var distance_m:=0.0
var max_depth_m:=0.0
var last_surface:=""
var air_time:=0.0
var direction:=Vector3.ZERO
var support_direction:=Vector3.ZERO
var support_vertex:=Vector3.ZERO
var support_shape:RefCounted
func reset()->void:
	work_j=0;distance_m=0;max_depth_m=0;last_surface="";air_time=0;direction=Vector3.ZERO
func sweep(start:Transform3D,finish:Transform3D,shape:RefCounted,terrain:RefCounted,dt:float,fraction:float,raw:Vector3)->Dictionary:
	var event:Dictionary={}
	if terrain==null:reset();return {}
	# Backswing and forward swing must not share stored losses.
	if raw.length()>.2 and direction.dot(raw.normalized())<-.25:reset()
	if raw.length()>.2:direction=raw.normalized()
	var end:=start.interpolate_with(finish,clampf(fraction,0,1))
	var angle:=start.basis.get_rotation_quaternion().angle_to(end.basis.get_rotation_quaternion())
	var radius:float=shape.radius
	var path:=start.origin.distance_to(end.origin)+angle*radius
	if path<.000001:
		air_time+=dt*fraction
		if air_time>.12:reset()
		return {}
	# Spatial quadrature makes resistance independent of headset cadence.
	var steps:=maxi(1,ceili(path/.005))
	var previous:=start
	for i in steps:
		var next:=start.interpolate_with(end,float(i+1)/steps)
		var pose:=previous.interpolate_with(next,.5)
		# Find the mesh support point against the local terrain plane. Reuse it
		# until the plane/head changes by 0.1 degree (under 0.2 mm on these heads).
		# Query actual height at that vertex so terrain seams still affect depth.
		var normal:Vector3=terrain.normal_at(pose.origin.x,pose.origin.z)
		var local_normal:=pose.basis.transposed()*normal
		if support_shape!=shape or support_direction.distance_squared_to(local_normal)>.000003:
			support_shape=shape;support_direction=local_normal
			var lowest:=INF
			for vertex in shape.surface_points:
				var projection:float=vertex.dot(local_normal)
				if projection<lowest:lowest=projection;support_vertex=vertex
		var contact:Vector3=pose*support_vertex
		var depth:float=maxf(0,terrain.height(contact.x,contact.z)-contact.y)
		if depth>0:
			var surface:String=terrain.lie(contact.x,contact.z)
			var ds:=path/steps
			var work:=float(STIFFNESS.get(surface,1800.0))*depth*ds
			work_j+=work
			var frame_work:float=float(event.get("work_j",0))+work
			if depth>float(event.get("depth_m",0)):
				event={"position":Vector3(contact.x,contact.y+depth,contact.z),"normal":normal,"surface":surface,"depth_m":depth,"velocity":raw}
			event.work_j=frame_work
			distance_m+=ds;max_depth_m=maxf(max_depth_m,depth);last_surface=surface;air_time=0
		else:
			air_time+=dt*fraction/steps
			if air_time>.12:reset()
		previous=next
	return event
func attenuate(linear:Vector3,angular:Vector3,shape:RefCounted,basis:Basis)->Dictionary:
	var local:=basis.transposed()*angular
	var energy:float=.5*shape.mass*linear.length_squared()+.5*local.dot(shape.inertia*local)
	var loss:=minf(work_j,energy)
	var scale:=sqrt(maxf(0,1.0-loss/energy)) if energy>0 else 0.0
	return {"work_j":loss,"requested_work_j":work_j,"speed_scale":scale,"distance_m":distance_m,"max_depth_m":max_depth_m,"surface":last_surface,"incoming_energy_j":energy}
