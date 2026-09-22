extends RefCounted
## Fits the golf implement without changing the host's tracking or controller calibration.
static func solve(grip:Transform3D,ball:Vector3,aim:Vector3,length:float)->Dictionary:
	if not grip.origin.is_finite() or not grip.basis.is_finite() or absf(grip.basis.determinant())<.01 or not ball.is_finite() or not aim.is_finite() or aim.length()<.01 or not is_finite(length) or length<=0:return {}
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
static func clearance(pose:Transform3D,shape:RefCounted,ground:Callable)->float:
	var lowest:=INF
	for vertex in shape.surface_points:
		var point:Vector3=pose*vertex
		lowest=minf(lowest,point.y-float(ground.call(point.x,point.z)))
	return lowest

static func head_pose(grip:Transform3D,fit:Dictionary,length:float,shape:RefCounted)->Transform3D:
	var basis:Basis=grip.basis.orthonormalized()*Basis.from_euler(fit.rotation*PI/180.0)
	return Transform3D(basis*Basis.from_euler(fit.get("head_rotation",Vector3.ZERO)*PI/180.0)*Basis(Vector3.RIGHT,shape.loft),grip.origin+basis*Vector3(.055,-length,0)*float(fit.reach))

static func solve_grounded(grip:Transform3D,ball:Vector3,aim:Vector3,length:float,shape:RefCounted,ground:Callable)->Dictionary:
	# Keep the entire mesh above the terrain, including the back of lofted wedges.
	var target_ball:=ball
	var fit:Dictionary={}
	for attempt in 12:
		fit=solve(grip,target_ball,aim,length)
		if fit.is_empty():return {}
		# Fit shaft reach independently of face loft: natural hand lean must not
		# turn a driver's intended launch face down into the turf.
		var forward:=Vector3(aim.x,0,aim.z).normalized()
		var upright:=Basis(forward.cross(Vector3.UP),Vector3.UP,-forward)
		var shaft:Basis=grip.basis.orthonormalized()*Basis.from_euler(fit.rotation*PI/180.0)
		fit.head_rotation=(shaft.inverse()*upright).get_euler()*180.0/PI
		var pose:=head_pose(grip,fit,length,shape)
		var gap:=clearance(pose,shape,ground)
		if not is_finite(gap):return {}
		if absf(gap-SOLE_CLEARANCE)<.0005:
			fit.capture_grip=grip
			fit.clearance=gap
			return fit
		target_ball.y+=SOLE_CLEARANCE-gap
	return {}
