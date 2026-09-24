extends RefCounted
## Finite-mass rigid-body impulse at the measured surface point, SI units.
const MASS:=.04593
const RADIUS:=.021335
const BALL_INERTIA:=.4*MASS*RADIUS*RADIUS
static func surface_region(normal:Vector3)->String:
	if normal.z<-.65:return "face"
	if absf(normal.y)>=maxf(absf(normal.x),absf(normal.z)):return "crown" if normal.y>0 else "sole"
	if absf(normal.x)>absf(normal.z):return "toe" if normal.x>0 else "heel"
	return "back" if normal.z>0 else "face_edge"
static func inverse_tensor(basis:Basis,diagonal:Vector3)->Basis:
	return basis*Basis.from_scale(Vector3(1.0/diagonal.x,1.0/diagonal.y,1.0/diagonal.z))*basis.transposed()
static func response(impulse:Vector3,arm:Vector3,ball_arm:Vector3,inverse:Basis,head_mass:float)->Vector3:
	return impulse*(1.0/MASS+1.0/head_mass)-arm.cross(inverse*arm.cross(impulse))-ball_arm.cross(ball_arm.cross(impulse))/BALL_INERTIA
static func solve(shape:RefCounted,linear:Vector3,angular:Vector3,contact:Dictionary,_lie:String)->Dictionary:
	if not linear.is_finite() or not angular.is_finite():return {}
	var normal:Vector3=contact.get("normal",Vector3.ZERO)
	var point:Vector3=contact.get("contact",Vector3.ZERO)
	var centre:Vector3=contact.get("head_center",Vector3.ZERO)
	var basis:Basis=contact.get("head_basis",Basis.IDENTITY)
	if not normal.is_finite() or normal.length_squared()<.9 or not point.is_finite() or not centre.is_finite() or not basis.is_finite() or absf(basis.determinant())<.01:return {}
	normal=normal.normalized();basis=basis.orthonormalized()
	var ball_velocity:Vector3=contact.get("ball_velocity",Vector3.ZERO)
	var ball_spin:Vector3=contact.get("ball_spin",Vector3.ZERO)
	if not ball_velocity.is_finite() or not ball_spin.is_finite():return {}
	var arm:=point-centre
	var ball_arm:Vector3=-normal*RADIUS
	# Incoming motion already includes measured pre-ball turf resistance.
	var efficiency:=1.0
	var contact_velocity:=linear+angular.cross(arm)
	var relative:=ball_velocity+ball_spin.cross(ball_arm)-contact_velocity
	var closing:float=-relative.dot(normal)
	if closing<=.03:return {}
	var inverse:=inverse_tensor(basis,shape.inertia)
	var tangent1:Vector3=normal.cross(Vector3.UP if absf(normal.y)<.9 else Vector3.RIGHT).normalized()
	var tangent2:=normal.cross(tangent1)
	var kn:=normal.dot(response(normal,arm,ball_arm,inverse,shape.mass))
	var kt1:=response(tangent1,arm,ball_arm,inverse,shape.mass)
	var kt2:=response(tangent2,arm,ball_arm,inverse,shape.mass)
	var a:=tangent1.dot(kt1);var b:=tangent1.dot(kt2);var c:=tangent2.dot(kt2)
	var determinant:=a*c-b*b
	if kn<=0 or determinant<=0:return {}
	var face_contact:bool=(basis*Vector3.FORWARD).dot(normal)>.65
	var restitution:float=shape.restitution if face_contact else .45
	var mu:float=shape.friction
	var normal_impulse:=0.0
	var tangent_impulse:=Vector2.ZERO
	var impulse:=Vector3.ZERO
	for iteration in 16:
		var residual:=relative+response(impulse,arm,ball_arm,inverse,shape.mass)
		normal_impulse=maxf(0,normal_impulse+(restitution*closing-residual.dot(normal))/kn)
		impulse=normal*normal_impulse+tangent1*tangent_impulse.x+tangent2*tangent_impulse.y
		residual=relative+response(impulse,arm,ball_arm,inverse,shape.mass)
		var v:=Vector2(residual.dot(tangent1),residual.dot(tangent2))
		var correction:=Vector2(-c*v.x+b*v.y,b*v.x-a*v.y)/determinant
		tangent_impulse=(tangent_impulse+correction).limit_length(mu*normal_impulse)
		impulse=normal*normal_impulse+tangent1*tangent_impulse.x+tangent2*tangent_impulse.y
	# Newton restitution plus coupled friction must remain passive even at extreme offsets.
	var quadratic:=impulse.dot(response(impulse,arm,ball_arm,inverse,shape.mass))
	var work:=relative.dot(impulse)
	if work+.5*quadratic>0 and quadratic>0:
		var passive_scale:=clampf(-2.0*work/quadratic,0,1)
		impulse*=passive_scale;normal_impulse*=passive_scale;tangent_impulse*=passive_scale
	var velocity:=ball_velocity+impulse/MASS
	var spin:=ball_spin+ball_arm.cross(impulse)/BALL_INERTIA
	var head_velocity:Vector3=linear-impulse/shape.mass
	var head_angular:=angular-inverse*arm.cross(impulse)
	if not velocity.is_finite() or not spin.is_finite():return {}
	var local:Vector3=basis.transposed()*arm
	var path:=Vector3(contact_velocity.x,0,contact_velocity.z)
	var face:=Vector3(normal.x,0,normal.z)
	return {"velocity":velocity,"spin":spin,"normal_speed_m_s":closing,"tangential_speed_m_s":(relative+normal*closing).length(),"face_path_angle_degrees":rad_to_deg(face.signed_angle_to(path,Vector3.UP)) if face.length()>.0001 and path.length()>.0001 else 0.0,"dynamic_loft_degrees":rad_to_deg(asin(clampf(normal.y,-1,1))),"attack_angle_degrees":rad_to_deg(atan2(contact_velocity.y,path.length())),"impact_offset_m":Vector2(local.x,local.y),"contact_normal":normal,"contact_point":point,"contact_velocity":contact_velocity,"normal_impulse_ns":normal_impulse,"tangent_impulse_ns":tangent_impulse.length(),"friction":mu,"restitution":restitution,"head_velocity_after":head_velocity,"head_angular_velocity_after":head_angular,"efficiency":efficiency,"smash":velocity.length()/maxf(contact_velocity.length(),.001),"head_mass_kg":shape.mass,"head_inertia_kg_m2":shape.inertia,"effective_normal_mass_kg":1.0/kn,"surface":"face" if face_contact else "body","surface_region":surface_region(basis.transposed()*normal),"contact_normal_local":basis.transposed()*normal,"model":"mesh_rigid_impulse_v3"}
