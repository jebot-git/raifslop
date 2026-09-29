extends RefCounted
## Swept face contact, with tracking/teleport rejection and deliberate grip arming.
var previous:=Vector3.INF
var armed_before:=false
static func contact(from:Vector3,to:Vector3,ball:Vector3,face:Vector3,dt:float)->Vector2:
	if not from.is_finite() or not to.is_finite() or dt<=0 or dt>.1:return Vector2.ZERO
	var travel:=to-from
	if travel.length()>.4 or travel.length()/dt>12:return Vector2.ZERO
	var forward:=Vector3(face.x,0,face.z).normalized()
	if forward.length()<.9:return Vector2.ZERO
	var speed:=travel.dot(forward)/dt
	if absf(speed)<.025:return Vector2.ZERO
	if speed<0:forward=-forward;speed=-speed
	var side:=Vector3.UP.cross(forward)
	var d0:=(ball-from).dot(forward)
	var d1:=(ball-to).dot(forward)
	# The physical blade's leading face must sweep the ball, not appear inside it.
	if d0<.034 or d1>.034 or d0<=d1:return Vector2.ZERO
	var fraction:=clampf((d0-.034)/(d0-d1),0,1)
	var hit:=from.lerp(to,fraction)
	if absf((ball-hit).dot(side))>.085 or absf(ball.y-hit.y)>.042:return Vector2.ZERO
	return Vector2(forward.x,forward.z)*minf(speed*1.65,8)
func sample(at:Vector3,ball:Vector3,face:Vector3,dt:float,armed:bool)->Vector2:
	var impulse:=Vector2.ZERO
	if armed and armed_before:impulse=contact(previous,at,ball,face,dt)
	previous=at if armed else Vector3.INF;armed_before=armed
	return impulse
func reset()->void:previous=Vector3.INF;armed_before=false
