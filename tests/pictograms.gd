extends SceneTree
const Icons=preload("res://scripts/ui/pictograms.gd")
var checks:=0
var failures:Array=[]
var effect=preload("res://tests/xr_capture.gd").new()
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize():run.call_deferred()
func run():
 var g=load("res://scenes/main.tscn").instantiate();root.add_child(g)
 await create_timer(.4).timeout
 g.set_process(false);g.motor.set_physics_process(false);g.fishing_feedback.set_process(false)
 g.avatar.process_mode=Node.PROCESS_MODE_DISABLED;g.avatar.hide();g.rod.hide();g.bobber.hide();g.hud.hide();g.line_mesh.clear_surfaces()
 g.game.reset();g.menu_open=false;g.fish_guide.held=false;g.rod_holster.stowed=false
 var grid:=Node3D.new();g.add_child(grid)
 grid.global_transform=g.head.global_transform*Transform3D(Basis.IDENTITY,Vector3(0,0,-.85))
 var i:=0
 for key in Icons.KEYS:
  var texture:=Icons.texture(key)
  check(texture!=null and texture.get_width()==128 and texture.get_height()==128,"128px vector import "+key)
  var pixels:Image=texture.get_image()
  if pixels.is_compressed():pixels.decompress()
  var covered:=0;var partial:=0
  for y in 128:
   for x in 128:
    var alpha:float=pixels.get_pixel(x,y).a
    if alpha>.05:covered+=1
    if alpha>.05 and alpha<.95:partial+=1
  check(covered>300 and covered<10000 and partial>20,"Visible antialiased symbol with transparent margin "+key)
  check(pixels.has_mipmaps(),"Mipmap chain for VR minification "+key)
  g.rod_status.show_notice(key);g.rod_status.remaining=0;g.rod_status._process(.01)
  check(g.rod_status.pictogram.visible and g.rod_status.shown_icon==key and not g.rod_status.label.visible,"World pictogram renders without notice text "+key)
  var sprite:=Sprite3D.new();sprite.texture=texture;sprite.pixel_size=.0007
  sprite.position=Vector3((i%4-1.5)*.16,(1.5-i/4)*.14,0);grid.add_child(sprite)
  # Diagnostic labels belong only to this render sheet, never the game overlay.
  var label:=Label3D.new();label.text=key;label.font_size=24;label.pixel_size=.0006
  label.position=sprite.position+Vector3(0,-.052,0);grid.add_child(label)
  i+=1
 g.avatar_menu.pictograms_toggle.button_pressed=false
 status_toggle_check(g)
 Icons.enabled=true;g._load_player_preferences()
 check(not Icons.enabled,"Pictogram preference survives reload")
 g.avatar_menu.pictograms_toggle.button_pressed=true
 Icons.enabled=false;g._load_player_preferences()
 check(Icons.enabled,"Re-enabled preference survives reload")
 g.rod_status.hide()
 check(Icons.texture("unknown")==Icons.texture("warning"),"Unknown symbol safely falls back to warning")
 var s=g.game;var status=g.rod_status
 status.notice_remaining=0
 s.state=g.Session.State.BITE;check(status.active_icon()=="up","Bite means lift")
 s.state=g.Session.State.FIGHT;s.jump_time=0;s.cue=-1;s.tension=.45
 s.submerge=g.Session.Submerge.PULL;check(status.active_icon()=="stop","Dive means ease off")
 s.submerge=g.Session.Submerge.SLACK;check(status.active_icon()=="reel","Inward rush means wind")
 s.submerge=g.Session.Submerge.NONE;s.tension=.95;check(status.active_icon()=="warning","Strain warning")
 s.tension=.05;check(status.active_icon()=="warning","Slack warning")
 s.tension=.45;s.state=g.Session.State.READY;check(status.active_icon().is_empty(),"No idle guide icon")
 g.shoulder_radio.indicator.texture=Icons.texture("radio")
 check(g.shoulder_radio.indicator is Sprite3D,"Radio guidance is a pictogram, not text")
 if "--capture" in OS.get_cmdline_user_args():
  DirAccess.make_dir_recursive_absolute("res://test-results/pictograms")
  if g.xr:
   var compositor:=Compositor.new();compositor.compositor_effects=[effect];g.head.compositor=compositor
  for i_frame in 20:await process_frame
  if g.xr:
   effect.request_capture("all")
   for i_frame in 120:
    await process_frame
    if effect.completed=="all":break
   check(effect.completed=="all" and effect.results.size()==2,"All symbols captured in both VR eyes")
   for eye in effect.results.size():
    var frame:Image=effect.results[eye];frame.convert(Image.FORMAT_RGBA8);frame.linear_to_srgb()
    frame.save_png("res://test-results/pictograms/all_eye%d.png"%eye)
  else:
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://test-results/pictograms/all.png")
 g.head.compositor=null
 g.ambience.stop()
 await create_timer(.3).timeout
 g.queue_free();await process_frame;await create_timer(.3).timeout
 print("PICTOGRAM_RESULT ",checks," checks, ",failures);quit(0 if failures.is_empty() else 1)

func status_toggle_check(g):
 check(not Icons.enabled,"Menu toggle disables symbols")
 for key in Icons.KEYS:
  g.rod_status.show_notice(key);g.rod_status.remaining=0;g.rod_status._process(0)
  check(not g.rod_status.pictogram.visible,"Disabled pictogram hidden: "+key)
 g.rod_status.show_bait();g.rod_status._process(0)
 check(g.rod_status.label.visible,"Bait text remains available with symbols disabled")
