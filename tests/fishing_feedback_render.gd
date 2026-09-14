extends SceneTree
func _initialize():run.call_deferred()
func run():
 var g=load("res://scenes/main.tscn").instantiate();root.add_child(g)
 await create_timer(.4).timeout
 g.set_process(false);g.motor.set_physics_process(false);g.fishing_feedback.set_process(false)
 g._cast(7);g.game.state=g.Session.State.FIGHT;g.game.tension=.9
 g.game.distance=7;g.game.cue=0;g.escape_offset=g.fish_escape_direction()*.8
 g.head.look_at(g.cast_target+Vector3.UP*.6)
 g.game.message="Fish running right · sweep the rod left to counter."
 g._update_line();g.fishing_feedback._process(.1);g.hud.queue_redraw()
 for i in range(20):await process_frame
 await RenderingServer.frame_post_draw
 var result=root.get_texture().get_image().save_png("res://docs/fishing_wake.png")
 print("FISHING_FEEDBACK_RENDER ",result)
 g.queue_free();await process_frame;quit(0 if result==OK else 1)
