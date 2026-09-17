extends SceneTree
func _initialize():run.call_deferred()
func run():
 var view:=SubViewport.new();view.size=Vector2i(1400,900);view.own_world_3d=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
 var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("253640");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.65;view.add_child(env)
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-30,-25,0);light.light_energy=.9;view.add_child(light)
 var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=1.15;camera.position=Vector3(0,0,3);view.add_child(camera)
 var fish=load("res://assets/models/fish/leervis.glb").instantiate();view.add_child(fish)
 var twitch=preload("res://scripts/catch_twitch.gd").new();twitch.configure(fish,preload("res://scripts/fish_size.gd").bounds(fish),37)
 DirAccess.make_dir_recursive_absolute("res://test-results/fishing-repairs")
 for pose in [Vector2(0,0),Vector2(.8,1),Vector2(-.8,-1)]:
  fish.rotation.y=pose.x;twitch.set_amount(pose.y)
  await capture(view,"leervis-"+str(pose.y))
 fish.free();camera.size=.25
 for i in 4:
  var cage=load("res://assets/models/rods/cage_feeder.glb").instantiate();view.add_child(cage);cage.position=Vector3((i-1.5)*.060,.03,0)
  var bait=preload("res://scripts/bait_visual.gd").new();cage.add_child(bait);bait.set_bait([0,1,3,4][i],false,false,false,true)
 await capture(view,"feeder-contents")
 view.queue_free();await process_frame;print("FISHING_REPAIRS_RENDER_RESULT []");quit()
func capture(view:SubViewport,label:String):
 for i in 8:await process_frame
 await RenderingServer.frame_post_draw
 var error:=view.get_texture().get_image().save_png("res://test-results/fishing-repairs/"+label+".png")
 if error!=OK:quit(1)
