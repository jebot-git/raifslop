extends SceneTree
const L=preload("res://scripts/locations.gd")
const F=preload("res://scripts/fly_fishing.gd")
const S=preload("res://scripts/fishing_session.gd")
var failures:Array[String]=[]
var checks:=0
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);push_error(label)
func settle():
 for i in 12:await process_frame
func run():
 var seen:Dictionary={}
 for category in L.WATER_TYPES:
  for water in L.waters_in_category(category.id):
   check(not seen.has(water.id),"Each water appears once in categories");seen[water.id]=true
 check(seen.size()==L.CATALOG.size(),"Categories include all waters")
 check(L.waters_in_category("rivers").size()==4,"Four fly waters available")
 check(F.current(Vector3(0,0,-11),"glacier_run").x>F.current(Vector3(0,0,-11),"cedar_creek").x,"Alpine channel runs faster than shaded creek")
 check(F.current(Vector3(-6,0,-10),"glacier_run").x<F.current(Vector3(-8,0,-10),"glacier_run").x,"Glacial boulders provide sheltered current")
 var g=load("res://scenes/main.tscn").instantiate();root.add_child(g);await settle()
 g.set_process(false);g.motor.set_physics_process(false)
 for id in ["cedar_creek","glacier_run"]:
  check(g._select_location(id,false),"Travel to "+id);await settle()
  check(g.game.is_fly_fishing(),"New water equips fly mode")
  var expected:int=40 if id=="cedar_creek" else 41
  for bait in 2:check(expected in F.preferred(bait,id),"New species reachable with dry fly and nymph")
  var bank=g.find_child("RiverForeground",true,false)
  check(bank!=null and bank.get_meta("location_id")==id,"Dedicated physical river foreground")
  check(bank.find_child("CedarGrove" if id=="cedar_creek" else "GlacialRidge",true,false)!=null,"Distinct authored scenery")
  if id=="cedar_creek":
   var grove=bank.find_child("CedarGrove",true,false)
   check(grove.get_meta("cross_sections",0)==2 and grove.get_meta("instances",0)==44,"Cedar trees use stereo-stable crossed cards")
   var foliage:Texture2D=grove.get_child(0).material_override.get_shader_parameter("foliage")
   var pixels:=foliage.get_image()
   check(pixels.has_mipmaps() and pixels.detect_alpha()!=Image.ALPHA_NONE,"Tree cutout retains alpha and mipmaps")
  else:
   var finish:ShaderMaterial=bank.find_child("GlacialRidge",true,false).get_child(0).material_override
   check(finish.get_shader_parameter("albedo_tex")!=null and finish.get_shader_parameter("normal_tex")!=null and finish.get_shader_parameter("occlusion_tex")!=null,"Glacial rock shading includes texture, normal and occlusion")
  var s=S.new();s.location_id=id;s.rng.seed=883
  var catches:Dictionary={}
  for i in 200:
   s.reset();s.select_bait(i%2);s.cast(12);s.tick(1,0,0);catches[s.fish_index]=true
  check(catches.has(expected),"New species encountered by actual casting")
  if "--capture" in OS.get_cmdline_user_args():
   g.hud.hide();g.rod.hide();g.avatar.hide();g.fish_guide.hide();g.rod_status.hide();g.bobber.hide()
   g.head.rotation=Vector3(-.10,0,0);await settle();await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://docs/fly_expansion/"+id+".png")
 var menu=g.avatar_menu
 menu.show_locations();menu.show_water_categories()
 check(menu.water_categories.visible and not menu.water_submenu.visible,"Category root hides water submenu")
 menu.open_water_category("rivers")
 check(menu.visible_waters.size()==4,"River submenu is filtered")
 var selected:Array[String]=[];menu.location_selected.connect(func(id):selected.append(id))
 menu.location_list.select(2);menu._preview_location(2);menu.visit_button.pressed.emit()
 check(selected==["cedar_creek"],"Filtered row emits stable water ID")
 menu.show_water_categories();check(not menu.location_actions.visible,"Back hides travel action")
 if "--capture" in OS.get_cmdline_user_args():await capture_assets(g)
 g.queue_free();await settle()
 print("FLY_EXPANSION_RESULT ",checks," checks, ",failures);quit(0 if failures.is_empty() else 1)

func capture_assets(g):
 var view:=SubViewport.new();view.size=Vector2i(1000,720);view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
 var menu=g.avatar_menu;menu.reparent(view);menu.position=Vector2(50,30);menu.size=Vector2(900,656);menu.scale=Vector2.ONE;menu.show()
 menu.show_water_categories();await settle();await RenderingServer.frame_post_draw
 view.get_texture().get_image().save_png("res://docs/fly_expansion/water_categories.png")
 menu.open_water_category("rivers");menu.location_list.select(2);menu._preview_location(2);await settle();await RenderingServer.frame_post_draw
 view.get_texture().get_image().save_png("res://docs/fly_expansion/river_submenu.png")
 menu.reparent(g);view.queue_free()
 var gallery:=SubViewport.new();gallery.size=Vector2i(1200,800);gallery.own_world_3d=true;gallery.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(gallery)
 var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("122a32");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_energy=.6;env.environment.ambient_light_color=Color.WHITE;gallery.add_child(env)
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-30,-20,0);light.light_energy=1.2;gallery.add_child(light)
 var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=1.4;camera.position=Vector3(0,0,3);gallery.add_child(camera)
 for i in 2:
  var fish:Node3D=load(S.SPECIES[40+i].model).instantiate();gallery.add_child(fish);fish.position.y=.27-i*.55
  var label:=Label3D.new();label.text=S.SPECIES[40+i].name;label.pixel_size=.001;label.font_size=24;label.position=Vector3(0,fish.position.y-.23,.05);gallery.add_child(label)
 await settle();await RenderingServer.frame_post_draw
 gallery.get_texture().get_image().save_png("res://docs/fly_expansion/fish_species.png");gallery.queue_free();await settle()
