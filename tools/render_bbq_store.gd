extends SceneTree
func _initialize()->void:run.call_deferred()
func run()->void:
 var viewport:=SubViewport.new();viewport.size=Vector2i(2560,1440);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var game=load("res://scenes/main.tscn").instantiate();viewport.add_child(game)
 await create_timer(.5).timeout;game.set_process(false);game.motor.set_physics_process(false)
 game.bbq.visit();await create_timer(.8).timeout
 game.head.global_position=game.bbq.station.global_position+Vector3(2,1.8,2.6)
 game.head.look_at(game.bbq.station.global_position+Vector3(0,.8,0))
 if is_instance_valid(game.avatar):game.avatar.hide()
 game.hud.hide()
 await create_timer(.5).timeout;await RenderingServer.frame_post_draw
 var frame:Image=viewport.get_texture().get_image();frame.convert(Image.FORMAT_RGB8)
 var code:=frame.save_png("res://test-results/minigolf-store/bbq-lakeside.png");print("BBQ_STORE ",code)
 game.ambience.stop();game.queue_free();await process_frame;quit(code)
