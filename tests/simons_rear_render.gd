extends SceneTree
func _initialize():run.call_deferred()
func run():
 var g=load("res://scenes/main.tscn").instantiate();root.add_child(g)
 await create_timer(.4).timeout
 g.set_process(false);g.motor.set_physics_process(false);g.line_mesh.clear_surfaces()
 for item in [g.hud,g.rod,g.avatar,g.fish_guide,g.rod_status,g.bobber]:item.hide()
 if not g._select_location("simons_town_rocks",false):quit(1);return
 var details=g.foreground.get_node("RearRockTransitions")
 if details.get_node("CurvedRockCards").multimesh.instance_count!=2:quit(1);return
 if "--before" in OS.get_cmdline_user_args():details.hide()
 var camera:=Camera3D.new();g.add_child(camera);camera.current=true
 for view in ["standing","seated","left","right","rear_edge"]:
  camera.position=Vector3(-3 if view=="left" else 3 if view=="right" else 0,1.15 if view=="seated" else 1.7,2)
  if view=="rear_edge":camera.position=Vector3(3.8,1.7,6.3)
  camera.look_at(Vector3(0,1,10))
  for i in 12:await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://test-results/simons-rear-"+("before-" if "--before" in OS.get_cmdline_user_args() else "after-")+view+".png")
 print("SIMONS_REAR_RENDER_RESULT: 5 viewpoints captured")
 g.queue_free();await process_frame;quit()
