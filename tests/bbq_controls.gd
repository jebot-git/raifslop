extends SceneTree
const Sites=preload("res://scripts/bbq/sites.gd")
var g
var failures:Array=[]
var trackers:Array[XRControllerTracker]=[]
func _initialize() -> void:run.call_deferred()
func check(ok:bool,label:String) -> void:
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func pose(hand:int,at:Vector3) -> void:
 trackers[hand].set_pose("grip",Transform3D(Basis.IDENTITY,g.origin.to_local(at)),Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
func settle() -> void:
 for i in 4:await process_frame
func trigger(hand:int) -> void:
 trackers[hand].set_input("trigger",1.0);await settle();trackers[hand].set_input("trigger",0.0);await settle()
func run() -> void:
 g=load("res://scenes/main.tscn").instantiate();root.add_child(g);await create_timer(.6).timeout
 g.set_process(false);g.motor.set_physics_process(false);g.fishing_feedback.set_process(false)
 g.game.reset();g._select_location("secluded_beach",false);g.bbq.select_location();g.rod_holster.set_stowed(true)
 g.motor.relocate(Sites.arrival(g.current_location));g.bbq.service.request("start");await settle()
 var a=g.bbq;var service=a.service;var site:=Sites.pose(g.current_location)
 check(a.station.find_children("*","Label3D",true,false).is_empty(),"Shared BBQ uses icons without floating text")
 for icon in a.hint_icons:check(icon.layers==g.fish_guide.photo_camera.UI_LAYER,"BBQ prompts stay out of camera photos")
 for hand in 2:
  var t:=XRControllerTracker.new();t.name="bbq_test_"+str(hand);XRServer.add_tracker(t);trackers.append(t)
  var c:XRController3D=g.left if hand==0 else g.right;c.tracker=t.name;c.pose="grip"
  t.set_input("grip",0.0);t.set_input("trigger",0.0);t.set_input("trigger_click",false);t.set_input("primary",Vector2.ZERO)
 g.xr=true;g.tracking_manager.focused=true;g.tracking_manager.calibration_pending=false
 var journal:Array=g.game.journal.duplicate(true);var bait:int=g.game.bait
 var items:Array=service.model.stations[g.current_location].items
 pose(0,site*items[6].pos);pose(1,site*items[7].pos);await settle()
 trackers[0].set_input("grip",1.0);trackers[1].set_input("grip",1.0);await settle()
 check(a.holds(0) and a.holds(1),"Both hands can grab their own tongs")
 check(g.fish_guide.can_grab(),"Guide stays available while cooking")
 check(a.item_nodes[6].global_position.is_equal_approx(g.left.global_position),"Utensil snaps to tracked hand")
 g._left_button("ax_button");check(g.game.bait==bait,"Context action never changes bait")
 pose(1,site*items[0].pos+Vector3(0,0,.22));await settle();await trigger(1)
 check(items[0].place=="grill","Tracked tongs put food on grill with forgiving reach")
 pose(1,site*items[0].pos+Vector3(0,0,.22));await settle();await trigger(1)
 check(items[0].side==1,"Trigger turns food")
 await trigger(1);check(items[0].place=="served","Trigger serves turned food")
 trackers[1].set_input("grip",0.0);await settle()
 check(not a.holds(1) and items[7].owner==0,"Release docks tongs")
 pose(1,site*items[0].pos);await settle();trackers[1].set_input("grip",1.0);await settle()
 check(a.holds(1) and items[0].owner==1,"Served food can be held")
 await trigger(1);check(items[0].place=="hand","Food does not disappear until brought to mouth")
 pose(1,g.head.global_position+Vector3(0,-.10,-.12));await settle();await trigger(1)
 check(items[0].place=="gone","Eating gesture consumes only the leisure prop")
 trackers[1].set_input("grip",0.0);await settle()
 pose(1,site*Sites.COOLER_HANDLE);await settle()
 service.request("cooler",-1,1);await settle()
 pose(1,site*items[8].pos);await settle();trackers[1].set_input("grip",1.0);await settle();await trigger(1)
 check(items[8].open,"Trigger opens a held drink")
 pose(1,g.head.global_position+Vector3(0,-.1,-.1));await settle();await trigger(1)
 check(items[8].sips==1,"Mouth gesture sips drink")
 # The guide owns camera input while shared food continues cooking.
 service.model.stations[g.current_location].items[1].place="grill"
 var heat:float=items[1].cook[0]
 g.fish_guide.held=true;g.fish_guide.photo_camera.toggle();await settle()
 check(g.fish_guide.photo_camera.active,"Camera mode opens at the shared BBQ")
 check(not a.holds(0) and not a.holds(1),"Opening guide returns BBQ props")
 check(items[1].cook[0]>heat,"Guide use does not stop shared cooking")
 g.xr=false
 var click:=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true
 var c:=InputEventKey.new();c.keycode=KEY_C;c.pressed=true
 check(not a.handle_input(click) and not a.handle_input(c),"Guide camera receives mouse and camera-key inputs")
 g.fish_guide.photo_camera.toggle();g.fish_guide.held=false;g.xr=true
 # Reacquire a utensil before focus loss so this also tests ownership cleanup.
 trackers[0].set_input("grip",0.0);pose(0,site*items[6].pos);await settle()
 trackers[0].set_input("grip",1.0);await settle()
 check(a.holds(0),"Tool may be taken after docking guide")
 var Icons=preload("res://scripts/ui/pictograms.gd")
 Icons.enabled=false;await settle();check(not a.hint.visible and not a.cooler_icon.visible,"BBQ respects guiding-icon preference")
 Icons.enabled=true
 g.tracking_manager.focused=false;await settle()
 check(not a.holds(0) and not a.holds(1),"Focus loss returns all held props")
 g.tracking_manager.focused=true;await settle();check(not a.holds(0),"Held grip cannot reacquire after focus loss")
 check(g.game.journal==journal and g.game.bait==bait,"BBQ leaves fishing state intact")
 for t in trackers:XRServer.remove_tracker(t)
 g.xr=false
 for player in g.find_children("*","AudioStreamPlayer",true,false):player.stop()
 g.queue_free();await process_frame;await create_timer(.3).timeout
 print("BBQ_CONTROLS_RESULT ",failures);quit(0 if failures.is_empty() else 1)
