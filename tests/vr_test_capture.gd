extends SceneTree
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func run()->void:
	var g=load("res://scenes/main.tscn").instantiate();root.add_child(g)
	await create_timer(.5).timeout
	g.set_process(false);g.motor.set_physics_process(false)
	var capture=g.get_node_or_null("VRTestCapture")
	check(capture!=null and capture.enabled,"Explicit capture flag opens a recording")
	if capture==null:quit(1);return
	var trackers:Array[XRControllerTracker]=[]
	for hand in 2:
		var t:=XRControllerTracker.new();t.name="capture_fixture_"+str(hand);XRServer.add_tracker(t);trackers.append(t)
		var c:XRController3D=g.left if hand==0 else g.right;c.tracker=t.name;c.pose="grip"
		t.set_pose("grip",Transform3D(Basis(Vector3.UP,.3),Vector3(hand*.5,1.2,-.3)),Vector3(1,2,3),Vector3(.1,.2,.3),XRPose.XR_TRACKING_CONFIDENCE_HIGH)
		t.set_pose("aim",Transform3D(Basis.IDENTITY,Vector3(hand*.5,1.2,-.3)),Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
		t.set_input("primary",Vector2(.25,-.5));t.set_input("trigger",.7);t.set_input("grip",.4)
	for i in 3:await process_frame
	for i in 4:await process_frame
	var origin:Transform3D=g.origin.transform
	var head:Transform3D=g.head.transform
	trackers[1].set_input("trigger_click",true)
	for i in 4:await process_frame
	trackers[1].set_input("trigger_click",false)
	trackers[0].invalidate_pose("grip")
	for i in 3:await process_frame
	for i in 4:await process_frame
	check(g.origin.transform.is_equal_approx(origin) and g.head.transform.is_equal_approx(head),"Recording never moves tracking origin or headset")
	await g.golf_activity.join_course("spyglass")
	g.golf_activity.golf.set_process(false);g.golf_activity.golf.set_physics_process(false);g.motor.set_physics_process(false)
	for i in 4:await process_frame
	var in_golf:int=capture.sequence
	for i in 6:await process_frame
	check(capture.sequence>=in_golf+5 and capture.can_process(),"Automatic controller polling remains active throughout golf")
	for service in get_nodes_in_group("activity_services"):
		check(service.can_process(),"Persistent diagnostics survive course transition: "+str(service.name))
	g.golf_activity.leave()
	var returned:int=capture.sequence
	for i in 6:await process_frame
	check(capture.sequence>=returned+5,"Automatic polling continues after returning to fishing")
	capture.stop("fixture_complete")
	var rows:Array=[]
	for line in FileAccess.get_file_as_string(capture.directory.path_join("controllers-000.jsonl")).split("\n",false):rows.append(JSON.parse_string(line))
	var frames:Array=rows.filter(func(row):return row.type=="frame")
	var input_rows:Array=rows.filter(func(row):return row.type=="button" and row.data.button=="trigger_click")
	check(frames.size()>=4,"Frame samples are valid JSONL")
	check(input_rows.any(func(row):return row.data.pressed) and input_rows.any(func(row):return not row.data.pressed),"Press and release are timestamped independently of frame polling")
	check(frames.any(func(row):return row.data.right.get("linear_velocity",[])==[1.0,2.0,3.0] and row.data.right.stick==[.25,-.5]),"Runtime velocities and stick values survive serialization")
	check(frames.any(func(row):return not row.data.left.tracked and row.data.right.tracked),"Offhand tracking loss is recorded explicitly")
	check(frames.any(func(row):return row.data.has("golf") and row.data.golf.has("head") and row.data.golf.has("ball")),"Golf club, ball and fitting context share the controller timeline")
	var ordered:=true
	for i in range(1,rows.size()):ordered=ordered and rows[i].seq>rows[i-1].seq and rows[i].us>=rows[i-1].us
	check(ordered and rows.back().type=="capture_stopped","Capture flushes ordered records and an explicit stop event")
	for t in trackers:XRServer.remove_tracker(t)
	g.ambience.stop();g.queue_free();await process_frame;await create_timer(.2).timeout
	print("VR_TEST_CAPTURE_RESULT ",failures);quit(0 if failures.is_empty() else 1)
