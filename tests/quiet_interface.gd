extends SceneTree
var failures:Array=[]
var checks:=0
var effect=preload("res://tests/xr_capture.gd").new()
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize():run.call_deferred()
func capture(g,label:String):
 for i in 20:await process_frame
 if g.xr:
  effect.request_capture(label)
  for i in 150:
   await process_frame
   if effect.completed==label:break
  check(effect.completed==label and effect.results.size()==2,"Two-eye capture "+label)
  for eye in effect.results.size():
   var frame:Image=effect.results[eye];frame.convert(Image.FORMAT_RGBA8);frame.linear_to_srgb()
   frame.save_png("res://test-results/quiet-interface/"+label+"_eye%d.png"%eye)
 else:
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://test-results/quiet-interface/"+label+".png")
func run():
 var g=load("res://scenes/main.tscn").instantiate();root.add_child(g)
 await create_timer(.4).timeout
 g.set_process(false);g.motor.set_physics_process(false);g.network.set_process(false)
 g.fishing_feedback.set_process(false)
 check(not g.avatar_menu.pages.has("help"),"Tutorial page removed")
 check(g.avatar_menu.pages.has("leaderboard"),"Leaderboard replaces Tutorial")
 check(FileAccess.file_exists("res://docs/MANUAL.html"),"Repository HTML manual available")
 g.game.reset();g.rod_holster.stowed=false;g.menu_open=false;g.fish_guide.held=false
 g.rod_status.show_bait();var bait:String=g.rod_status.label.text
 for key in ["cast","extend","stop","mend","warning"]:
  g.rod_status.show_notice(key);g.rod_status.remaining=0;g.rod_status._process(.01)
  check(g.rod_status.label.text==bait and not g.rod_status.label.visible,"Notice does not create text: "+key)
  check(g.rod_status.pictogram.visible and g.rod_status.shown_icon==key,"Notice uses symbol: "+key)
 g.rod_status.notice_remaining=0;g.game.state=g.Session.State.FIGHT
 for cue in 3:
  g.game.cue=cue;g.rod_status._process(.01)
  check(g.rod_status.shown_icon==["left","right","up"][cue],"Directional fight symbol")
 g.menu_open=true;g.rod_status._process(.01)
 check(not g.rod_status.pictogram.visible,"Symbols hide behind menus")
 g.menu_open=false;g.game.reset()
 var board=preload("res://scripts/network/leaderboard.gd").new()
 for i in 3:
  board.connect_player(i+1,"%064x"%i,["River wanderer","Harbour angler","Returning fisher"][i])
  for n in (3-i):
   var d={"state":1,"location":"lakeside","species":i,"length":g.Session.SPECIES[i].length*1.14,"caught":false}
   board.observe(i+1,d);d.state=4;board.observe(i+1,d);d.state=5;d.caught=true;board.observe(i+1,d)
 g.network.leaderboard=board;g.network.active=true
 if "--capture" in OS.get_cmdline_user_args():
  DirAccess.make_dir_recursive_absolute("res://test-results/quiet-interface")
  if g.xr:
   var compositor:=Compositor.new();compositor.compositor_effects=[effect];g.head.compositor=compositor
  g._toggle_avatar_menu();g.avatar_menu.leaderboard_button.pressed.emit()
  g.network.leaderboard_changed.emit()
  await capture(g,"leaderboard")
  check(g.avatar_menu.active_page=="leaderboard","Header opens leaderboard in menu")
  var page=g.avatar_menu.pages.leaderboard.page
  page.category="exceptional";page.get_child(1).value="exceptional";page.get_child(1).update_label();page.poll();await capture(g,"exceptional")
  g._toggle_avatar_menu();g.hud.hide();g.avatar.hide()
  g.avatar.process_mode=Node.PROCESS_MODE_DISABLED
  g.rod.show()
  g.rod.global_transform=g.head.global_transform*Transform3D(Basis.IDENTITY,Vector3(.15,-.16,-.35))
  g.rod_status.show_notice("mend");g.rod_status.notice_remaining=30
  g.rod_status._process(.01)
  check(g.rod_status.pictogram.is_visible_in_tree(),"Rod symbol visible in capture")
  await capture(g,"rod-symbol")
 g.network.active=false
 g.head.compositor=null;g.queue_free();await process_frame
 print("QUIET_INTERFACE_RESULT ",checks," checks, ",failures);quit(0 if failures.is_empty() else 1)
