extends RefCounted
## Solves length-only adjustments and controller-to-address attachment fitting.
const SOLE_CLEARANCE:=.004
static func ground_normal(at:Vector3,ground:Callable)->Vector3:
	var e:=.05
	return Vector3(float(ground.call(at.x-e,at.z))-float(ground.call(at.x+e,at.z)),2*e,float(ground.call(at.x,at.z-e))-float(ground.call(at.x,at.z+e))).normalized()
static func clearance(pose:Transform3D,shape:RefCounted,ground:Callable)->float:
	var lowest:=INF
	for vertex in shape.surface_points:
		var point:Vector3=pose*vertex
		lowest=minf(lowest,point.y-float(ground.call(point.x,point.z)))
	return lowest

static func head_pose(grip:Transform3D,fit:Dictionary,length:float,shape:RefCounted)->Transform3D:
	var shaft:Basis=grip.basis.orthonormalized()*Basis.from_euler(fit.rotation*PI/180.0)
	var head:Basis=grip.basis.orthonormalized()*Basis.from_euler(fit.get("head_rotation",Vector3.ZERO)*PI/180.0)*Basis(Vector3.RIGHT,shape.loft)
	# The shaft ends at the hosel; head dimensions never scale with reach.
	return Transform3D(head,grip.origin-shaft.y*length*float(fit.reach)+head.x*.055)

static func solve_grounded(grip:Transform3D,ball:Vector3,aim:Vector3,length:float,shape:RefCounted,ground:Callable,head_rotation:=Vector3.ZERO,shaft_rotation:=Vector3.ZERO)->Dictionary:
	if not grip.is_finite() or absf(grip.basis.determinant())<.01 or not ball.is_finite() or not aim.is_finite() or not is_finite(length) or length<=0:return {}
	if not head_rotation.is_finite() or not shaft_rotation.is_finite():return {}
	# Capture the controller-relative attachment unchanged. The ball and aim
	# never steer the handle: only solve distance along its existing axis.
	var shaft:=grip.basis.orthonormalized()*Basis.from_euler(shaft_rotation*PI/180)
	if (-shaft.y).dot(Vector3.DOWN)<.15:return {}
	var fit:Dictionary={"reach":.35,"rotation":shaft_rotation,"head_rotation":head_rotation,"capture_grip":grip}
	var short_gap:=clearance(head_pose(grip,fit,length,shape),shape,ground)
	fit.reach=1.6
	var long_gap:=clearance(head_pose(grip,fit,length,shape),shape,ground)
	if not is_finite(short_gap) or not is_finite(long_gap) or short_gap<SOLE_CLEARANCE or long_gap>SOLE_CLEARANCE:return {}
	var low:=.35;var high:=1.6
	for attempt in 24:
		fit.reach=(low+high)*.5
		var pose:=head_pose(grip,fit,length,shape)
		var gap:=clearance(pose,shape,ground)
		if not is_finite(gap):return {}
		if absf(gap-SOLE_CLEARANCE)<.0001:
			fit.target=pose.origin;fit.clearance=gap;return fit
		if gap>SOLE_CLEARANCE:low=fit.reach
		else:high=fit.reach
	return {}

static func solve_address(grip:Transform3D,ball:Vector3,aim:Vector3,length:float,shape:RefCounted,ground:Callable,head_rotation:Vector3,shaft_rotation:Vector3,pose_rotation:Vector3)->Dictionary:
	if not grip.is_finite() or absf(grip.basis.determinant())<.01 or not ball.is_finite() or not aim.is_finite() or not head_rotation.is_finite() or not pose_rotation.is_finite():return {}
	var up:=ground_normal(ball,ground)
	var forward:=aim-up*aim.dot(up)
	if not up.is_finite() or forward.length_squared()<.01:return {}
	forward=forward.normalized()
	# Establish an address frame with the selected club's authored loft.
	# The captured controller offset holds the face steady while the handle
	# independently connects the hand to the address position.
	var address:=Basis(forward.cross(up).normalized(),up,-forward)
	var desired_grip:=address*Basis.from_euler(head_rotation*PI/180).inverse()
	var head:=address*Basis(Vector3.RIGHT,shape.loft)
	var horizontal:=Vector3(aim.x,0,aim.z).normalized()
	if horizontal.length_squared()<.5 or not is_finite(length) or length<=0 or not shaft_rotation.is_finite():return {}
	# Keep the entire head behind the ball, with a small gap even for a driver.
	var front_extent:=0.0
	for vertex in shape.surface_points:front_extent=maxf(front_extent,(head*vertex).dot(horizontal))
	var target:=ball-horizontal*maxf(.075,front_extent+shape.BALL_RADIUS+.01)
	target.y=float(ground.call(target.x,target.z))
	var gap:=clearance(Transform3D(head,target),shape,ground)
	if not is_finite(gap):return {}
	target.y+=SOLE_CLEARANCE-gap
	# Fit the handle from the actual hand to the fixed hosel. Head orientation
	# stays in its address frame; tilting the shaft must not tilt the face.
	var to_grip:=grip.origin-(target-head.x*.055)
	var reach:=to_grip.length()/length
	if not is_finite(reach) or reach<.35 or reach>1.6 or to_grip.y<=0:return {}
	var original_shaft:=desired_grip*Basis.from_euler(shaft_rotation*PI/180)
	var shaft:=Basis(Quaternion(original_shaft.y.normalized(),to_grip.normalized()))*original_shaft
	var fit:Dictionary={"reach":reach,"rotation":(desired_grip.inverse()*shaft).get_euler()*180/PI,"head_rotation":head_rotation,"capture_grip":Transform3D(desired_grip,grip.origin),"target":target,"clearance":SOLE_CLEARANCE}
	var correction:=grip.basis.orthonormalized().inverse()*desired_grip
	fit.pose_rotation=(Basis.from_euler(pose_rotation*PI/180)*correction).orthonormalized().get_euler()*180/PI
	fit.controller_grip=grip
	return fit
