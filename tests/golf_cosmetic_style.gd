extends SceneTree
const Style=preload("res://addons/golfminus/scripts/golf/club_style.gd")
const Shape=preload("res://addons/golfminus/scripts/golf/club_head.gd")
var failures:Array[String]=[]
var checks:=0
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);push_error(label)
func club(index:int,physical:=true)->Node3D:
 var kind:String="putter" if index==7 else "driver" if index<2 else "iron"
 var node:Node3D=load("res://addons/golfminus/assets/models/%s.glb"%kind).instantiate()
 if physical:Shape.for_club(index).install(node,index)
 return node
func shaft(node:Node3D)->MeshInstance3D:
 for part in node.find_children("*","MeshInstance3D",true,false):
  if "shaft" in part.name:return part
 return null
func run():
 for index in 8:
  var local:=club(index);root.add_child(local)
  var remote:=club(index,false);root.add_child(remote)
  var other:=club(index);root.add_child(other);Style.apply(other,1)
  var saved_color:Color=shaft(other).get_active_material(0).albedo_color
  var shape=Shape.for_club(index)
  var mesh:Mesh=shape.mesh;var triangles:PackedVector3Array=shape.triangles.duplicate()
  var transforms:Dictionary={}
  for child in local.find_children("*","MeshInstance3D",true,false):transforms[child]=child.transform
  var nearest:Dictionary=shape.nearest(Vector3(.01,.02,-.09))
  var head:MeshInstance3D=local.get_node("PhysicalClubHead")
  for tier in 4:
   Style.apply(local,tier);Style.apply(remote,tier)
   check(local.get_meta("tackle_style")==tier and remote.get_meta("tackle_style")==tier,"Local and imported remote model accept each tier")
   var mat:ShaderMaterial=head.material_override
   check(mat.get_shader_parameter("style_enabled") and mat.get_shader_parameter("style_blank")==Vector3(Style.palettes[tier].blank[0],Style.palettes[tier].blank[1],Style.palettes[tier].blank[2]),"Head receives exact linear palette")
   check(shaft(local).get_active_material(0).albedo_color.is_equal_approx(Style.linear_rgb(Style.palettes[tier].blank).linear_to_srgb()),"Shaft receives matching sRGB palette")
   check(shaft(local).get_active_material(0).albedo_color==shaft(remote).get_active_material(0).albedo_color,"Local and remote shaft styling agree")
   check(shaft(other).get_active_material(0).albedo_color==saved_color,"Other player's material stays independent")
   var unchanged:bool=shape.mesh==mesh and shape.triangles==triangles and shape.nearest(Vector3(.01,.02,-.09))==nearest
   for child in transforms:unchanged=unchanged and child.transform==transforms[child]
   check(unchanged and Shape.TRACKING_TOLERANCE==.002,"Styling preserves mesh, contact result, transforms and tolerance")
   var material_id:int=shaft(local).get_active_material(0).get_instance_id();Style.apply(local,tier)
   check(shaft(local).get_active_material(0).get_instance_id()==material_id,"Unchanged style allocates no replacement material")
  Style.apply(local,-1)
  check(not head.material_override.get_shader_parameter("style_enabled") and shaft(local).get_surface_override_material(0)==null,"Standalone fallback restores neutral finish")
  local.free();remote.free();other.free()
 print("GOLF_COSMETIC_STYLE_RESULT ",checks," checks, ",failures)
 if "--capture" in OS.get_cmdline_user_args():await gallery()
 quit(0 if failures.is_empty() else 1)
func gallery():
 var view:=SubViewport.new();view.size=Vector2i(1600,1200);view.own_world_3d=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
 var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("293638");environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.8;view.add_child(environment)
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-35,-25,0);light.light_energy=2.0;view.add_child(light)
 var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=3.5;camera.position=Vector3(0,-.6,4);view.add_child(camera)
 for tier in 4:
  for family in 3:
   var index:int=[0,3,7][family];var node:=club(index);view.add_child(node);node.position=Vector3(-1.38+tier*.9+family*.23,0,0)
   var head:MeshInstance3D=node.get_node("PhysicalClubHead");head.position=Vector3(.055,-[1.13,.93,.86][family],0);head.rotation.y=.35
   Style.apply(node,tier)
  var label:=Label3D.new();label.text=Style.palettes[tier].name.capitalize();label.position=Vector3(-1.15+tier*.9,.13,0);label.font_size=32;label.pixel_size=.0015;view.add_child(label)
 for i in 12:await process_frame
 await RenderingServer.frame_post_draw
 DirAccess.make_dir_recursive_absolute("res://docs/golf_tackle_styling")
 view.get_texture().get_image().save_png("res://docs/golf_tackle_styling/club_palettes.png")
 view.queue_free();await process_frame
