extends SceneTree
func _initialize()->void:run.call_deferred()
func run()->void:
 var id:String=OS.get_cmdline_user_args()[0]
 preload("res://scripts/locations.gd").save_location(id)
 var viewport:=SubViewport.new();viewport.size=Vector2i(2560,1440);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var game=load("res://scenes/main.tscn").instantiate();viewport.add_child(game)
 await create_timer(.5).timeout;game.set_process(false);game.motor.set_physics_process(false)
 if game.current_location!=id:game._select_location(id,false)
 game.golf_activity.ensure_world();game.golf_activity.set_process(false)
 game.rod_holster.set_stowed(true);game.hud.hide()
 if is_instance_valid(game.avatar):game.avatar.hide()
 game.head.global_position=Vector3(-7,8,34);game.head.look_at(Vector3(-14,2,18));game.head.fov=62
 await create_timer(1.2).timeout;await RenderingServer.frame_post_draw
 var frame:Image=viewport.get_texture().get_image();frame.convert(Image.FORMAT_RGB8)
 var folder:="res://test-results/minigolf-store";DirAccess.make_dir_recursive_absolute(folder)
 var code:=frame.save_png(folder+"/course_"+id+".png");print("STORE_IMAGE ",id," ",code)
 var audit:="res://test-results/minigolf-environment-audit";DirAccess.make_dir_recursive_absolute(audit)
 viewport.size=Vector2i(1600,900)
 for view in ["shore","arrival","rear","overview"]:
  match view:
   "shore":game.head.global_position=Vector3(0,1.65,6);game.head.look_at(Vector3(0,2.5,35))
   "arrival":game.head.global_position=Vector3(0,3.65,27);game.head.look_at(Vector3(0,2.6,13))
   "rear":game.head.global_position=Vector3(20,3.65,64);game.head.look_at(Vector3(0,2.5,35))
   "overview":game.head.global_position=Vector3(42,39,89);game.head.look_at(Vector3(0,2,38))
  await create_timer(.25).timeout;await RenderingServer.frame_post_draw
  var image:Image=viewport.get_texture().get_image();image.convert(Image.FORMAT_RGB8);image.save_png(audit+"/"+id+"-"+view+".png")
  print("ENVIRONMENT_AUDIT ",id," ",view)
 game.ambience.stop();game.queue_free();await process_frame;quit(code)
