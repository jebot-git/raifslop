extends RefCounted
## Deterministic rolling ball. Small fixed substeps prevent rail/obstacle tunnelling.
const RADIUS:=.021335
const CUP_RADIUS:=.065
const MAX_SPEED:=8.0
const STEP:=1.0/360.0
const Catalog=preload("res://scripts/minigolf/catalog.gd")
var layout:Dictionary={}
var position:=Vector2.ZERO
var velocity:=Vector2.ZERO
var last_safe:=Vector2.ZERO
var moving:=false
var holed:=false
var elapsed:=0.0
var accumulator:=0.0
var result:=""
func reset(hole:Dictionary)->void:
	layout=hole;position=Catalog.point(hole.tee);last_safe=position;velocity=Vector2.ZERO;moving=false;holed=false;elapsed=0;accumulator=0;result=""
func strike(impulse:Vector2)->bool:
	if moving or holed or not impulse.is_finite() or impulse.length()<.04:return false
	last_safe=position;velocity=impulse.limit_length(MAX_SPEED);moving=true;elapsed=0;result="";accumulator=0
	return true
func height(at:Vector2)->float:
	var y:=0.0
	for bump in layout.get("bumps",[]):
		var axes:=Catalog.point(bump.get("axes",[bump.radius,bump.radius]))
		var offset:=(at-Catalog.point(bump.center))/axes
		var d2:=offset.length_squared()
		if d2<1:y+=float(bump.height)*pow(1-d2,2)
	for ramp in layout.get("ramps",[]):
		var t:=clampf((-at.y-float(ramp.start))/(float(ramp.end)-float(ramp.start)),0,1)
		y+=float(ramp.height)*t*t*(3-2*t)
	return y
func gradient(at:Vector2)->Vector2:
	var g:=Vector2.ZERO
	for bump in layout.get("bumps",[]):
		var axes:=Catalog.point(bump.get("axes",[bump.radius,bump.radius]))
		var offset:=at-Catalog.point(bump.center)
		var d2:=(offset/axes).length_squared()
		if d2<1:g+=-4*float(bump.height)*(1-d2)*offset/(axes*axes)
	for ramp in layout.get("ramps",[]):
		var span:float=float(ramp.end)-float(ramp.start)
		var t:=clampf((-at.y-float(ramp.start))/span,0,1)
		g.y-=float(ramp.height)*6*t*(1-t)/span
	return g
func tick(dt:float)->String:
	if not moving:return ""
	accumulator+=clampf(dt,0,.1)
	while accumulator>=STEP and moving:
		accumulator-=STEP;_step(STEP)
	return result if not moving else ""
func _step(dt:float)->void:
	elapsed+=dt
	var slope:=-gradient(position)*9.81*5.0/7.0
	velocity+=slope*dt
	velocity=velocity.move_toward(Vector2.ZERO,.32*dt)
	position+=velocity*dt
	var half:float=float(layout.width)/2-RADIUS
	var far:float=-float(layout.length)+RADIUS
	if absf(position.x)>half:
		position.x=clampf(position.x,-half,half);velocity.x=-velocity.x*.8
	if position.y> -RADIUS or position.y<far:
		position.y=clampf(position.y,far,-RADIUS);velocity.y=-velocity.y*.8
	for obstacle in layout.obstacles:
		var offset:=position-Catalog.point(obstacle.center)
		var radius:float=float(obstacle.radius)+RADIUS
		if offset.length_squared()<radius*radius:
			var normal:=offset.normalized() if offset.length()>.0001 else Vector2.RIGHT
			position=Catalog.point(obstacle.center)+normal*radius
			if velocity.dot(normal)<0:velocity=velocity.bounce(normal)*.82
	for rail in layout.get("rails",[]):
		var a:=Catalog.point(rail.a);var b:=Catalog.point(rail.b)
		var nearest:=Geometry2D.get_closest_point_to_segment(position,a,b)
		var offset:=position-nearest;var radius:float=float(rail.radius)+RADIUS
		if offset.length_squared()<radius*radius:
			var normal:=offset.normalized() if offset.length()>.00001 else (b-a).orthogonal().normalized()
			position=nearest+normal*radius
			if velocity.dot(normal)<0:velocity=velocity.bounce(normal)*.8
	for hazard in layout.hazards:
		var size:=Catalog.point(hazard.size)
		if Rect2(Catalog.point(hazard.center)-size/2,size).has_point(position):
			position=last_safe;_stop("hazard");return
	var cup:=Catalog.point(layout.cup)
	var distance:=position.distance_to(cup)
	# Fast putts roll over the cup; slow entries fall in without a magnetic assist.
	if distance<CUP_RADIUS-RADIUS*.45 and velocity.length()<1.25:
		position=cup;holed=true;_stop("holed");return
	if (velocity.length()<.035 and slope.length()<.32) or elapsed>35:_stop("rest")
func _stop(reason:String)->void:
	velocity=Vector2.ZERO;moving=false;result=reason
