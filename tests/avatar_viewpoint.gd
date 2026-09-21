extends SceneTree
var failures:Array=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
 if not ok:failures.append(label);push_error(label)
func run():
 var g=load("res://scenes/main.tscn").instantiate();root.add_child(g)
 for i in 400:
  await process_frame
  if not g.avatar_loading:break
 g.set_process(false);g.motor.set_physics_process(false)
 for path in g.avatars.DEFAULTS:
  await g._select_avatar(path)
  var rig=g.avatar
  rig.process_mode=Node.PROCESS_MODE_DISABLED
  var sk:Skeleton3D=rig.skeleton
  for position in [Vector3(0,1.65,0),Vector3(.35,1.2,-.25),Vector3(-.4,1.8,.3)]:
   for pitch in [0.0,.6,1.55,1.59,-.6]:
    g.head.position=position;g.head.rotation=Vector3(pitch,.7,.12)
    rig.apply_tracking(g.motor.global_transform,{},{})
    rig.update_targets(g.head,g.desktop_left,g.rod,g.motor.global_position.y,Vector3.ZERO,.02)
    rig.solver._process_modification_with_delta(.02)
    check(rig.viewpoint_position().distance_to(g.head.global_position)<.001,"Avatar eyes follow headset: "+path)
    var shoulder:=sk.to_global(sk.get_bone_global_pose(sk.find_bone("RightUpperArm")).origin)
    for i in 5:rig.solver._process_modification_with_delta(.02)
    check(shoulder.distance_to(sk.to_global(sk.get_bone_global_pose(sk.find_bone("RightUpperArm")).origin))<.001,"Shoulders do not accumulate solver drift")
    check(rig.viewpoint_position().distance_to(g.head.global_position)<.001,"Repeated solve preserves viewpoint")
    if pitch>1.5:check(absf(rig.body_yaw-.7)<.04,"Looking vertically does not flip shoulders")
    for index in sk.get_bone_count():check(sk.get_bone_global_pose(index).is_finite(),"Finite body pose")
  g.head.position=Vector3(0,1.4,0);g.head.rotation=Vector3(.4,.7,0)
  var hips:=Transform3D(Basis(Vector3.UP,.3),Vector3(0,.72,0))
  rig.apply_tracking(g.motor.global_transform,{"hips":hips},{})
  rig.update_targets(g.head,g.desktop_left,g.rod,g.motor.global_position.y,Vector3.ZERO,.02)
  rig.solver._process_modification_with_delta(.02)
  check(rig.viewpoint_position().distance_to(g.head.global_position)<.001,"Tracked hips retain headset viewpoint")
  var expected:Vector3=(g.motor.global_transform*rig.fit_tracked_hips(hips)).origin
  check(sk.to_global(sk.get_bone_global_pose(sk.find_bone("Hips")).origin).distance_to(expected)<.001,"Eye alignment preserves tracked hips")
  for height in [.95, 1.15, 1.65]:
   g.head.position=Vector3(.15,height,-.2)
   hips.origin=Vector3(0,height-.73,.05)
   var body={"hips":hips,"chest":Transform3D(Basis(Vector3.RIGHT,.2),Vector3(0,height-.3,-.05))}
   var origin_before:Transform3D=g.origin.global_transform
   for pitch in [-.6,.6]:
    g.head.rotation.x=pitch
    rig.apply_tracking(g.motor.global_transform,body,{})
    rig.update_targets(g.head,g.desktop_left,g.rod,g.motor.global_position.y,Vector3.ZERO,.02)
    rig.solver._process_modification_with_delta(.02)
    var chest:=sk.find_bone("Chest")
    if chest>=0:
     check(sk.get_bone_pose_position(chest).is_equal_approx(sk.get_bone_rest(chest).origin),"FBT seated torso retains its length instead of being translated by eye alignment: "+path)
    expected=(g.motor.global_transform*rig.fit_tracked_hips(hips)).origin
    check(sk.to_global(sk.get_bone_global_pose(sk.find_bone("Hips")).origin).distance_to(expected)<.001,"Seated pelvis stays on its tracked target")
    check(rig.viewpoint_position().distance_to(g.head.global_position)<.001,"Seated head still follows the headset")
    check(g.origin.global_transform.is_equal_approx(origin_before),"Avatar fitting cannot move tracking origin")
 var locations=preload("res://scripts/locations.gd")
 for index in g.Session.SPECIES.size():
  var hint:Dictionary=g.fish_guide.discovery_hint(index)
  for id in g.Session.LOCATION_SPECIES:
   if index in g.Session.species_for_location(id):check(locations.find_location(id).name in hint.waters,"Guide uses Waters catalog names")
 g.queue_free();await process_frame
 print("AVATAR_VIEWPOINT_RESULT ",failures);quit(0 if failures.is_empty() else 1)
