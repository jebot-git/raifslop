extends SceneTree
## Regressions for the recorded fly-line, leap and shoreline failures.
const F=preload("res://scripts/fly_fishing.gd")
const S=preload("res://scripts/fishing_session.gd")
const NetState=preload("res://scripts/network/state.gd")
var failures: Array[String]=[]
func _initialize(): run.call_deferred()
func check(ok:bool,label:String):
 if not ok: failures.append(label);push_error(label)
func run():
 for rotation in [Basis.IDENTITY,Basis.from_euler(Vector3(.4,1.1,-.7))]:
  var f=F.new()
  var outlet:Vector3=rotation*Vector3.ZERO
  var guide:Vector3=rotation*Vector3(0,.3,0)
  var hand:Vector3=outlet
  check(f.strip(rotation*Vector3(1,0,0),1,.02,outlet,guide)==0 and not f.strip_engaged,"Grip far from line cannot strip")
  check(f.strip(hand,1,.02,outlet,guide)==0 and f.strip_engaged,"Grab visible segment without a first-frame impulse")
  hand+=rotation*Vector3(0,-.08,0)
  check(f.strip(hand,1,.05,outlet,guide)>1,"Physical downward pull works with tilted rod")
  check(f.strip(hand,1,.02,outlet+Vector3(.1,0,0),guide+Vector3(.1,0,0))==0,"Moving rod alone cannot strip")
  check(f.strip(hand,.45,.02,outlet,guide)==0 and f.strip_engaged,"Grip hysteresis prevents flicker")
  hand+=rotation*Vector3(0,.04,0)
  check(f.strip(hand,1,.02,outlet,guide)==0,"Returning hand does not reel")
  f.strip(hand,.2,.02,outlet,guide)
  check(not f.strip_engaged,"Relaxing grip releases visible line")
  f.strip(outlet,1,.02,outlet,guide)
  check(f.strip(outlet+Vector3(.7,0,0),1,.02,outlet,guide)==0 and not f.strip_engaged,"Tracking discontinuity releases without reeling")
  f.strip(outlet,1,.02,outlet,guide)
  check(not f.strip_engaged,"Tracking recovery needs release before regrab")
  f.strip(outlet,0,.02,outlet,guide);f.strip(outlet,1,.02,outlet,guide)
  check(f.strip_engaged,"Fresh grip reacquires after tracking recovery")
 var g=load("res://scenes/main.tscn").instantiate();root.add_child(g)
 await create_timer(.4).timeout
 g.set_process(false);g.motor.set_physics_process(false);g.fishing_feedback.set_process(false)
 g._select_location("meadow_bend",false)
 g.xr=true;g.left.position=Vector3(-.2,1,-.3);g.game.fly.strip_engaged=true
 g._update_line()
 var vertices:PackedVector3Array=g.line_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
 check(vertices[1].distance_to(g._fly_hand_position())<.001,"Visible fly line passes through rendered offhand")
 var state:Dictionary=NetState.capture(g,1)
 check(NetState.valid(state) and state.in_hand,"Remote anglers receive line grip in compatible state packet")
 var remote=preload("res://scripts/network/remote_angler.gd").new()
 remote.session=g.network;g.add_child(remote);remote.set_process(false)
 state.state=S.State.WAITING;remote.receive_state(state);remote._process(.02)
 var remote_vertices:PackedVector3Array=remote.line.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
 check(remote_vertices[1].distance_to(state.left.origin)<.001,"Remote fly line attaches to offhand while avatar loads")
 remote.queue_free()
 g.game.fly.release_strip();g._update_line()
 vertices=g.line_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
 check(vertices[1].distance_to(g.rod.to_global(F.LINE_GUIDE))<.001,"Release returns line to rod guides")
 # A stale IK pose or moving head must never become physical strip input.
 var tracker:=XRControllerTracker.new();tracker.name="fly_line_test_left";XRServer.add_tracker(tracker)
 g.left.tracker=tracker.name;g.left.pose="grip"
 var grab:Vector3=g.origin.to_local(g.rod.to_global(F.LINE_OUTLET))
 tracker.set_pose("grip",Transform3D(Basis.IDENTITY,grab),Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
 tracker.set_input("grip",1.0);await process_frame
 g.game.fly.reset();g._sample_fly_strip(.02)
 check(g.game.fly.strip_engaged,"Current tracked palm grabs the rendered rod segment")
 g.head.position+=Vector3(.1,.1,.1)
 g.avatar.left_grip=Transform3D(Basis.IDENTITY,Vector3(9,9,9));g.avatar.right_grip_frame=Engine.get_process_frames()
 check(g._sample_fly_strip(.02)==0 and g.game.fly.strip_engaged,"Head movement and stale solved hand cannot reel or detach line")
 var pull:Vector3=(grab-g.origin.to_local(g.rod.to_global(F.LINE_GUIDE))).normalized()*.05
 tracker.set_pose("grip",Transform3D(Basis.IDENTITY,grab+pull),Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
 await process_frame
 check(g._sample_fly_strip(.05)>0,"Fresh controller movement strips without waiting for IK")
 XRServer.remove_tracker(tracker);g.game.fly.reset()
 g.xr=false
 for id in ["lakeside","meadow_bend","boulder_run"]:
  g.game.reset();g._select_location(id,false)
  g.game.fish_index=10;g.game.state=S.State.BITE;g.game.strike();g.game.distance=9
  g.cast_anchor=Vector3(0,g.water_level+.05,-3);g.cast_target=Vector3(0,g.water_level+.05,-12)
  for fps in [30,72,90]:
   g.game._start_jump(0);g._update_line()
   var fish=g.hooked_fish
   var start:Vector3=fish.global_position
   check(start.y<g.water_level,"Leap begins submerged "+id)
   check((fish.model.position+fish.measured.get_center()).length()<.001,"Imported fish pivot is centered on animated trajectory")
   var previous:Vector3=start
   var end:Vector3=fish.landing_position()
   for frame in range(fps+1):
    var t:float=float(frame)/fps
    g.game.jump_time=maxf(.00001,S.JUMP_AIR*(1-t));g._update_line()
    var at:Vector3=fish.global_position
    check(at.distance_to(previous)<.15,"Continuous leap at "+str(fps)+" FPS")
    check(fish.global_basis.is_conformal(),"Leap orientation remains orthonormal")
    if frame==0:check(fish.global_basis.x.y>0,"Takeoff points upward")
    if frame==fps:check(fish.global_basis.x.y<0,"Landing points downward")
    if frame==fps/2:check(at.y>g.water_level+.5,"Leap follows elevated curve")
    if id!="lakeside":check(at.z>=-18.3 and at.z<=-4,"River leap remains in channel")
    previous=at
   # Exercise the main loop's landing rebase, not just the curve helper.
   g._process(.02)
   check(g.cast_target.distance_to(Vector3(end.x,g.water_level+.05,end.z))<.02,"Landing becomes new retrieval target "+id)
   check(g.hooked_fish.global_position.distance_to(end)<.02,"No teleport at water reentry "+id)
   g.game.cue=-1;g.escape_offset=Vector3.ZERO
 for id in ["lakeside","lake_pier","gray_pier","bell_park_pier","simons_town_rocks","blouberg_sunrise_2"]:
  g.game.reset();g._select_location(id,false)
  check(g.water_surface.mesh.size.x==512,"Water covers the submerged distant land edges "+id)
  check(is_equal_approx(g.water_surface.position.y,g.water_level),"Water surface matches gameplay water height "+id)
  var transitions:=0
  for node in g.foreground.find_children("*","MeshInstance3D",true,false):
   for surface in node.mesh.get_surface_count():
    var mat:Material=node.get_active_material(surface)
    if mat and mat.next_pass:transitions+=1
  check((transitions==0) if id in ["lakeside","gray_pier","bell_park_pier"] else (transitions>0),"Only approved locations use photographic ground transition "+id)
  if "--capture" in OS.get_cmdline_user_args():
   for item in [g.hud,g.rod,g.avatar,g.fish_guide,g.rod_status,g.bobber]:item.hide()
   g.line_mesh.clear_surfaces()
   var output:String="res://test-results/gameplay-video/fixed/"+id
   DirAccess.make_dir_recursive_absolute(output)
   for view in [["front",-.18,0.0],["left",-.2,1.3],["right",-.2,-1.3],["rear",-.18,PI]]:
    g.head.position=Vector3(0,1.65,.65);g.head.rotation=Vector3(view[1],view[2],0)
    for frame in 12:await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(output+"/"+view[0]+".png")
 g.queue_free();await process_frame;await create_timer(.3).timeout
 print("GAMEPLAY_RECORDING_RESULT ",failures);quit(0 if failures.is_empty() else 1)
