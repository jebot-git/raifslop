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
   var im:Image=effect.results[eye];im.convert(Image.FORMAT_RGBA8);im.linear_to_srgb();im.save_png("res://test-results/feeder/"+label+"_eye%d.png"%eye)
 else:
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://test-results/feeder/"+label+".png")
func run():
 var g=load("res://scenes/main.tscn").instantiate();root.add_child(g)
 for i in 400:
  await process_frame
  if not g.avatar_loading:break
 g.set_process(false);g.motor.set_physics_process(false);g.fishing_feedback.set_process(false)
 g.avatar.process_mode=Node.PROCESS_MODE_DISABLED;g.avatar.hide()
 var native:bool=g.xr
 # Scripted tracked controller input also runs in the headless regression suite.
 var tracker:=XRControllerTracker.new();tracker.name="feeder_right";XRServer.add_tracker(tracker)
 g.right.tracker=tracker.name;g.right.pose="grip"
 tracker.set_pose("grip",Transform3D(Basis.IDENTITY,Vector3(.25,1.3,-.4)),Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
 tracker.set_input("primary",Vector2.ZERO);tracker.set_input("primary_click",false)
 g.xr=true;g.tracking_manager.focused=true;g.menu_open=false;g.fish_guide.held=false;g.rod_holster.stowed=false
 g.game.reset();g._select_location("lakeside",false);g._select_rig(0)
 await process_frame
 g._right_pressed("primary_click");check(g.rig_radial.opened,"Joystick press opens radial")
 g._right_released("primary_click");g.rig_radial.update()
 check(g.rig_radial.opened and g.game.rig==0,"Releasing stick click leaves radial open without selecting")
 var motor_xr:bool=g.motor.xr
 g.motor.xr=true;g.motor.tracking_focused=true
 g.motor._physics_process(1.0/90)
 check(g.motor.turn_reserved,"Neutral stick cannot release turning while radial remains open")
 tracker.set_input("primary",Vector2.RIGHT);await process_frame;g.rig_radial.point(Vector2.RIGHT)
 var facing:Basis=g.origin.basis
 g.motor._physics_process(1.0/90)
 check(g.origin.basis.is_equal_approx(facing),"Selecting a direction does not turn the player")
 g.motor.xr=motor_xr
 g._right_pressed("trigger_click");check(not g.casting,"Radial consumes cast trigger")
 if "--capture" in OS.get_cmdline_user_args():
  DirAccess.make_dir_recursive_absolute("res://test-results/feeder")
  g.xr=native;g.hud.hide();g.rod.hide();g.rod_status.hide()
  if native:
   var compositor:=Compositor.new();compositor.compositor_effects=[effect];g.head.compositor=compositor
  await capture(g,"radial")
  g.xr=true
 g.rod_status.show();g.rod.show()
 g.rig_radial.update()
 check(g.motor.turn_reserved and g.motor.radial_open and g.game.rig==0,"Highlighted choice keeps radial open and reserves turning")
 for direction in [Vector2(0,1),Vector2.LEFT,Vector2.RIGHT]:
  tracker.set_input("primary",direction);await process_frame;g.rig_radial.update()
  check(g.rig_radial.opened and g.game.rig==0,"Rotating the stick previews without selecting")
 check(g.rig_radial.choice==1,"Last pointed style stays highlighted")
 tracker.set_input("primary",Vector2(.3,0));await process_frame;g.rig_radial.update()
 check(g.rig_radial.opened and g.rig_radial.choice==1,"Returning through dead zone retains the highlight")
 tracker.set_input("primary",Vector2.ZERO);await process_frame;g.rig_radial.update()
 g._right_released("primary_click")
 check(g.game.is_feeder_fishing() and not g.rig_radial.opened,"Returning stick to neutral selects feeder without holding click")
 check(g.rod_visual.feeder_mode and g.rod_visual.quiver.visible,"Feeder rod fitted with quiver tip")
 check(not g.bobber.visible and g.rod_status.feeder_visual.visible,"Feeder replaces float")
 var anchor:Vector3=g.tip.position;g.game.state=g.Session.State.BITE;g.time+=.1;g._update_line()
 check(g.tip.position==anchor,"Quiver animation cannot trigger a hook-setting gesture")
 g.game.state=g.Session.State.WAITING;g.game.feeder.begin_nibbles(g.game.rng);g._update_line()
 var nibble_bend:float=-g.rod_visual.quiver.end.y
 check(g.rod_status.active_icon()=="stop","Nibble cue asks the player to wait")
 g.game.feeder.tick(.3);g._update_line()
 check(-g.rod_visual.quiver.end.y<nibble_bend,"Light tip pulse relaxes between nibbles")
 g.game.feeder.bite_age=0;g.game.state=g.Session.State.BITE;g._update_line()
 check(-g.rod_visual.quiver.end.y>nibble_bend*2,"Real bite produces a larger visible quiver pulse")
 g.game.feeder.tick(.5);g._update_line()
 check(is_equal_approx(-g.rod_visual.quiver.end.y,.05) and g.tip.position==anchor,"Bite pulse settles without moving the input anchor")
 g.game.reset()
 g._select_bait(2);g.rod_status.update_bait()
 check(g.rod_status.bait_visual.selected==3 and g.rod_status.bait_visual.feeder_mode,"Maggots packed inside feeder cage")
 var peer=preload("res://scripts/network/remote_angler.gd").new();peer.session=g.network;root.add_child(peer);peer.set_process(false)
 for location in ["lakeside","meadow_bend"]:
  g.game.reset();g._select_location(location,false);g._select_rig(1)
  for bait in 4:
   g._select_bait(bait)
   for phase in [0,1,2,3,4,6]:
    g.game.state=phase;g._update_line()
    var d=Wire.capture(g,checks);check(Wire.valid(d),"Valid feeder state")
    peer.receive_state(d);peer._process(1)
    check(g.rod_status.bait_visual.global_position.is_equal_approx(g.rod_status.feeder_visual.global_position),"Local feeder bait stays inside cage in every phase")
    check(peer.bait_visual.global_position.is_equal_approx(peer.feeder_visual.global_position),"Remote feeder bait stays inside cage")
    check(peer.feeder_visual.visible==g.rod_status.feeder_visual.visible,"Remote feeder visibility")
    check(not peer.float_mesh.visible and not peer.rod_visual.fly_mode,"Remote feeder has no float or fly reel")
    check(peer.bait_visual.selected==g.game.bait_model() and peer.bait_visual.feeder_mode,"Remote cage contents match selected bait")
   for piece in g.rod_status.bait_visual.get_children():
    check(not "Hook" in piece.name,"Cage contents have no external hook")
    var bounds:AABB=piece.transform*piece.get_aabb()
    check(bounds.position.y>=-.066 and bounds.end.y<=-.014 and maxf(absf(bounds.position.x),absf(bounds.end.x))<.022 and maxf(absf(bounds.position.z),absf(bounds.end.z))<.022,"Selected food fits inside cage")
   g.game.reset()
 var invalid=Wire.capture(g,checks);invalid.location="boulder_run";check(not Wire.valid(invalid),"Wire rejects rig at unsupported location")
 invalid=Wire.capture(g,checks);invalid.bait=5;check(not Wire.valid(invalid),"Wire rejects invalid feeder bait")
 g.game.reset();g._select_location("lakeside",false);g._select_rig(1)
 tracker.set_input("primary",Vector2.RIGHT);await process_frame
 g._right_pressed("primary_click");g.rig_radial.update()
 check(g.rig_radial.opened and g.game.rig==1,"Opening with deflected stick waits for centre")
 tracker.set_input("primary",Vector2.ZERO);await process_frame;g.rig_radial.update()
 check(g.rig_radial.opened and g.rig_radial.selection_ready,"Neutral stick keeps menu open and arms selection")
 tracker.set_input("primary",Vector2(0,1));await process_frame;g.rig_radial.update()
 check(g.rig_radial.choice==2 and g.game.rig==1,"Highlighting another style does not equip it")
 g._right_pressed("primary_click");g._right_released("primary_click")
 check(not g.rig_radial.opened and g.game.rig==1,"Second click cancels a highlighted choice without changing rig")
 tracker.set_input("primary",Vector2.ZERO);await process_frame
 g.game.rig=0;g._load_player_preferences()
 check(g.game.rig==1,"Selected feeder survives preferences reload")
 g.xr=native
 g._right_pressed("primary_click");g._right_pressed("by_button")
 check(g.menu_open and not g.rig_radial.opened,"Menu button dismisses radial")
 g._right_pressed("by_button");g.xr=true
 g._right_pressed("primary_click");g.tracking_manager.focused=false;g.rig_radial.update()
 check(not g.rig_radial.opened and g.game.rig==1,"Tracking focus loss cancels radial")
 g.tracking_manager.focused=true;g.game.state=g.Session.State.FIGHT
 check(not g.rig_radial.open(),"Fight cannot open rig selector")
 g.game.reset();g._select_location("boulder_run",false)
 check(g.game.rig==0 and g.game.is_fly_fishing(),"Travel to trout stream restores fly tackle")
 g.rod_visual.equip(0,true)
 check(is_equal_approx(g.crank.position.x,-.036),"Fly crank sits on spool face")
 g._right_pressed("primary_click");g._right_released("primary_click")
 tracker.set_input("primary",Vector2.RIGHT);await process_frame;g.rig_radial.update()
 check(g.rig_radial.opened and g.game.rig==0,"Unavailable feeder keeps menu open without changing rig")
 tracker.set_input("primary",Vector2.ZERO);await process_frame;g.rig_radial.update()
 check(g.rig_radial.opened and g.game.rig==0,"Returning from unavailable style does not select or close")
 tracker.set_input("primary",Vector2(0,1));await process_frame;g.rig_radial.update()
 check(g.rig_radial.opened and g.rig_radial.choice==2 and g.game.rig==0,"Available style stays highlighted after unavailable option")
 tracker.set_input("primary",Vector2.ZERO);await process_frame;g.rig_radial.update()
 check(not g.rig_radial.opened and g.game.rig==2,"Neutral confirms available style after unavailable option")
 g.xr=false
 var tab:=InputEventKey.new();tab.keycode=KEY_TAB;tab.pressed=true
 g._unhandled_input(tab);tab.pressed=false;g._unhandled_input(tab)
 check(g.rig_radial.opened,"Desktop Tab tap leaves radial open after release")
 var arrow:=InputEventKey.new();arrow.keycode=KEY_LEFT;arrow.pressed=true
 Input.parse_input_event(arrow);Input.flush_buffered_events();g.rig_radial.update()
 check(g.rig_radial.opened and g.game.rig==2,"Desktop arrow highlights without selecting")
 var arrow_release:InputEventKey=arrow.duplicate();arrow_release.pressed=false
 Input.parse_input_event(arrow_release);Input.flush_buffered_events();g.rig_radial.update()
 check(not g.rig_radial.opened and g.game.rig==0,"Desktop arrow release confirms without holding Tab")
 tab.pressed=true;g._unhandled_input(tab);tab.pressed=false;g._unhandled_input(tab)
 tab.pressed=true;g._unhandled_input(tab);tab.pressed=false;g._unhandled_input(tab)
 check(not g.rig_radial.opened,"Second Tab tap cancels desktop radial")
 if "--capture" in OS.get_cmdline_user_args():
  peer.hide();g.game.reset();g._select_location("lakeside",false)
  g.xr=native;g.rod.hide();g.rod_status.hide();g.bobber.hide();g.line_mesh.clear_surfaces()
  var inspection:=OmniLight3D.new();g.add_child(inspection);inspection.global_position=g.head.global_position+Vector3(.1,.3,.1);inspection.omni_range=2;inspection.light_energy=.6
  var display=preload("res://scripts/rod_visual.gd").new();g.head.add_child(display);display.equip(0,true)
  display.transform=Transform3D(Basis(Vector3.UP,-PI/2),Vector3(0,.03,-.45))
  await capture(g,"fly-reel")
  display.rotate_object_local(Vector3.UP,PI);await capture(g,"fly-reel-crank")
  display.equip(0,false,true);display.update_tip(3,.06)
  display.transform=Transform3D(Basis(Vector3.UP,PI/2),Vector3(.65,.06,-1.5))
  await capture(g,"feeder-rod")
  display.queue_free()
  var cage=load("res://assets/models/rods/cage_feeder.glb").instantiate();g.head.add_child(cage)
  cage.transform=Transform3D(Basis.IDENTITY,Vector3(0,.03,-.38))
  await capture(g,"cage")
  cage.queue_free()
 g.head.compositor=null;g.xr=false;XRServer.remove_tracker(tracker);peer.queue_free();g.queue_free();await process_frame
 # Let the audio server retire ambience playbacks before the test exits.
 await create_timer(.3).timeout
 print("FEEDER_INTERFACE_RESULT ",checks," checks, ",failures);quit(0 if failures.is_empty() else 1)
