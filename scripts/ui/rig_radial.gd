extends Node3D
## Tap right stick click, point to highlight, then centre to select. Tap again to cancel.
var game_root:Node3D
var opened:=false
var choice:=-1
var selection_ready:=false
var view:=SubViewport.new()
var canvas:Control
class Dial extends Control:
 var owner_menu:Node
 var font:=ThemeDB.fallback_font
 func _draw():
  var m=owner_menu
  for side in 3:
   var angle:float=[5*PI/6,PI/6,-PI/2][side]
   var center:=Vector2(256,200)+Vector2.from_angle(angle)*96
   var enabled:bool=m.game_root.Session.rig_supported(side,m.game_root.current_location)
   var start:float=angle-PI/3+.04
   var points:=PackedVector2Array()
   for i in 33:points.append(Vector2(256,200)+Vector2.from_angle(start+i*(TAU/3-.08)/32)*180)
   for i in range(32,-1,-1):points.append(Vector2(256,200)+Vector2.from_angle(start+i*(TAU/3-.08)/32)*28)
   draw_colored_polygon(points,Color("355f50") if m.choice==side else Color("122d29"))
   draw_arc(Vector2(256,200),180,start,start+TAU/3-.08,48,Color("edd6a0") if m.choice==side else Color("648779"),4,true)
   var texture:Texture2D=preload("res://scripts/ui/pictograms.gd").texture(["cast","feeder","lure"][side])
   draw_texture_rect(texture,Rect2(center-Vector2(33,42),Vector2(66,66)),false,Color.WHITE if enabled else Color(.35,.4,.38))
   var title:String=("Fly" if m.game_root.game.Fly.river(m.game_root.current_location) else "Classic") if side==0 else ["","Feeder","Lure"][side] if enabled else "Unavailable"
   draw_string(font,center+Vector2(-62,47),title,HORIZONTAL_ALIGNMENT_CENTER,124,23 if enabled else 18,Color("e5e4d0") if enabled else Color("8b9690"))
  draw_circle(Vector2(256,200),9,Color("e7c884"))
func setup(g:Node3D):
 game_root=g;add_child(view);view.size=Vector2i(512,400);view.transparent_bg=true;view.render_target_update_mode=SubViewport.UPDATE_DISABLED
 canvas=Dial.new();canvas.owner_menu=self;canvas.size=Vector2(512,400);view.add_child(canvas)
 var mesh:=QuadMesh.new();mesh.size=Vector2(.32,.25)
 var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.albedo_texture=view.get_texture()
 var panel:=MeshInstance3D.new();panel.mesh=mesh;panel.material_override=material;panel.layers=preload("res://scripts/guide_camera.gd").UI_LAYER;panel.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(panel);hide()
func open()->bool:
 var g=game_root
 if g.menu_open or g.fish_guide.held or g.shoulder_radio.held or g.avatar_loading or g.casting or g.game.state!=g.Session.State.READY:return false
 if g.xr and (not g.right.get_has_tracking_data() or not g.tracking_manager.focused):return false
 opened=true;choice=-1;selection_ready=selection_axis().length()<.2
 show();global_transform=g.head.global_transform*Transform3D(Basis.IDENTITY,Vector3(0,-.12,-.65))
 view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;canvas.queue_redraw();g.motor.turn_reserved=true;g.motor.radial_open=true
 return true
func toggle():
 if opened:close()
 else:open()
func selection_axis()->Vector2:
 return game_root.right.get_vector2("primary") if game_root.xr else Vector2(float(Input.is_key_pressed(KEY_RIGHT))-float(Input.is_key_pressed(KEY_LEFT)),float(Input.is_key_pressed(KEY_UP))-float(Input.is_key_pressed(KEY_DOWN)))
func point(axis:Vector2):
 choice=-1
 if axis.length()>.45:
  var directions=[Vector2(-.866,-.5),Vector2(.866,-.5),Vector2(0,1)]
  var best:=-INF
  for candidate in 3:
   var score:float=axis.normalized().dot(directions[candidate])
   if score>best:best=score;choice=candidate
  if not game_root.Session.rig_supported(choice,game_root.current_location):choice=-1
 canvas.queue_redraw()
func close(confirm:=false):
 if not opened:return
 var selected:=choice;opened=false;hide();view.render_target_update_mode=SubViewport.UPDATE_DISABLED
 game_root.motor.radial_open=false
 if confirm and selected>=0:game_root._select_rig(selected)
 game_root.tracking_was_valid=false;game_root.reel_tracker.engaged=false;game_root.reel_tracker.angular_delta=0
func update():
 if not opened:return
 var g=game_root
 if g.menu_open or g.fish_guide.held or g.shoulder_radio.held or g.game.state!=g.Session.State.READY or g.xr and (not g.right.get_has_tracking_data() or not g.tracking_manager.focused):close();return
 var axis:=selection_axis()
 # Opening while already turning must not immediately select a rig.
 if not selection_ready:
  if axis.length()<.2:selection_ready=true
  return
 # Keep the highlighted wedge while the stick travels back through the
 # dead zone. Deflection only previews; returning to centre commits it.
 if axis.length()<.2:
  if choice>=0:close(true)
 elif axis.length()>.45:
  point(axis)
