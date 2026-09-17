extends Node3D
## Hold right stick click, point left/right, release. Neutral release cancels.
var game_root:Node3D
var opened:=false
var choice:=-1
var view:=SubViewport.new()
var canvas:Control
class Dial extends Control:
 var owner_menu:Node
 var font:=ThemeDB.fallback_font
 func _draw():
  var m=owner_menu
  for side in 2:
   var center:=Vector2(158 if side==0 else 354,170)
   var enabled:bool=side==0 or m.game_root.game.Feeder.supported(m.game_root.current_location)
   var start:float=PI/2+.045 if side==0 else -PI/2+.045
   var points:=PackedVector2Array()
   for i in 33:points.append(Vector2(256,170)+Vector2.from_angle(start+i*(PI-.09)/32)*156)
   for i in range(32,-1,-1):points.append(Vector2(256,170)+Vector2.from_angle(start+i*(PI-.09)/32)*29)
   draw_colored_polygon(points,Color("355f50") if m.choice==side else Color("122d29"))
   draw_arc(Vector2(256,170),156,start,start+PI-.09,48,Color("edd6a0") if m.choice==side else Color("648779"),4,true)
   var texture:Texture2D=preload("res://scripts/ui/pictograms.gd").texture("cast" if side==0 else "feeder")
   draw_texture_rect(texture,Rect2(center-Vector2(48,59),Vector2(96,96)),false,Color.WHITE if enabled else Color(.35,.4,.38))
   var title:String=("Fly" if m.game_root.game.Fly.river(m.game_root.current_location) else "Classic") if side==0 else "Feeder" if enabled else "Unavailable"
   draw_string(font,center+Vector2(-69,62),title,HORIZONTAL_ALIGNMENT_CENTER,138,23 if enabled else 18,Color("e5e4d0") if enabled else Color("8b9690"))
  draw_circle(Vector2(256,170),9,Color("e7c884"))
func setup(g:Node3D):
 game_root=g;add_child(view);view.size=Vector2i(512,340);view.transparent_bg=true;view.render_target_update_mode=SubViewport.UPDATE_DISABLED
 canvas=Dial.new();canvas.owner_menu=self;canvas.size=Vector2(512,340);view.add_child(canvas)
 var mesh:=QuadMesh.new();mesh.size=Vector2(.32,.2125)
 var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.albedo_texture=view.get_texture()
 var panel:=MeshInstance3D.new();panel.mesh=mesh;panel.material_override=material;panel.layers=preload("res://scripts/guide_camera.gd").UI_LAYER;panel.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(panel);hide()
func open()->bool:
 var g=game_root
 if g.menu_open or g.fish_guide.held or g.shoulder_radio.held or g.avatar_loading or g.casting or g.game.state!=g.Session.State.READY:return false
 if g.xr and (not g.right.get_has_tracking_data() or not g.tracking_manager.focused):return false
 opened=true;choice=-1;show();global_transform=g.head.global_transform*Transform3D(Basis.IDENTITY,Vector3(0,-.12,-.65))
 view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;canvas.queue_redraw();g.motor.turn_reserved=true
 return true
func point(axis:Vector2):
 choice=-1
 if axis.length()>.45 and absf(axis.x)>.3:
  var selected:=0 if axis.x<0 else 1
  if selected==0 or game_root.game.Feeder.supported(game_root.current_location):choice=selected
 canvas.queue_redraw()
func close(confirm:=false):
 if not opened:return
 var selected:=choice;opened=false;hide();view.render_target_update_mode=SubViewport.UPDATE_DISABLED
 if confirm and selected>=0:game_root._select_rig(selected)
 game_root.tracking_was_valid=false;game_root.reel_tracker.engaged=false;game_root.reel_tracker.angular_delta=0
func update():
 if not opened:return
 var g=game_root
 if g.menu_open or g.fish_guide.held or g.shoulder_radio.held or g.game.state!=g.Session.State.READY or g.xr and (not g.right.get_has_tracking_data() or not g.tracking_manager.focused):close();return
 point(g.right.get_vector2("primary") if g.xr else Vector2(float(Input.is_key_pressed(KEY_RIGHT))-float(Input.is_key_pressed(KEY_LEFT)),0))
