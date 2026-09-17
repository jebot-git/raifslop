extends SceneTree
const S=preload("res://scripts/fishing_session.gd")
const F=preload("res://scripts/fly_fishing.gd")
var failures:Array=[]
func check(ok:bool,label:String):
 if not ok:failures.append(label);push_error(label)
func _initialize():run.call_deferred()
func run():
 var mend_input=F.new()
 mend_input.sample_mend(Vector3.ZERO,Basis.IDENTITY,.02)
 check(mend_input.sample_mend(Vector3(-.02,0,0),Basis.IDENTITY,.02)==0,"Brief velocity spike does not mend")
 var accepted:=0
 for i in range(2,20):
  if mend_input.sample_mend(Vector3(-i*.02,0,0),Basis.IDENTITY,.02)==-1:accepted+=1
 check(accepted==1,"One deliberate sweep yields one mend")
 mend_input.sample_mend(Vector3(-.38,0,0),Basis.IDENTITY,.02)
 accepted=0
 for i in range(1,14):
  if mend_input.sample_mend(Vector3(-.38+i*.02,0,0),Basis.IDENTITY,.02)==1:accepted+=1
 check(accepted==1,"Settling rearms a downstream sweep")
 mend_input.reset_mend_gesture();mend_input.sample_mend(Vector3.ZERO,Basis.IDENTITY,.02)
 check(mend_input.sample_mend(Vector3.ZERO,Basis(Vector3.UP,PI/2),.02)==0,"Turning without tracked hand movement cannot mend")
 check(mend_input.sample_mend(Vector3(-2,0,0),Basis.IDENTITY,.02)==0,"Tracking teleport cannot mend")
 var upstream=F.new();var untouched=F.new();upstream.start=Vector3(0,0,-11);untouched.start=upstream.start
 upstream.drag=.8;untouched.drag=.8;upstream.mend(-1)
 var drag_after:float=upstream.drag
 check(not upstream.mend(-1) and upstream.drag==drag_after,"Mend cooldown rejects repeats")
 upstream.drift(.3,0,"meadow_bend");untouched.drift(.3,0,"meadow_bend")
 check(upstream.quality>untouched.quality and upstream.mend_bend()<-.8,"Accepted upstream mend improves the same drift and visibly bows line")
 var clean=F.new();clean.start=Vector3(0,0,-11)
 var dragged=F.new();dragged.start=clean.start
 for i in 500:
  clean.drift(.02,0,"meadow_bend");dragged.drift(.02,1,"meadow_bend")
  if i%50==0:clean.mend(-1)
 check(clean.offset.x>5 and clean.quality>dragged.quality,"Current transports fly and mending improves presentation")
 check(F.current(Vector3(0,0,-11),"boulder_run").x>F.current(Vector3(0,0,-11),"meadow_bend").x,"Boulder river has stronger channel")
 check(F.current(Vector3(6,0,-13),"boulder_run").x<F.current(Vector3(2,0,-13),"boulder_run").x,"Rock creates sheltered pocket")
 var poor=S.new();poor.location_id="meadow_bend";poor.cast(12);poor.tick(1,0,0);poor.fly.drag=1
 var waiting_timer:float=poor.timer
 for i in 100:poor.tick(.02,0,0)
 check(is_equal_approx(poor.timer,waiting_timer),"Dragging fly does not earn bite progress")
 var input=F.new();input.begin_cast();input.stroke(.5,-1);input.stroke(.4,1)
 check(input.strokes==1 and input.cast_power()>8,"Back/forward stroke adds cast distance")
 input.begin_cast();input.stroke(.2,-1);input.stroke(2,0);input.stroke(.1,1)
 check(input.strokes==1,"Paused backcast still accepts a deliberate forward swing")
 check(input.strip(Vector3.ZERO,1,.02,Vector3.ZERO,Vector3(0,0,-.3))==0 and input.strip(Vector3(0,0,.1),1,.05,Vector3.ZERO,Vector3(0,0,-.3))>0,"Left-hand pull strips line")
 for id in ["meadow_bend","boulder_run"]:
  for bait in 2:
   var s=S.new();s.location_id=id;s.rng.seed=6;s.select_bait(bait);s.cast(12);s.tick(1,0,0)
   check(s.fish_index in S.LOCATION_SPECIES[id],"River roster used")
   for i in 1600:
    if s.state!=S.State.WAITING:break
    if i%50==0:s.fly.mend(-1)
    s.tick(.02,0,0)
   check(s.state==S.State.BITE,"Natural drift yields take "+id+str(bait))
   s.strike();check(s.state==S.State.FIGHT,"Indicator take can be struck")
   check(S.predator_for_prey(s.fish_index,id) in [-1,S.HUCHEN],"Only river-appropriate huchen can take over")
 var g=load("res://scenes/main.tscn").instantiate();root.add_child(g)
 await create_timer(.4).timeout
 g.set_process(false);g.motor.set_physics_process(false)
 for id in ["meadow_bend","boulder_run"]:
  g.game.reset();check(g._select_location(id,false),"River travel "+id)
  await physics_frame
  g.rod_visual.equip(3,true)
  check(g.rod_visual.fly_mode and g.rod_visual.model!=null,"Fly reel equips in river")
  var ground=g.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0,2,1),Vector3(0,-2,1),1))
  check(not ground.is_empty(),"River spawn has solid ground")
  var shrubs=g.foreground.get_node("LayeredRiverShrubs")
  check(shrubs.get_meta("instances")>50 and g.foreground.has_node("RiverAlders"),"River has layered realistic vegetation groups")
  check(shrubs.get_meta("layer_depth_separation")>.2,"Shrub layers have real depth separation")
  g.game.select_bait(1);g.rod_status.update_bait();g._cast(12);g._update_line()
  check(g.game.state==S.State.CASTING,"River bank allows real cast "+g.game.message)
  check(g.bobber.visible and g.bobber.scale.x<.4,"Nymph uses small strike indicator")
  check(g.rod_status.bait_visual.find_child("NymphBead",true,false)!=null,"Nymph model equipped")
  var prior_state:int=g.game.state;g.game.state=S.State.WAITING;g.game.fly.drag=.8
  check(g._mend_fly(-1) and g.rod_status.notice_remaining>0 and g.rod_status.notice_icon=="mend","Mending confirms success with a rod pictogram")
  check(not g._mend_fly(-1),"Rejected mend does not retrigger feedback")
  g.game.state=prior_state
  if "--capture" in OS.get_cmdline_user_args():
   g.hud.hide();g.rod.hide();g.bobber.hide();g.rod_status.hide();g.avatar.hide();g.line_mesh.clear_surfaces()
   var camera:=Camera3D.new();g.add_child(camera);camera.current=true
   camera.global_position=Vector3(0,1.7,.5);camera.look_at(Vector3(8,-.3,-12))
   for i in 15:await process_frame
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://test-results/"+id+".png")
   var preview=root.get_texture().get_image();preview.resize(640,400)
   preview.save_jpg("res://assets/environment/locations/"+id+"_preview.jpg",.85)
   camera.global_position=Vector3(0,1.15,.5);camera.look_at(Vector3(8,-.3,-12))
   for i in 12:await process_frame
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://test-results/"+id+"-seated.png")
   camera.queue_free();await process_frame
  g.game.state=S.State.BITE;g.game.fish_index=11;g.game.strike();g.game.jumps_enabled=false
  for frame in 18000:
   if g.game.state!=S.State.FIGHT:break
   if g.game.cue>=0:g.game.gesture(g.game.cue)
   var rate:=0.0 if g.game.is_running() or g.game.tension>.7 else 1.0
   if g.game.submerge==S.Submerge.PULL:rate=0
   elif g.game.submerge==S.Submerge.SLACK:rate=1.4 if g.game.tension>.7 else 1.8
   g.game.fly.current_speed=F.current(g.cast_target,id).length()
   g.game.tick(.02,rate,0);g._constrain_river_fish(.02)
  check(g.game.state==S.State.LANDED,"Fish can be landed within river boundaries: "+g.game.message)
  g.game.reset();g.game.select_bait(0);g._update_line()
  var press:=InputEventKey.new();press.keycode=KEY_SPACE;press.pressed=true
  g._unhandled_input(press);g.game.fly.stroke(.6,0)
  check(g.game.fly.charging and g.game.state==S.State.READY,"Desktop backcast charges on space press")
  var release:=InputEventKey.new();release.keycode=KEY_SPACE;release.pressed=false;g._unhandled_input(release)
  check(g.game.state==S.State.CASTING,"Desktop release sends fly into channel")
  g.game.reset();g._update_line()
  check(not g.bobber.visible,"Dry fly does not show conventional float")
 g.game.reset();g._select_location("lakeside",false);g._update_line()
 check(g.game.bait_count()==6 and is_equal_approx(g.bobber.scale.x,1),"Returning to lake restores ordinary tackle")
 g.queue_free();await process_frame;await create_timer(.3).timeout
 print("FLY_FISHING_RESULT ",failures);quit(0 if failures.is_empty() else 1)
