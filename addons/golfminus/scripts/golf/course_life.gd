extends Node3D
## Reuses Fishing's stereo wildlife and sound controls; scenery stays cosmetic.
var activity:Node
var birds:Node3D
var insects:Node3D
var sound:=AudioStreamPlayer.new()
var animals:Array[Node3D]=[]
var clock:=0.0
var anchor:=Vector3(INF,0,0)
var marker:=Label3D.new()
var leaves:=CPUParticles3D.new()
func setup(a:Node)->void:
	activity=a;name="CourseEnvironmentLife"
	birds=preload("res://scripts/environment_life.gd").new();add_child(birds)
	birds.configure("secluded_beach" if a.golf.course_id=="pebble" else "lakeside")
	insects=preload("res://scripts/environment_life.gd").new();add_child(insects);insects.configure("gray_pier");insects.birds.hide()
	add_child(sound);sound.stream=load("res://assets/audio/ambience/secluded_beach.ogg" if a.golf.course_id=="pebble" else "res://assets/audio/ambience/lakeside.ogg").duplicate();sound.stream.loop=true;sound.play()
	add_child(leaves);leaves.amount=28;leaves.lifetime=9;leaves.preprocess=2;leaves.emission_shape=CPUParticles3D.EMISSION_SHAPE_BOX;leaves.emission_box_extents=Vector3(14,3,14)
	leaves.direction=Vector3(1,-.25,.3);leaves.spread=24;leaves.initial_velocity_min=.5;leaves.initial_velocity_max=1.3;leaves.gravity=Vector3(0,-.08,0);leaves.angular_velocity_min=-50;leaves.angular_velocity_max=70
	var leaf_mesh:=PrismMesh.new();leaf_mesh.size=Vector3(.08,.015,.035);leaves.mesh=leaf_mesh
	var leaf_mat:=StandardMaterial3D.new();leaf_mat.albedo_color=Color("6a8050");leaf_mat.cull_mode=BaseMaterial3D.CULL_DISABLED;leaf_mesh.material=leaf_mat
	# Small ground squirrels near the course margins, assembled as low-cost meshes.
	var fur:=StandardMaterial3D.new();fur.albedo_color=Color("81715b");fur.roughness=1
	for i in 3:
		var animal:=Node3D.new();animal.name="GroundSquirrel";add_child(animal);animals.append(animal)
		for part in [[Vector3(0,.15,0),Vector3(.13,.12,.25)],[Vector3(0,.23,-.2),Vector3(.10,.10,.10)],[Vector3(0,.28,.22),Vector3(.075,.23,.075)]]:
			var mesh:=MeshInstance3D.new();var shape:=SphereMesh.new();shape.radius=1;shape.height=2;shape.radial_segments=12;shape.rings=6;mesh.mesh=shape;mesh.scale=part[1];mesh.position=part[0];mesh.material_override=fur;animal.add_child(mesh)
	add_child(marker);marker.name="CurrentHoleGuide";marker.text="⚑\n01";marker.font_size=96;marker.pixel_size=.055;marker.modulate=Color("ffe29c");marker.outline_modulate=Color("16362c");marker.outline_size=18;marker.billboard=BaseMaterial3D.BILLBOARD_ENABLED;marker.no_depth_test=true
func _process(dt:float)->void:
	if not is_instance_valid(activity) or not activity.active:return
	clock+=dt
	var g=activity.golf
	var p:Vector3=activity.host.motor.global_position
	if not anchor.is_finite() or anchor.distance_to(p)>100:
		anchor=p;birds.position=anchor;insects.position=anchor;leaves.position=anchor+Vector3.UP*5
	marker.scale=Vector3.ONE*clampf(p.distance_to(g.model.pin())/180,1,6)
	marker.position=g.model.pin()+Vector3.UP*(12+marker.scale.x*6);marker.text="▼\n%02d"%(g.model.index+1)
	marker.visible=preload("res://addons/golfminus/scripts/golf/pictograms.gd").enabled and activity.clubhouse_round==null
	sound.volume_db=-80 if activity.host.ambience.muted else linear_to_db(maxf(.0001,activity.host.ambience.volume)) - 7
	for i in animals.size():
		var at:=anchor+Vector3(16+i*6+sin(clock*.4+i)*2,0,12+cos(clock*.3+i)*3)
		var lie:String=g.model.lie(at.x,at.z)
		animals[i].visible=lie in ["rough","fairway"]
		at.y=g.world.surface_height(at.x,at.z)+absf(sin(clock*5+i))*.025
		animals[i].position=at;animals[i].rotation.y=sin(clock*.4+i)*.5
func _exit_tree()->void:
	sound.stop();sound.stream=null
