extends SceneTree
## Captures the real catch deformation beside a metre ruler, in world units.
func _initialize() -> void: run.call_deferred()
func run() -> void:
 var g=load("res://scenes/main.tscn").instantiate();root.add_child(g)
 await create_timer(.3).timeout
 g.set_process(false);g.motor.set_physics_process(false);g.fishing_feedback.set_process(false)
 g.game.fish_index=1;g.game.journal=[{"length":58.0}];g._show_fish()
 var view:=SubViewport.new();view.size=Vector2i(1200,800);view.own_world_3d=true
 view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
 g.fish_display.reparent(view);g.fish_display.transform=Transform3D.IDENTITY
 g.fish_display.rotation_degrees.y=-35
 var env:=WorldEnvironment.new();env.environment=Environment.new()
 env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("24363b")
 env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_energy=.65
 view.add_child(env)
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-35,-25,0);view.add_child(light)
 var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=1.0
 camera.position=Vector3(0,0,2);view.add_child(camera)
 var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_color=Color("bfe1d3")
 for i in 11:
  var marker:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3(.002,.02,.002)
  marker.mesh=box;marker.material_override=mat;marker.position=Vector3(-.5+i*.1,-.24,0);view.add_child(marker)
 var label:=Label3D.new();label.text="58 cm carp · 10 cm ruler divisions · 170 cm avatar reference"
 label.font_size=26;label.pixel_size=.0008;label.position=Vector3(0,-.30,0);view.add_child(label)
 DirAccess.make_dir_recursive_absolute("res://test-results/catch-twitch")
 for amount in [0.0,-1.0,1.0]:
  g.catch_twitch.set_amount(amount)
  for i in 12: await process_frame
  await RenderingServer.frame_post_draw
  var result:=view.get_texture().get_image().save_png("res://test-results/catch-twitch/bend-"+str(amount)+".png")
  if result!=OK:quit(1);return
 print("CATCH_TWITCH_RENDER_RESULT: neutral and both bends captured")
 g.fish_display.reparent(g);view.queue_free();g._quit_game()
