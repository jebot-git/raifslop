extends RefCounted
## SI units. Fixed substeps, drag, spin lift, impulse bounce and slope-aware rolling.
const MASS := .04593
const RADIUS := .021335
const TEE_HEIGHT := .035
const AREA := PI*RADIUS*RADIUS
const GRAVITY := Vector3(0,-9.80665,0)
const SURFACES := {"green":[.25,.55],"fringe":[.30,.85],"fairway":[.42,1.8],"rough":[.23,2.5],"sand":[.10,4.5]}
# Tunable material response, not measured course properties. Static holding is
# independent of the energy lost pushing through grass/sand while moving.
const HOLD_ACCEL := {"green":.08,"fringe":.12,"fairway":.16,"rough":.45,"sand":2.0}
const MATERIAL_DRAG := {"green":0.0,"fringe":.001,"fairway":.002,"rough":.07,"sand":.35}
const LOW_SPEED_DRAG := 2.0
const REST_SPEED := .01
const SLIDING_FRICTION := {"green":.20,"fringe":.25,"fairway":.30,"rough":.45,"sand":.60}
# Impact friction is separate from sustained sliding and rolling resistance.
# Initial dry-surface coefficients; course-specific calibration needs measured shots.
const LANDING_FRICTION := {"green":.35,"fringe":.40,"fairway":.50,"rough":.65,"sand":.80}
# Effective normal stiffness (N/m) for a small compliant turf contact patch.
# These are starting coefficients, not measured material properties.
const LANDING_STIFFNESS := {"green":120000.0,"fringe":100000.0,"fairway":90000.0,"rough":50000.0,"sand":20000.0}
func landing_contact(normal:Vector3,surface:String)->Dictionary:
	var vn:=velocity.dot(normal)
	if vn>=0:return {}
	var restitution:float=SURFACES.get(surface,SURFACES.rough)[0]
	var normal_delta:=-(1.0+restitution)*vn
	# Normal kinetic energy loads a compliant patch: 1/2 k d² = 1/2 m vn².
	# Bulk turf displacement resists translation through its pressure centroid,
	# separately from point-contact sliding friction. Its impulse is capped so
	# it cannot reverse translation or inject energy. No fixed speed retention.
	var indentation:=minf(RADIUS*.8,absf(vn)*sqrt(MASS/float(LANDING_STIFFNESS.get(surface,50000.0))))
	var tangent:=velocity-normal*vn
	var deformation:Vector3=-tangent.normalized()*minf(tangent.length(),normal_delta*indentation/RADIUS)
	velocity+=deformation
	var arm:Vector3=-normal*RADIUS
	var slip:=velocity-normal*vn+spin.cross(arm)
	# A solid sphere has tangential inverse effective mass 3.5/m. Stop slip
	# without reversing it, bounded by Coulomb friction on the normal impulse.
	var friction:Vector3=-slip.normalized()*minf(slip.length()/3.5,float(LANDING_FRICTION.get(surface,.65))*normal_delta)
	velocity+=normal*normal_delta+friction
	spin+=arm.cross(friction)*2.5/(RADIUS*RADIUS)
	return {"normal_impulse_ns":normal_delta*MASS,"friction_impulse_ns":friction*MASS,"deformation_impulse_ns":deformation*MASS,"indentation_m":indentation,"slip_before_friction":slip}
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
func support_height(x:float,z:float)->float:
	# Sphere support on the local plane; vertical radius alone penetrates slopes.
	return model.height(x,z)+RADIUS/maxf(.2,model.normal_at(x,z).y)
func holding_acceleration(surface:String)->float:
	return float(HOLD_ACCEL.get(surface,HOLD_ACCEL.rough))
func rolling_resistance(surface:String,speed:float)->float:
	var base:float=SURFACES.get(surface,SURFACES.rough)[1]
	# Smoothly approach the static threshold as speed crosses zero, allowing an
	# uphill ball to reverse instead of repeatedly being clamped to a dead stop.
	return minf(base,holding_acceleration(surface)+speed*LOW_SPEED_DRAG)
func material_drag(surface:String,speed:float)->float:
	return float(MATERIAL_DRAG.get(surface,.07))*speed*speed
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
	# Rifle spin (parallel to the airflow) produces no Magnus lift. Normalizing
	# the cross product while using total spin gave near-rifle shots full lift.
	var transverse_spin:=w-relative*(w.dot(relative)/(speed*speed))
	var ratio := RADIUS*transverse_spin.length()/speed
	var cd := .23+.07*clampf(ratio,0,1)
	var lift := transverse_spin.cross(relative).normalized()*.5*1.225*AREA*minf(.30,ratio*1.6)*speed*speed/MASS
	return GRAVITY-relative*(.5*1.225*AREA*cd*speed/MASS)+lift
func step(delta: float) -> void:
	if not moving or not is_finite(delta) or delta<=0: return
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
	var height: float = model.height(position.x,position.z)+RADIUS/maxf(.2,normal.y)
	if grounded and position.y<=height+.04:
		var slope := GRAVITY-normal*GRAVITY.dot(normal)
		velocity -= normal*velocity.dot(normal)
		var resistance:float=rolling_resistance(surface,velocity.length())
		var arm:Vector3=-normal*RADIUS
		var slip:=velocity+spin.cross(arm)
		if slip.length()>.002:
			# A skid exchanges translation and rotation through friction. Do not
			# erase landing backspin, or create rolling energy from a sliding ball.
			velocity+=slope*dt
			slip=velocity+spin.cross(arm)
			var friction:Vector3=-slip.normalized()*minf(slip.length()/3.5,float(SLIDING_FRICTION.get(surface,.3))*absf(GRAVITY.dot(normal))*dt)
			velocity+=friction
			spin+=arm.cross(friction)*2.5/(RADIUS*RADIUS)
			# Bulk material drag acts during a skid too. Reduce both energies
			# without manufacturing rolling spin or reversing translation.
			var speed:=velocity.length()
			var factor:=maxf(0.0,1.0-material_drag(surface,speed)*dt/maxf(speed,.000001))
			velocity*=factor;spin*=factor
		else:
			# I = 2/5 mr²: rolling acceleration down a slope is 5/7 g sin(theta).
			var acceleration_downhill:=slope*(5.0/7.0)
			if velocity.length()<.025 and acceleration_downhill.length()<=holding_acceleration(surface):
				velocity=Vector3.ZERO
			else:
				velocity+=acceleration_downhill*dt
				velocity=velocity.move_toward(Vector3.ZERO,(resistance+material_drag(surface,velocity.length()))*dt)
			spin=normal.cross(velocity)/RADIUS+normal*spin.dot(normal)*exp(-3*dt)
		position+=velocity*dt
		var floor_y:=support_height(position.x,position.z)
		# A convex crest may fall away faster than gravity can keep the ball in
		# contact. Leave the surface rather than gluing the ball to its height.
		if position.y+GRAVITY.y*dt*dt*.5>floor_y+.00005:
			position+=GRAVITY*dt*dt*.5;velocity+=GRAVITY*dt;grounded=false
		else:position.y=floor_y
	else:
		grounded=false
		# Midpoint integration keeps carry stable across 72/90/120 Hz headset rates.
		var a := acceleration(velocity,spin,model.wind())
		var mid := velocity+a*dt*.5
		velocity+=acceleration(mid,spin,model.wind())*dt
		position+=mid*dt
		spin*=exp(-.12*dt)
		air_time+=dt
		var floor_y: float = support_height(position.x,position.z)
		if position.y<=floor_y:
			if carry==0: carry=Vector2(position.x-origin.x,position.z-origin.z).length()
			position.y=floor_y
			normal=model.normal_at(position.x,position.z)
			landing_contact(normal,model.lie(position.x,position.z))
			if absf(velocity.dot(normal))<.65:
				grounded=true; velocity-=normal*velocity.dot(normal)
	if collision_query.is_valid():
		var obstacle: Dictionary=collision_query.call(before,position)
		if not obstacle.is_empty():
			var n: Vector3=obstacle.normal
			position=obstacle.get("center",obstacle.position+n*(RADIUS+.002))
			var incoming:=velocity.dot(n)
			if incoming<0:
				# Dampen normal motion without reversing an already escaping ball.
				velocity-=n*(1.45*incoming);spin*=.5
			grounded=false
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
	var rest_normal:Vector3=model.normal_at(position.x,position.z)
	var downhill:Vector3=(GRAVITY-rest_normal*GRAVITY.dot(rest_normal))*(5.0/7.0)
	# Small force hysteresis prevents sub-millimetre creep at large course
	# coordinates from keeping a visually stationary ball active indefinitely.
	if grounded and velocity.length()<REST_SPEED and (velocity+spin.cross(-rest_normal*RADIUS)).length()<.025 and downhill.length()<=holding_acceleration(model.lie(position.x,position.z))+LOW_SPEED_DRAG*REST_SPEED: rest_time+=dt
	else: rest_time=0
	if rest_time>.35: moving=false;velocity=Vector3.ZERO;stop_reason="rest"
	# A numerical fail-safe produces a playable lie, never an endless flight.
	if air_time>30 or not position.is_finite(): hazard=true;moving=false;stop_reason="simulation_fail_safe"
