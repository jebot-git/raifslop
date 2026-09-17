extends SceneTree
const S=preload("res://scripts/fishing_session.gd")
const Size=preload("res://scripts/fish_size.gd")
var failures:Array=[]
var checks:=0
var g
var effect=preload("res://tests/xr_capture.gd").new()
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize():run.call_deferred()
func line_count(text:String,size_:int)->int:
 var font=ThemeDB.fallback_font;var line:="";var lines:=1
 for word in text.split(" "):
  var next:String=word if line.is_empty() else line+" "+word
  if font.get_string_size(next,HORIZONTAL_ALIGNMENT_LEFT,-1,size_).x>565:lines+=1;line=word
  else:line=next
 return lines
func run():
 g=load("res://scenes/main.tscn").instantiate();root.add_child(g)
 await create_timer(.4).timeout
 g.set_process(false);g.motor.set_physics_process(false);g.fishing_feedback.set_process(false)
 var peer=preload("res://scripts/network/remote_angler.gd").new();peer.session=g.network;root.add_child(peer);peer.set_process(false)
 for index in range(38,40):
  var species:Dictionary=S.SPECIES[index]
  for ratio in [.85,1.0,1.15]:
   g.game.fish_index=index;g.game.journal.assign([species.duplicate()]);g.game.journal[0].length=species.length*ratio;g._show_fish()
   peer._build_fish(index,species.length*ratio)
   var local: AABB=Size.bounds(g.fish_display);var remote:AABB=Size.bounds(peer.caught)
   check(absf(local.size.x-species.length*ratio*.01)<.002,"Local catch length scales correctly")
   check(absf(remote.size.x-local.size.x)<.002,"Remote catch length matches local")
  var model=load(species.model).instantiate()
  var meshes=model.find_children("*","MeshInstance3D",true,false)
  check(meshes.size()==1,"One mesh per authored fish")
  var triangles:=0;var skin:=false;var normal:=false;var eyes:=false;var fins:=false
  for mesh in meshes:
   for surface in mesh.mesh.get_surface_count():
    var mat:StandardMaterial3D=mesh.mesh.surface_get_material(surface)
    var arrays=mesh.mesh.surface_get_arrays(surface)
    triangles+=arrays[Mesh.ARRAY_INDEX].size()/3
    check(mat.albedo_texture!=null and arrays[Mesh.ARRAY_TEX_UV].size()>0,"Every fish surface has UV texture")
    skin=skin or "skin" in mat.resource_name
    normal=normal or mat.normal_enabled and mat.normal_texture!=null
    eyes=eyes or "cornea" in mat.resource_name
    fins=fins or "fin membranes" in mat.resource_name
   var bounds:AABB=Size.bounds(model)
   check(is_equal_approx(bounds.size.x,1.0) and bounds.size.z>.01 and bounds.size.y>.1,"Normalized volumetric mesh faces +X")
  check(skin and normal and eyes and fins,"Distinct skin, baked normal, fins and eyes")
  check(triangles<35000,"Fish stays within authored triangle budget")
  model.free()
 g.fish_guide.ingest(S.SPECIES)
 for entry in g.fish_guide.ordered_entries():
  check(line_count("WATERS · "+entry.waters,20)<=2,"Guide waters fit above description: "+entry.name)
  check(line_count(entry.description,20)<=4,"Guide description fits above personal best: "+entry.name)
  for text in ["PREFERRED BAIT · "+entry.bait,"METHODS · "+entry.methods]:check(ThemeDB.fallback_font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,23).x<=568,"Guide detail fits width: "+entry.name)
 if "--capture" in OS.get_cmdline_user_args():
  DirAccess.make_dir_recursive_absolute("res://test-results/predator-expansion")
  await gallery()
  for index in range(38,40):
   g.fish_guide.selected=index;g.fish_guide.screen.queue_redraw()
   for i in 3:await process_frame
   await RenderingServer.frame_post_draw
   g.fish_guide.viewport.get_texture().get_image().save_png("res://test-results/predator-expansion/guide-%d.png"%index)
  if g.xr:
   var compositor:=Compositor.new();compositor.compositor_effects=[effect];g.head.compositor=compositor
   g.avatar.hide();g.avatar.process_mode=Node.PROCESS_MODE_DISABLED;g.hud.hide();g.rod.hide();g.rod_status.hide();g.fish_display.hide();g.bobber.hide();g.line_mesh.clear_surfaces();peer.hide()
   var fill:=OmniLight3D.new();g.head.add_child(fill);fill.position=Vector3(0,.3,.05);fill.light_energy=.45;fill.omni_range=2
   for group in 1:
    var display=Node3D.new();g.head.add_child(display)
    for side in 2:
     var model=load(S.SPECIES[38+group*2+side].model).instantiate();display.add_child(model)
     model.scale=Vector3.ONE*.42;model.position=Vector3(0,.13-side*.26,-.58);model.rotation.y=.35
    await capture("fish-pair-%d"%group);display.free()
   g.fish_guide.reparent(g.head);g.fish_guide.transform=Transform3D(Basis.IDENTITY,Vector3(0,0,-.42));g.fish_guide.show();g.fish_guide.held=true;g.fish_guide.selected=38;g.fish_guide.screen.queue_redraw()
   await capture("guide-huchen")
   g.head.compositor=null
 peer.queue_free();g.xr=false;g.queue_free();await process_frame;await create_timer(.3).timeout
 print("PREDATOR_ASSETS_RESULT ",checks," checks, ",failures);quit(0 if failures.is_empty() else 1)
func capture(label:String):
 for i in 15:await process_frame
 effect.request_capture(label)
 for i in 150:
  await process_frame
  if effect.completed==label:break
 check(effect.completed==label and effect.results.size()==2,"Stereo capture "+label)
 for eye in effect.results.size():
  var im:Image=effect.results[eye];im.convert(Image.FORMAT_RGBA8);im.linear_to_srgb();im.save_png("res://test-results/predator-expansion/"+label+"_eye%d.png"%eye)
func gallery():
 var view:=SubViewport.new();view.size=Vector2i(1500,750);view.own_world_3d=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
 var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("172b30");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.65;view.add_child(env)
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-30,-25,0);light.light_energy=.9;view.add_child(light)
 var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.65;camera.keep_aspect=Camera3D.KEEP_WIDTH;camera.position=Vector3(0,0,4);view.add_child(camera)
 var models:Array=[]
 for i in 2:
  var species:Dictionary=S.SPECIES[38+i];var model=load(species.model).instantiate();view.add_child(model)
  model.position=Vector3(-.64+(i%2)*1.28,0.05,0);models.append(model)
  var label:=Label3D.new();view.add_child(label);label.text=species.name;label.font_size=25;label.pixel_size=.0016;label.position=model.position+Vector3(0,-.36,.2)
 for angle in [0.0,.55]:
  for model in models:model.rotation.y=angle
  for i in 10:await process_frame
  await RenderingServer.frame_post_draw
  var image:Image=view.get_texture().get_image()
  check(image.get_pixel(0,0).get_luminance()>.005,"Gallery rendered its lit background")
  image.save_png("res://test-results/predator-expansion/gallery"+("-oblique" if angle>0 else "")+".png")
 view.queue_free()
