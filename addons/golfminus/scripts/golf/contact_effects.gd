extends Node3D
## Cosmetic only: contact effects never alter the ball, score or tracked club.
const Turf=preload("res://addons/golfminus/scripts/golf/club_turf.gd")
var probe:=Turf.new()
var previous:=Transform3D.IDENTITY
var valid:=false
var cooldown:=0.0
var debris:Array[Dictionary]=[]
var tee:Node3D
var tee_position:=Vector3.ZERO
var tee_armed:=false
var sounds:Dictionary={}
var audio:AudioStreamPlayer3D
var rng:=RandomNumberGenerator.new()
func _ready()->void:
	rng.randomize()
	audio=AudioStreamPlayer3D.new();audio.max_distance=18;audio.max_polyphony=3;add_child(audio)
	for surface in ["grass","sand"]:
		for hard in [false,true]:sounds[surface+str(hard)]=_sound(surface,hard)
func clear()->void:
	valid=false;cooldown=0;probe.reset();tee_armed=false
	if is_instance_valid(tee):tee.queue_free()
	tee=null
	for item in debris:item.node.queue_free()
	debris.clear()
	if is_instance_valid(audio):audio.stop()
func arm_tee(ball_position:Vector3)->void:
	clear();tee_position=ball_position
	tee=_tee_mesh();add_child(tee);tee.position=ball_position-Vector3.UP*.021335
	tee_armed=true
func launch_tee(ball_position:Vector3,velocity:Vector3)->bool:
	if not tee_armed:return false
	tee_armed=false
	if not is_instance_valid(tee):return false
	if ball_position.distance_to(tee_position)>.06 or velocity.length()<.1:
		tee.queue_free();tee=null;return false
	var direction:=Vector3(velocity.x,0,velocity.z).normalized()
	debris.append({"node":tee,"velocity":direction*clampf(velocity.length()*.045,.35,2.2)+Vector3.UP*1.8,"spin":Vector3(12,4,8),"life":2.0,"duration":2.0,"floor":tee.position.y})
	tee=null
	return true
func sample_ground(pose:Transform3D,shape:RefCounted,terrain:RefCounted,dt:float,active:bool)->Dictionary:
	cooldown=maxf(0,cooldown-maxf(dt,0))
	if not active or dt<=0 or dt>.05 or not pose.origin.is_finite() or not pose.basis.is_finite() or absf(pose.basis.determinant())<.01:
		valid=false;return {}
	pose.basis=pose.basis.orthonormalized()
	if not valid:previous=pose;valid=true;return {}
	var start:=previous;previous=pose
	var speed:=start.origin.distance_to(pose.origin)/dt
	var angular:=start.basis.get_rotation_quaternion().angle_to(pose.basis.get_rotation_quaternion())/dt
	if speed>65 or angular>90:valid=false;return {}
	if speed+angular*float(shape.radius)<.15 or cooldown>0:return {}
	probe.reset()
	var event:Dictionary=probe.sweep(start,pose,shape,terrain,dt,1,(pose.origin-start.origin)/dt)
	if event.is_empty():return {}
	if event.depth_m<.0002 or event.surface in ["water","out"]:return {}
	var hard:bool=event.depth_m>.004 and speed+angular*float(shape.radius)>1.0
	event.strength=clampf(sqrt(float(event.work_j))*.25,.08,.65)
	event.hard=hard;cooldown=.15 if hard else .10
	_emit_ground(event)
	return event
func _emit_ground(event:Dictionary)->void:
	var sand:bool=event.surface=="sand"
	audio.position=event.position;audio.stream=sounds[("sand" if sand else "grass")+str(event.hard)]
	audio.volume_db=linear_to_db(clampf(event.strength,.12,.7));audio.pitch_scale=rng.randf_range(.9,1.1);audio.play()
	var color:=Color("bba77b") if sand else Color("527236")
	for i in (10 if event.hard else 4):
		if debris.size()>=64:break
		var bit:=MeshInstance3D.new();var mesh:=BoxMesh.new()
		mesh.size=Vector3(.005,.003,.007) if sand else Vector3(.006,.002,.022)
		bit.mesh=mesh;bit.material_override=_material(color);add_child(bit);bit.position=event.position+event.normal*.005
		var velocity:Vector3=event.normal*rng.randf_range(.4,1.3)+event.velocity.normalized()*rng.randf_range(.15,.7)
		velocity+=Vector3(rng.randf_range(-.35,.35),0,rng.randf_range(-.35,.35))
		debris.append({"node":bit,"velocity":velocity,"spin":Vector3(6,9,3),"life":.7,"duration":.7,"floor":event.position.y})
func _process(dt:float)->void:
	for i in range(debris.size()-1,-1,-1):
		var item:Dictionary=debris[i]
		item.life-=dt
		if item.life<=0:item.node.queue_free();debris.remove_at(i);continue
		item.velocity+=Vector3.DOWN*9.80665*dt
		item.node.position+=item.velocity*dt;item.node.rotation+=item.spin*dt
		if item.node.position.y<item.floor:
			item.node.position.y=item.floor;item.velocity=Vector3.ZERO;item.spin=Vector3.ZERO
		item.node.scale=Vector3.ONE*minf(1,float(item.life)/.2)
func _material(color:Color)->StandardMaterial3D:
	var material:=StandardMaterial3D.new();material.albedo_color=color;material.roughness=.95
	return material
func _tee_mesh()->Node3D:
	var result:=Node3D.new();result.name="GolfTee"
	for head in [false,true]:
		var part:=MeshInstance3D.new();var mesh:=CylinderMesh.new()
		mesh.height=.004 if head else .038;mesh.top_radius=.005 if head else .0016;mesh.bottom_radius=.002 if head else .0006;mesh.radial_segments=8
		part.mesh=mesh;part.material_override=_material(Color("e9d5a5"));part.position.y=-.002 if head else -.023;result.add_child(part)
	return result
func _sound(surface:String,hard:bool)->AudioStreamWAV:
	var data:=PackedByteArray();var random:=RandomNumberGenerator.new();random.seed=42
	var low:=0.0
	for i in 4400:
		var t:=float(i)/22050
		low=lerpf(low,random.randf_range(-1,1),.18 if hard else .6)
		var value:float=(low*.65+sin(t*TAU*110)*(.25 if hard else .02))*exp(-t*(35 if hard else 20))
		if surface=="sand":value*=.7
		var sample:=int(clampf(value,-1,1)*32767);data.append(sample&255);data.append((sample>>8)&255)
	var wav:=AudioStreamWAV.new();wav.format=AudioStreamWAV.FORMAT_16_BITS;wav.mix_rate=22050;wav.data=data
	return wav
