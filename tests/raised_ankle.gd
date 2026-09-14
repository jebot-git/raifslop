extends SceneTree
const Tracking=preload("res://scripts/tracking/tracking.gd")
var failures:Array=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func run():
	root.size=Vector2i(1000,1000)
	var world=Node3D.new();root.add_child(world)
	var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("263c38");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.8;world.add_child(env)
	var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-35,-25,0);world.add_child(light)
	var camera=Camera3D.new();camera.cull_mask=4;camera.fov=40;world.add_child(camera);camera.current=true
	var library=preload("res://scripts/avatar_library.gd").new()
	for path in library.DEFAULTS:
		var rig=preload("res://scripts/avatar_rig.gd").new();world.add_child(rig)
		var model:Node3D=library.load_model(path);rig.add_child(model);rig.configure(model)
		var neutral=Transform3D(Basis.IDENTITY,Vector3(.13,.5,0))
		var offset=Tracking.calibrate_foot(neutral,0,1,Basis.IDENTITY)
		for degrees in [45,90,120]:
			var calf=Transform3D(Basis(Vector3.RIGHT,deg_to_rad(-degrees)),Vector3(.13,.65,-.12))
			var estimated=Tracking.estimated_foot(calf,offset)
			check(estimated.is_equal_approx(calf*offset),"FPSloppa full estimated ankle transform: "+path.get_file()+" "+str(degrees))
			var angles=[]
			for corrected in [false,true]:
				var foot:Transform3D=estimated
				if not corrected:foot.basis=Basis.IDENTITY
				rig.xr_pose={"head":Transform3D(Basis.IDENTITY,Vector3(0,1.65,0)),"left":Transform3D(Basis.IDENTITY,Vector3(-.3,1.1,-.3)),"right":Transform3D(Basis.IDENTITY,Vector3(.3,1.1,-.3)),"body":{"hips":Transform3D(Basis.IDENTITY,Vector3(0,.92,0)),"right_knee":calf,"right_foot":foot}}
				rig.solver._process_modification_with_delta(.016)
				var bone:int=rig.skeleton.find_bone("RightFoot")
				var delta:Quaternion=rig.skeleton.get_bone_rest(bone).basis.get_rotation_quaternion().inverse()*rig.skeleton.get_bone_pose_rotation(bone)
				angles.append(rad_to_deg(delta.angle_to(Quaternion.IDENTITY)))
				if "--capture" in OS.get_cmdline_user_args() and degrees==90:
					camera.position=estimated.origin+Vector3(.85,.05,-.8);camera.look_at(estimated.origin+Vector3(0,.0,-.15))
					for i in 10:await process_frame
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png("res://test-results/vr-fixes/raised-ankle-"+path.get_file().get_basename()+("-fixed" if corrected else "-old")+".png")
			print("ANKLE_FLEX ",path.get_file()," calf=",degrees," old=",angles[0]," corrected=",angles[1])
			check(angles[1]<60 and angles[1]+20<angles[0],"Raised ankle avoids floor-lock hyperflexion: "+path.get_file()+" "+str(degrees))
		rig.queue_free();await process_frame
	world.queue_free();await process_frame
	print("RAISED_ANKLE_RESULT ",failures);quit(0 if failures.is_empty() else 1)
