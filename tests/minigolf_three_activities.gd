extends SceneTree
var game
var failures:Array=[]
var role:String
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func until(fn:Callable,seconds:=35.0)->bool:
 var deadline:=Time.get_ticks_msec()+int(seconds*1000)
 while Time.get_ticks_msec()<deadline:
  if fn.call():return true
  await create_timer(.05).timeout
 return false
func run()->void:
 role=OS.get_cmdline_user_args()[0]
 # Keep three full clients within the test machine's RAM; gameplay geometry stays unchanged.
 for entry in preload("res://scripts/locations.gd").CATALOG:entry.panorama=entry.preview
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);current_scene=game
 await create_timer(.5).timeout
 game.set_process(false);game.motor.set_physics_process(false);game.head.position=Vector3(0,1.65,0)
 game.network.display_name=role;game.network.voice_enabled=false
 if role=="golfer":game.network.host(28976)
 else:game.network.join("127.0.0.1",28976)
 check(await until(func():return game.network.players.size()==3),"Three full-scene players connected")
 check(await until(func():return game.network.states.size()==3),"All initial player poses reached the server")
 await create_timer(.5).timeout
 if role=="golfer":
  game.golf_activity.enter("lakeside");game.golf_activity.update_player(.016)
 elif role=="cook":
  game.bbq.visit();await create_timer(.8).timeout
 else:
  game.game.state=game.Session.State.WAITING
  game.bobber.global_position=Vector3(0,0,-5);game.bobber.show();game.cast_target=game.bobber.global_position
  game.head.look_at(Vector3(0,1,-5))
 var coexist:bool=await until(func():
  var putting:=false;var fishing:=false
  for state in game.network.states.values():
   putting=putting or state.golf_club==7
   fishing=fishing or (state.golf_club==-1 and state.state==game.Session.State.WAITING and state.bobber_visible)
  return putting and fishing and game.network.bbq.model.stations.has("lakeside"))
 check(coexist,"Fishing, BBQ and minigolf coexist in one live scene")
 if not coexist:
  print("STATIONS ",game.network.bbq.model.stations.keys())
  for state in game.network.states.values():print("ACTIVITY ",state.golf_club," ",state.state," ",state.bobber_visible)
 check(await until(func():return game.network.fighters.size()==2),"Both other players have remote scene representations")
 for state in game.network.states.values():check(state.location=="lakeside","Shared water identity")
 await create_timer(3).timeout
 if role=="golfer":game.golf_activity.update_player(.016)
 else:game._update_avatar(.016)
 game.head.global_position=game.motor.global_position+Vector3(0,1.65,0)
 if role=="cook" and is_instance_valid(game.bbq.station):game.head.look_at(game.bbq.station.global_position+Vector3(0,.9,0))
 elif role=="golfer":game.head.look_at(game.golf_activity.ball_position())
 DirAccess.make_dir_recursive_absolute("res://test-results/minigolf-three-activities")
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://test-results/minigolf-three-activities/"+role+".png")
 await create_timer(8).timeout
 game.network.leave();game.ambience.stop();game.queue_free();await process_frame
 print("THREE_ACTIVITIES ",role," ",failures);quit(0 if failures.is_empty() else 1)
