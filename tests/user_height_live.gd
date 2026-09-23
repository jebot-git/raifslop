extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var g=load("res://scenes/main.tscn").instantiate();root.add_child(g);current_scene=g
	await create_timer(3).timeout
	var out:=OS.get_environment("HEIGHT_VALIDATION_OUTPUT")
	if out.is_empty():out="/tmp/raifslop-height-live"
	DirAccess.make_dir_recursive_absolute(out)
	var rows:Array=[]
	var failures:Array=[]
	var latest:Dictionary={}
	g.avatar.solver.modification_processed.connect(func():
		var sk:Skeleton3D=g.avatar.skeleton
		var bones:Dictionary={}
		for name_ in ["Hips","Spine","Chest","UpperChest","Neck","Head","LeftUpperLeg","LeftLowerLeg","RightUpperLeg","RightLowerLeg"]:
			var i:=sk.find_bone(name_)
			if i>=0:bones[name_]={"position":str(sk.to_global(sk.get_bone_global_pose(i).origin)),"local_offset":str(sk.get_bone_pose_position(i)-sk.get_bone_rest(i).origin),"rotation":str(sk.get_bone_pose_rotation(i)),"rest_rotation":str(sk.get_bone_rest(i).basis.get_rotation_quaternion())}
		latest.clear();latest.merge({"world_scale":XRServer.world_scale,"head_height":g.head.position.y,"standing_height":g.avatar.standing_height,"model_scale":str(g.avatar.model.scale),"hip_neutral":g.avatar.neutral_hip_height,"head_error":g.avatar.viewpoint_position().distance_to(g.head.global_position),"tracked_hip":str(g.tracking_manager.body.get("hips")),"tracked_chest":str(g.tracking_manager.body.get("chest")),"bones":bones})
	)
	var view:=SubViewport.new();view.size=Vector2i(960,960);view.world_3d=g.get_world_3d();view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
	var camera:=Camera3D.new();camera.cull_mask=5;camera.fov=50;view.add_child(camera)
	for sample in 3:
		await create_timer(2).timeout
		if latest.is_empty() or latest.world_scale!=1.0 or latest.head_error>.005:failures.append("Invalid live eye alignment")
		for name_ in ["Head","Neck"]:
			if latest.get("bones",{}).has(name_) and latest.bones[name_].local_offset!="(0.0, 0.0, 0.0)":failures.append("Changed "+name_+" length")
		rows.append(latest.duplicate(true));print("USER_HEIGHT_LIVE ",JSON.stringify(latest))
		var center:Vector3=g.head.global_position+Vector3.DOWN*.35
		var facing:=Basis(Vector3.UP,atan2(g.head.global_basis.z.x,g.head.global_basis.z.z))
		camera.global_position=center+facing*Vector3(0,.1,-1.8);camera.look_at(center)
		await process_frame;await RenderingServer.frame_post_draw
		view.get_texture().get_image().save_png(out.path_join("avatar-%d.png"%sample))
	FileAccess.open(out.path_join("poses.json"),FileAccess.WRITE).store_string(JSON.stringify(rows,"\t"))
	view.queue_free();g.ambience.stop();g.queue_free();await process_frame;await create_timer(.4).timeout;print("USER_HEIGHT_LIVE_RESULT ",failures);quit(0 if failures.is_empty() else 1)
