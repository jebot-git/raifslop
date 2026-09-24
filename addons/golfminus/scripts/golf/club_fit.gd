extends RefCounted
## Fits the golf implement without changing the host's tracking or controller calibration.
static func solve(grip:Transform3D,ball:Vector3,aim:Vector3,length:float)->Dictionary:
	if not grip.origin.is_finite() or not grip.basis.is_finite() or absf(grip.basis.determinant())<.01 or not ball.is_finite() or not aim.is_finite() or aim.length()<.01 or not is_finite(length) or not is_finite(length) or length<=0:return {}
	var target:=ball-aim.normalized()*.075
	var delta:=target-grip.origin
	var distance:=delta.length()
	var reach:=distance/sqrt(length*length+.055*.055)
	if reach<.35 or reach>1.6:return {}
	var up:Vector3=-delta.normalized()
	var face:Vector3=aim-up*aim.dot(up)
	if face.length()<.2:return {}
	face=face.normalized()
	var right:=face.cross(up).normalized()
	# The authored head centre is offset 55 mm from the shaft.
	var desired:=Basis(right,up,-face)*Basis(Vector3.BACK,-atan(.055/length))
	var adjustment:=grip.basis.orthonormalized().inverse()*desired
	return {"reach":reach,"rotation":adjustment.get_euler()*180.0/PI,"target":target}
static func address_direction(target:Vector3,view_forward:Vector3)->Vector3:
	var facing:=Vector3(view_forward.x,0,view_forward.z).normalized()
	var direction:=Vector3(target.x,0,target.z).normalized()
	# A pin behind the player must not force the face backwards during fitting.
	return -direction if facing.length()>.5 and direction.dot(facing)<-.25 else direction
static func flip_face(rotation_degrees:Vector3,length:float)->Vector3:
	# Rotate about grip-to-head, preserving the head centre as well as the grip.
	var axis:=Vector3(.055,-length,0).normalized()
	return (Basis.from_euler(rotation_degrees*PI/180.0)*Basis(axis,PI)).get_euler()*180.0/PI

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

static func solve_grounded(grip:Transform3D,ball:Vector3,aim:Vector3,length:float,shape:RefCounted,ground:Callable,head_rotation:=Vector3.ZERO)->Dictionary:
	if not grip.is_finite() or absf(grip.basis.determinant())<.01 or not ball.is_finite() or not aim.is_finite() or not is_finite(length) or length<=0:return {}
	if not head_rotation.is_finite():return {}
	var forward:=Vector3(aim.x,0,aim.z).normalized()
	if forward.length_squared()<.5:return {}
	# Fitting changes the handle only. Aim positions the head behind the ball;
	# it must never replace the user's controller-relative head orientation.
	var local_head:Vector3=head_rotation
	var head:Basis=grip.basis.orthonormalized()*Basis.from_euler(local_head*PI/180)*Basis(Vector3.RIGHT,shape.loft)
	var target:=ball-forward*.075
	for attempt in 12:
		var delta:=target-head.x*.055-grip.origin
		var reach:=delta.length()/length
		if reach<.35 or reach>1.6:return {}
		var up:Vector3=-delta.normalized()
		var face:Vector3=forward-up*forward.dot(up)
		if face.length()<.2:return {}
		face=face.normalized()
		var shaft:=Basis(face.cross(up).normalized(),up,-face)
		var fit:Dictionary={"reach":reach,"rotation":(grip.basis.orthonormalized().inverse()*shaft).get_euler()*180/PI,"head_rotation":local_head,"target":target,"capture_grip":grip}
		var gap:=clearance(head_pose(grip,fit,length,shape),shape,ground)
		if not is_finite(gap):return {}
		if absf(gap-SOLE_CLEARANCE)<.0005:
			fit.clearance=gap;return fit
		target.y+=SOLE_CLEARANCE-gap
	return {}
