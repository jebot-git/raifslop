extends SceneTree
const Wire=preload("res://scripts/network/state.gd")
var failures:Array=[]
var checks:=0
var effect=preload("res://tests/xr_capture.gd").new()
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize():run.call_deferred()
func capture(g,label:String):
 for i in 20:await process_frame
 if g.xr:
  effect.request_capture(label)
  for i in 150:
   await process_frame
   if effect.completed==label:break
  check(effect.completed==label and effect.results.size()==2,"Stereo capture "+label)
  for eye in effect.results.size():
   var im:Image=effect.results[eye];im.convert(Image.FORMAT_RGBA8);im.linear_to_srgb();im.save_png("res://test-results/lure/"+label+"_eye%d.png"%eye)
 else:
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://test-results/lure/"+label+".png")
func run():
 var g=load("res://scenes/main.tscn").instantiate();root.add_child(g)
 for i in 400:
  await process_frame
  if not g.avatar_loading:break
 g.set_process(false);g.motor.set_physics_process(false);g.fishing_feedback.set_process(false)
 g.avatar.process_mode=Node.PROCESS_MODE_DISABLED;g.avatar.hide()
 var native:bool=g.xr
 var trackers:Array[XRControllerTracker]=[]
 for side in 2:
  var tracker:=XRControllerTracker.new();tracker.name="lure_control_"+str(side);XRServer.add_tracker(tracker);trackers.append(tracker)
  var controller:XRController3D=g.left if side==0 else g.right;controller.tracker=tracker.name;controller.pose="grip"
  tracker.set_pose("grip",Transform3D(Basis.IDENTITY,Vector3(-.25 if side==0 else .25,1.3,-.4)),Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
  tracker.set_input("primary",Vector2.ZERO);tracker.set_input("primary_click",false);tracker.set_input("grip",0.0);tracker.set_input("trigger",0.0)
 g.xr=true;g.tracking_manager.focused=true;g.menu_open=false;g.fish_guide.held=false;g.rod_holster.stowed=false
 g.game.reset();g._select_location("lakeside",false);g._select_rig(0)
 await process_frame
 g._right_pressed("primary_click");check(g.rig_radial.opened,"Joystick press opens radial")
 g._right_released("primary_click");g.rig_radial.update()
 check(g.rig_radial.opened,"Radial stays open after joystick click is released")
 trackers[1].set_input("primary",Vector2(0,1));await process_frame;g.rig_radial.point(Vector2(0,1))
 if "--capture" in OS.get_cmdline_user_args():
  DirAccess.make_dir_recursive_absolute("res://test-results/lure")
  g.xr=native;g.hud.hide();g.rod.hide();g.rod_status.hide()
  if native:
   var compositor:=Compositor.new();compositor.compositor_effects=[effect];g.head.compositor=compositor
  await capture(g,"radial");g.xr=true
 g.rod.show();g.rod_status.show();g.rig_radial.update();g._right_released("primary_click")
 check(g.rig_radial.opened and g.rig_radial.choice==2 and not g.game.is_lure_fishing(),"Stick up highlights lure without selecting")
 trackers[1].set_input("primary",Vector2.ZERO);await process_frame;g.rig_radial.update()
 check(g.game.is_lure_fishing() and g.rod_visual.lure_mode and not g.rig_radial.opened,"Returning stick to neutral fits lure tackle without holding click")
 check(g.motor.turn_reserved,"Selection keeps turning reserved until stick recentres")
 check(not g.bobber.visible and not g.rod_status.feeder_visual.visible,"Lure has no float or cage")
 g._left_button("ax_button");check(g.game.bait==1,"Offhand bait button selects jig")
 var peer=preload("res://scripts/network/remote_angler.gd").new();peer.session=g.network;root.add_child(peer);peer.set_process(false)
 for location in ["lakeside","boulder_run","fish_hoek_beach"]:
  g.game.reset();g._select_location(location,false);g._select_rig(2)
  for tier in 4:
   g.game.tackle.equipped=tier;g.rod_visual.equip(tier,false,false,true)
   for bait in 3:
    g._select_bait(bait)
    for phase in [0,1,2,3,4,6]:
     g.game.state=phase;g._update_line()
     var d=Wire.capture(g,checks);check(Wire.valid(d),"Valid lure state")
     peer.receive_state(d);peer._process(1)
     check(peer.rod_visual.tier==tier and peer.rod_visual.lure_mode,"Remote casting tackle follows progression")
     check(not peer.float_mesh.visible and not peer.feeder_visual.visible,"Remote lure has no float or cage")
     check(peer.bait_visual.selected==bait and peer.bait_visual.marine==g.game.is_marine_location(location),"Remote exact lure and water variant")
     check(peer.bait_visual.quaternion.is_equal_approx(g.rod_status.bait_visual.quaternion),"Remote lure orientation matches")
    g.game.reset()
 var invalid=Wire.capture(g,checks);invalid.bait=3;check(not Wire.valid(invalid),"Wire rejects fourth lure")
 invalid=Wire.capture(g,checks);invalid.rig=3;check(not Wire.valid(invalid),"Wire rejects unsupported rig")
 # The live avatar target follows the selected style, on desktop and in VR.
 g.xr=false;g._update_avatar(.02)
 check(g.desktop_left.global_position.distance_to(g.crank.to_global(g.rod_visual.crank_grip_position()))<.001,"Desktop hand uses selected reel anchor")
 g.xr=true;g.tracking_manager.calibration_pending=false
 g.game.reset();g._select_location("lakeside",false);g._select_rig(2)
 trackers[1].set_input("primary",Vector2.ZERO)
 for i in 5:await process_frame;g._process(.02)
 g.game.cast(20,Vector3(0,g.water_level,-20),Vector3(0,g.water_level,0));g.game.tick(.81,0,0)
 check(g._sample_lure_motion(.02)==0,"First raw controller sample establishes lure baseline")
 var rod_pose:Transform3D=g.controller_local_pose(1)
 rod_pose.origin.x+=.06
 trackers[1].set_pose("grip",rod_pose,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
 await process_frame
 check(g._sample_lure_motion(.02)>1,"Raw lateral controller motion reaches lure input")
 var original_origin:Transform3D=g.origin.transform
 g.origin.position+=Vector3(.3,0,.2);g.origin.rotate_y(.4)
 check(absf(g._sample_lure_motion(.02))<.001,"Locomotion and turning cannot work a stationary lure")
 g.origin.transform=original_origin
 var head_before:Vector3=g.head.position
 g.head.position.x+=.15
 check(absf(g._sample_lure_motion(.02))<.001,"Head movement cannot twitch a stationary rod")
 g.head.position=head_before
 g.game.timer=100
 var lure_before:Vector3=g.game.cast_position
 var work_pose:Transform3D=g.controller_local_pose(1)
 work_pose.basis=Basis(Vector3.UP,-.2)*work_pose.basis
 trackers[1].set_pose("grip",work_pose,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
 await process_frame
 var side_speed:float=g._sample_lure_motion(.02)
 g.game.tick(.02,0,0,false,side_speed);g._update_line()
 check(g.game.cast_position.x>lure_before.x+.1,"Wrist twitch moves actual tackle laterally without reeling")
 g.fishing_feedback._process(.02)
 check(g.fishing_feedback.surface.visible and g.fishing_feedback.water_fx.get_shader_parameter("strength")>.05,"Tracked lure twitch creates visible water ripples")
 check(absf(g.fishing_feedback.surface.global_position.y-g.water_level-.045)<.001,"Lure ripple remains on water above submerged tackle")
 check(g.fishing_feedback.water_fx.get_shader_parameter("directional"),"Sideways twitch has directional ripples without reeling")
 var wake:Vector2=g.fishing_feedback.water_fx.get_shader_parameter("heading")
 check(wake.x>.99,"Rightward wrist twitch points the wake right")
 g.game.tick(.02,0,0,false,-4);g._update_line();g.fishing_feedback._process(.02)
 wake=g.fishing_feedback.water_fx.get_shader_parameter("heading")
 check(wake.x<-.99,"Reversing the twitch immediately reverses the ripple")
 g.game.tick(.05,0,0);g._update_line();g.fishing_feedback._process(.05)
 wake=g.fishing_feedback.water_fx.get_shader_parameter("heading")
 check(wake.x<-.99,"Lateral settling does not falsely reverse the twitch ripple")
 g.game.tick(2,0,0);g.fishing_feedback._process(.02)
 check(not g.fishing_feedback.surface.visible,"Unworked lure ripple stops after its pause window")
 g.rod.position.x+=.1
 check(absf(g._sample_lure_motion(.02))<.001,"Rendered IK rod movement cannot feed back into lure input")
 g.game.reset()
 for input in ["grip","trigger"]:
  g.game.reset();g.game.state=g.Session.State.BITE;g.game.fish_index=2;g.game.strike()
  g.game.jumps_enabled=false;g.game.next_cue=100;g.game.next_submerge=100;g.game.distance=20
  var at:Vector3=g.origin.to_local(g.crank.to_global(g.rod_visual.crank_grip_position()))
  trackers[0].set_pose("grip",Transform3D(Basis.IDENTITY,at),Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
  trackers[0].set_input(input,1.0)
  for i in 3:await process_frame
  g._process(.02)
  check(g.reel_tracker.engaged,"Tracked offhand grabs casting reel using "+input)
  check(g.desktop_left.global_position.distance_to(g.crank.to_global(g.rod_visual.crank_grip_position()))<.001,"VR hand snaps to casting paddle")
  var before:float=g.crank.rotation.x
  var angle:float=g.reel_tracker.previous_angle+.16
  var raw_rod:Transform3D=g.right.transform*g.rod_holster.HELD_POSE
  at=raw_rod*(g.crank.position+Vector3(-.02,cos(angle)*.045,sin(angle)*.045)-g.reel_tracking_offset)
  trackers[0].set_pose("grip",Transform3D(Basis.IDENTITY,at),Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
  for i in 3:await process_frame
  g._process(.02)
  check(absf(g.crank.rotation.x-before)>.1 and not g.game.fly_reel_penalty,"Tracked lure crank winds without fly strain penalty")
  trackers[0].set_input(input,0.0)
  for i in 3:await process_frame
  g._process(.02);check(not g.reel_tracker.engaged,"Releasing controller frees casting reel")
 # Both paddles use the same tracked crank plane and ordinary reeling input.
 g.game.reset();g._select_location("lakeside",false);g._select_rig(2)
 var reel=preload("res://scripts/reel_tracker.gd").new()
 var grip:Vector3=g.rod_visual.crank_grip_position()
 for sign in [-1,1]:
  reel.engaged=false
  reel.sample(grip*sign,true,.02)
  check(reel.engaged,"Either lure paddle can be grabbed")
  var rate:float=reel.sample(Basis(Vector3.RIGHT,.16)*(grip*sign),true,.02)
  check(rate>1 and reel.angular_delta>.1,"Compact double paddle produces reel input")
  reel.sample(grip,false,.02);check(not reel.engaged,"Release frees lure reel")
 g.game.rig=0;g._load_player_preferences();check(g.game.rig==2,"Lure choice persists")
 if "--capture" in OS.get_cmdline_user_args():
  peer.hide();g.xr=native;g.rod.hide();g.rod_status.hide();g.bobber.hide();g.line_mesh.clear_surfaces()
  var inspection:=OmniLight3D.new();g.head.add_child(inspection);inspection.position=Vector3(.1,.3,.1);inspection.omni_range=2;inspection.light_energy=.7
  var display=preload("res://scripts/rod_visual.gd").new();g.head.add_child(display)
  for tier in 4:
   display.equip(tier,false,false,true)
   display.transform=Transform3D(Basis(Vector3.UP,-PI/2),Vector3(0,.03,-.45))
   await capture(g,"casting-"+display.MODELS[tier])
  display.equip(3,false,false,true);display.rotate_object_local(Vector3.UP,PI);await capture(g,"casting-crank")
  display.queue_free()
  var lures=Node3D.new();g.head.add_child(lures)
  for i in 4:
   var bait=preload("res://scripts/bait_visual.gd").new();lures.add_child(bait);bait.set_bait(i%3,i==3,false,true)
   bait.position=Vector3((i-1.5)*.095,.08,-.45)
  await capture(g,"lures");lures.queue_free()
 g.head.compositor=null;g.xr=false
 for tracker in trackers:XRServer.remove_tracker(tracker)
 peer.queue_free();g.queue_free();await process_frame;await create_timer(.3).timeout
 print("LURE_INTERFACE_RESULT ",checks," checks, ",failures);quit(0 if failures.is_empty() else 1)
