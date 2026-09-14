extends SceneTree
func _initialize():run.call_deferred()
func run():
 var g=load("res://scenes/main.tscn").instantiate();root.add_child(g)
 await create_timer(.5).timeout
 g.hud.hide();g.set_process(false);g.motor.set_physics_process(false)
 for entry in g.Locations.CATALOG:
  g._select_location(entry.id,false);g.hud.hide()
  g.head.rotation_degrees.x=-25
  for i in range(20):await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://docs/locations/"+entry.id+"_soft_lighting.png")
 print("LIGHTING_RENDER_COMPLETE")
 g.queue_free();await process_frame;quit()
