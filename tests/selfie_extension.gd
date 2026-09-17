extends SceneTree
const Photo=preload("res://scripts/guide_camera.gd")
var failures:Array=[]
var checks:=0
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);push_error(label)
func run():
 var g=load("res://scenes/main.tscn").instantiate();root.add_child(g)
 for i in 400:
  await process_frame
  if not g.avatar_loading:break
 g.set_process(false);g.motor.set_physics_process(false)
 var guide=g.fish_guide;var photo=guide.photo_camera
 photo.set_process(false);g.xr=true;g.menu_open=false;guide.held=true;photo.active=true;photo.selfie=true
 guide.global_transform=Transform3D(Basis.IDENTITY,Vector3(0,10,0))
 photo.update_pose()
 var lens:Transform3D=guide.global_transform*Photo.lens_pose(true)
 check(photo.camera.global_transform.is_equal_approx(lens),"Default front lens remains on the guide")
 for i in 100:photo.adjust_selfie(1,.05)
 check(is_equal_approx(photo.selfie_extension,Photo.MAX_SELFIE_EXTENSION),"Stick up stops at maximum extension")
 check(photo.camera.global_position.distance_to(lens.origin+lens.basis.z*3)<.001,"Extension moves away from subjects along lens axis")
 check(photo.camera.global_basis.is_equal_approx(lens.basis),"Extension preserves hand aim")
 for i in 100:photo.adjust_selfie(-1,.05)
 check(photo.selfie_extension==0 and photo.camera.global_transform.is_equal_approx(lens),"Stick down retracts to lens without reversing through guide")
 for angle in [Vector3.ZERO,Vector3(.4,.7,-.3),Vector3(1.55,.5,.8)]:
  guide.global_basis=Basis.from_euler(angle);photo.selfie_extension=1.2;photo.update_pose()
  lens=guide.global_transform*Photo.lens_pose(true)
  check(photo.camera.global_position.distance_to(lens.origin+lens.basis.z*1.2)<.001,"Extension follows tilted and rolled guide")
  check(photo.camera.global_basis.is_equal_approx(lens.basis),"No mirroring or aiming change")
 for condition in ["deadzone","inactive","rear","docked","busy","menu"]:
  photo.selfie_extension=.5;photo.update_pose()
  photo.active=condition!="inactive";photo.selfie=condition!="rear";guide.held=condition!="docked";photo.busy=condition=="busy";g.menu_open=condition=="menu"
  photo.adjust_selfie(.1 if condition=="deadzone" else 1,.05)
  check(photo.selfie_extension==.5,"No adjustment while "+condition)
  photo.active=true;photo.selfie=true;guide.held=true;photo.busy=false;g.menu_open=false
 guide.global_transform=Transform3D(Basis.IDENTITY,Vector3(0,10,0));lens=guide.global_transform*Photo.lens_pose(true)
 var wall:=StaticBody3D.new();wall.collision_layer=1;var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(.5,.5,.1);shape.shape=box;wall.add_child(shape);g.add_child(wall)
 wall.global_position=lens.origin+lens.basis.z*.9
 await physics_frame;await physics_frame
 photo.selfie_extension=3;photo.update_pose()
 check(photo.effective_extension>.6 and photo.effective_extension<.8,"Camera stops with clearance before a solid wall")
 var clipped:float=photo.effective_extension
 photo.adjust_selfie(-1,.1)
 check(photo.effective_extension<clipped-.09,"Retracting responds immediately when extension is blocked")
 wall.global_position=lens.origin
 await physics_frame;await physics_frame
 photo.selfie_extension=3;photo.update_pose()
 check(photo.effective_extension==0,"Lens starting inside scenery cannot extend through it")
 wall.queue_free();await physics_frame;await physics_frame
 var trackers:Array[XRControllerTracker]=[]
 for side in 2:
  var tracker:=XRControllerTracker.new();tracker.name="selfie_test_"+str(side);trackers.append(tracker);XRServer.add_tracker(tracker)
  var controller:XRController3D=g.left if side==0 else g.right;controller.tracker=tracker.name;controller.pose="grip"
  tracker.set_pose("grip",Transform3D(Basis.IDENTITY,Vector3(side*.3,1.2,-.3)),Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
  tracker.set_input("primary",Vector2(0,1));tracker.set_input("grip",1.0)
 await process_frame
 g.tracking_manager.focused=true;photo.selfie_extension=0;photo.update_pose();photo.sample_selfie_input(.05)
 check(photo.selfie_extension>0,"Tracked right-stick up extends camera")
 var before:float=photo.selfie_extension
 trackers[1].set_input("primary",Vector2(0,-1));await process_frame;photo.sample_selfie_input(.02)
 check(photo.selfie_extension<before,"Tracked right-stick down retracts camera")
 before=photo.selfie_extension;g.tracking_manager.focused=false;photo.sample_selfie_input(.05)
 check(photo.selfie_extension==before,"Focus loss suppresses camera adjustment")
 g.tracking_manager.focused=true;trackers[1].invalidate_pose("grip");await process_frame;photo.sample_selfie_input(.05)
 check(photo.selfie_extension==before,"Controller tracking loss suppresses camera adjustment")
 for tracker in trackers:XRServer.remove_tracker(tracker)
 photo.selfie=false;photo.update_pose()
 check(photo.camera.global_transform.is_equal_approx(guide.global_transform*Photo.lens_pose(false)),"Rear camera ignores saved selfie extension")
 g.xr=false;g.queue_free();await process_frame;await create_timer(.2).timeout
 print("SELFIE_EXTENSION_RESULT ",checks," checks: ",failures);quit(0 if failures.is_empty() else 1)
