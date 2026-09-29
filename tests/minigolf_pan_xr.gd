extends SceneTree
## Native stereo audit: turn in place from the course toward the shore.
var capture=preload("res://tests/xr_capture.gd").new()
func _initialize()->void:run.call_deferred()
func run()->void:
 var id:String=OS.get_cmdline_user_args()[0]
 preload("res://scripts/locations.gd").save_location(id)
 var folder:="res://test-results/minigolf-vr-pan/"+id
 DirAccess.make_dir_recursive_absolute(folder)
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);current_scene=game
 await create_timer(1).timeout
 game.set_process(false);game.motor.set_physics_process(false)
 if not game.xr or not game.head.get_viewport().use_xr:
  push_error("Native OpenXR stereo required");quit(1);return
 game.golf_activity.enter(id);game.golf_activity.set_process(false)
 game.rod_holster.set_stowed(true);game.hud.hide()
 if is_instance_valid(game.avatar):game.avatar.hide()
 var comp:=Compositor.new();comp.compositor_effects=[capture];game.head.compositor=comp
 # Rear gallery has the widest view of course edges and the panorama behind it.
 game.motor.global_position=Vector3(0,2,64)
 game.motor.rotation=Vector3.ZERO
 var start:Basis=game.motor.global_basis
 var origin:Vector3=game.motor.global_position
 # Prime GPU readback after attaching the compositor. Its first resolved
 # buffer can precede sky initialization; never include that warm-up in evidence.
 capture.request_capture("warmup")
 var warmup_deadline:=Time.get_ticks_msec()+12000
 while capture.completed!="warmup" and Time.get_ticks_msec()<warmup_deadline:await process_frame
 var angles:Array=[]
 if "--zero-only" in OS.get_cmdline_user_args():angles=[0]
 else:
  for angle in range(0,181,15):angles.append(angle)
 for degrees in angles:
  game.motor.global_basis=Basis(Vector3.UP,deg_to_rad(float(degrees)))*start
  await create_timer(.7).timeout
  var label:="yaw-%03d"%degrees
  capture.request_capture(label)
  var deadline:=Time.get_ticks_msec()+12000
  while capture.completed!=label and Time.get_ticks_msec()<deadline:await process_frame
  if capture.completed!=label or capture.results.size()!=2:
   push_error("Stereo capture missing: "+label);quit(1);return
  for eye in 2:
   var frame:Image=capture.results[eye];frame.convert(Image.FORMAT_RGBA8);frame.linear_to_srgb()
   frame.save_png(folder+"/%s-eye%d.png"%[label,eye])
  print("VR_PAN ",id," ",degrees," headset=",game.head.global_transform," position_fixed=",game.motor.global_position.is_equal_approx(origin))
 game.ambience.stop();game.queue_free();await process_frame
 print("MINIGOLF_VR_PAN_PASS ",id);quit(0)
