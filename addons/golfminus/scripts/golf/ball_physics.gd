extends RefCounted
## SI units. Fixed substeps, drag, spin lift, impulse bounce and slope-aware rolling.
const MASS := .04593
const RADIUS := .021335
const AREA := PI*RADIUS*RADIUS
const GRAVITY := Vector3(0,-9.80665,0)
const SURFACES := {"green":[.25,.55],"fringe":[.30,.85],"fairway":[.42,1.8],"rough":[.23,2.5],"sand":[.10,4.5]}
var position := Vector3.ZERO
var velocity := Vector3.ZERO
var spin := Vector3.ZERO
var moving := false
var holed := false
var hazard := false
var air_time := 0.0
var carry := 0.0
var origin := Vector3.ZERO
var peak := 0.0
var grounded := false
var roll_distance:=0.0
var travel_distance:=0.0
var stop_reason:="placed"
var rest_time := 0.0
var model: RefCounted
var collision_query: Callable
func place(p: Vector3) -> void:
	roll_distance=0;travel_distance=0;stop_reason="placed"
	position=p; origin=p; velocity=Vector3.ZERO; spin=Vector3.ZERO
	moving=false; holed=false; hazard=false; grounded=true; rest_time=0; carry=0; peak=0; air_time=0
func launch(v: Vector3,w: Vector3) -> bool:
	if moving or holed or not v.is_finite() or not w.is_finite(): return false
	roll_distance=0;travel_distance=0;stop_reason="moving"
	velocity=v; spin=w; origin=position
	moving=true; grounded=false; rest_time=0; carry=0; peak=0; air_time=0
	return true
func acceleration(v: Vector3,w: Vector3,wind: Vector3) -> Vector3:
	var relative := v-wind
	var speed := relative.length()
	if speed<.01: return GRAVITY
	var ratio := RADIUS*w.length()/speed
	var cd := .23+.07*clampf(ratio,0,1)
	var lift := w.cross(relative).normalized()*.5*1.225*AREA*minf(.30,ratio*1.6)*speed*speed/MASS
	return GRAVITY-relative*(.5*1.225*AREA*cd*speed/MASS)+lift
func step(delta: float) -> void:
	if not moving: return
	var count := maxi(1,ceili(delta*360))
	var dt := delta/count
	for i in count:
		if not moving: break
		_substep(dt)
func _substep(dt: float) -> void:
	var before := position
	var rolling_before:=grounded
	var surface: String = model.lie(position.x,position.z)
	var normal: Vector3 = model.normal_at(position.x,position.z)
	var height: float = model.height(position.x,position.z)+RADIUS
	var props: Array = SURFACES.get(surface,SURFACES.rough)
	if grounded and position.y<=height+.04:
		var slope := GRAVITY-normal*GRAVITY.dot(normal)
		velocity -= normal*velocity.dot(normal)
		var resistance: float = props[1]
		if velocity.length()<.025 and slope.length()<resistance:
			velocity=Vector3.ZERO
		else:
			velocity+=slope*dt
			velocity=velocity.move_toward(Vector3.ZERO,resistance*dt)
		position+=velocity*dt
		position.y=model.height(position.x,position.z)+RADIUS
		spin=normal.cross(velocity)/RADIUS
	else:
		grounded=false
		# Midpoint integration keeps carry stable across 72/90/120 Hz headset rates.
		var a := acceleration(velocity,spin,model.wind())
		var mid := velocity+a*dt*.5
		velocity+=acceleration(mid,spin,model.wind())*dt
		position+=mid*dt
		spin*=exp(-.12*dt)
		air_time+=dt
		var floor_y: float = model.height(position.x,position.z)+RADIUS
		if position.y<=floor_y:
			if carry==0: carry=Vector2(position.x-origin.x,position.z-origin.z).length()
			position.y=floor_y
			normal=model.normal_at(position.x,position.z)
			props=SURFACES.get(model.lie(position.x,position.z),SURFACES.rough)
			var vn := velocity.dot(normal)
			if vn<0:
				var tangent := velocity-normal*vn
				# Friction opposes contact-point slip; bounded by impact impulse.
				var slip := tangent+spin.cross(-normal*RADIUS)
				var friction := -slip.normalized()*minf(slip.length()/3.5,absf(vn)*.35)
				var turf: String=model.lie(position.x,position.z)
				var retention: float={"green":.85,"fringe":.75,"fairway":.70,"rough":.45,"sand":.25}.get(turf,.6)
				velocity=(tangent+friction)*retention-normal*vn*float(props[0])
				spin+=(-normal*RADIUS).cross(friction)*2.5/(RADIUS*RADIUS)
			if absf(velocity.dot(normal))<.65:
				grounded=true; velocity-=normal*velocity.dot(normal)
	if collision_query.is_valid() and before.distance_squared_to(position)>.00000001:
		var obstacle: Dictionary=collision_query.call(before,position)
		if not obstacle.is_empty():
			var n: Vector3=obstacle.normal
			position=obstacle.position+n*(RADIUS+.002)
			velocity=velocity.bounce(n)*.45;spin*=.5;grounded=false
	var horizontal_step:=Vector2(position.x-before.x,position.z-before.z).length()
	travel_distance+=horizontal_step
	if rolling_before:roll_distance+=horizontal_step
	peak=maxf(peak,position.y-origin.y)
	var cup: Vector3 = model.pin()
	var closest := Geometry2D.get_closest_point_to_segment(Vector2(cup.x,cup.z),Vector2(before.x,before.z),Vector2(position.x,position.z))
	if surface=="green" and closest.distance_to(Vector2(cup.x,cup.z))<.054-RADIUS*.3 and absf(position.y-cup.y)<.08 and velocity.length()<1.65:
		position=cup-Vector3(0,.09,0);velocity=Vector3.ZERO;moving=false;holed=true;stop_reason="holed";return
	if surface in ["water","out"] and position.y<=height+.12:
		hazard=true;moving=false;velocity=Vector3.ZERO;stop_reason=surface;return
	if grounded and velocity.length()<.025: rest_time+=dt
	else: rest_time=0
	if rest_time>.35: moving=false;velocity=Vector3.ZERO;stop_reason="rest"
	# A numerical fail-safe produces a playable lie, never an endless flight.
	if air_time>30 or not position.is_finite(): hazard=true;moving=false;stop_reason="simulation_fail_safe"
