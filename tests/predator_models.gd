extends SceneTree
const Session=preload("res://scripts/fishing_session.gd")
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
 if not ok:push_error(label);quit(1)
func run():
 await gallery()
 print("PREDATOR_MODELS_RESULT passed")
 quit()
func gallery() -> void:
    var view:=SubViewport.new();view.size=Vector2i(1400,1000);view.own_world_3d=true
    view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
    var env:=WorldEnvironment.new();env.environment=Environment.new()
    env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("172b30")
    env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
    env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.75;view.add_child(env)
    var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-30,-25,0);light.light_energy=.9;view.add_child(light)
    var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=1.75
    camera.position=Vector3(0,0,4);view.add_child(camera)
    for i in 2:
        var species: Dictionary=Session.SPECIES[i+26]
        var fish=load(species.model).instantiate();fish.position=Vector3(0,.36-i*.73,0)
        fish.rotation.y=.16;view.add_child(fish)
        var label:=Label3D.new();label.text=species.name+" · "+str(species.length)+" cm"
        label.font_size=25;label.pixel_size=.0014;label.position=fish.position+Vector3(0,-.3,.15);view.add_child(label)
    for i in 16:await process_frame
    await RenderingServer.frame_post_draw
    DirAccess.make_dir_recursive_absolute("res://test-results/predator-fish")
    check(view.get_texture().get_image().save_png("res://test-results/predator-fish/gallery.png")==OK,"Gallery saved")
    view.queue_free()
