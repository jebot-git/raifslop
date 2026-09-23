extends SceneTree
const Sites=preload("res://scripts/bbq/sites.gd")
var failures:Array=[]
var g
var net
var role:String
var trackers:Array[XRControllerTracker]=[]
func _initialize() -> void:run.call_deferred()
func check(ok:bool,message:String) -> void:
 print("PASS " if ok else "FAIL ",message)
 if not ok:failures.append(message)
func wait_for(fn:Callable,seconds:=12.0) -> bool:
 var end:=Time.get_ticks_msec()+seconds*1000
 while Time.get_ticks_msec()<end:
  if fn.call():return true
  await create_timer(.04).timeout
 return false
func item(id:int) -> Dictionary:
 return net.bbq.model.stations.get("fish_hoek_beach",{}).get("items",[])[id] if net.bbq.model.stations.has("fish_hoek_beach") else {"owner":-1,"place":"missing","cook":[0.0,0.0]}
func request(action:String,id:=-1,hand:=1,at:=Vector3.ZERO) -> void:
 # Network tests supply tracked hand poses; no desktop reach or fake hand path.
 if action!="start":
  var where:Vector3=g.head.global_position
  var state:Dictionary=net.bbq.model.stations.get("fish_hoek_beach",{})
  if action=="cooler":where=Sites.pose("fish_hoek_beach")*Sites.COOLER_HANDLE
  elif action not in ["eat","sip"] and id>=0 and not state.is_empty():where=Sites.pose("fish_hoek_beach")*state.items[id].pos
  trackers[hand].set_pose("grip",Transform3D(Basis.IDENTITY,g.origin.to_local(where)),Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
  await create_timer(.2).timeout
 net.bbq.request(action,id,hand,at)
func run() -> void:
 var args:=OS.get_cmdline_user_args();role=args[0]
 g=load("res://scenes/main.tscn").instantiate();root.add_child(g);net=g.network
 if role=="server":
  check(g.server_only and not is_instance_valid(g.head),"Headless BBQ host loads no scene")
  check(await wait_for(func():return net.bbq.model.stations.has("fish_hoek_beach")),"Remote player starts BBQ at new maritime location")
  check(await wait_for(func():return not item(0).is_empty() and item(0).place=="grill"),"Host owns cooking state")
  check(await wait_for(func():return net.players.is_empty(),30),"All test peers departed")
  check(item(6).owner==0 and item(7).owner==0,"Departed cooks release utensils")
 else:
  await create_timer(.6).timeout
  g.set_process(false);g.motor.set_physics_process(false);g.fishing_feedback.set_process(false)
  g.game.reset();g._select_location("fish_hoek_beach",false);g.bbq.select_location()
  g.rod_holster.set_stowed(true);g.motor.relocate(Sites.arrival("fish_hoek_beach"));g.head.rotation=Vector3(-.2,0,0)
  g.bbq.set_process(false)
  g.head.position=Vector3(0,1.65,0)
  for hand in 2:
   var tracker:=XRControllerTracker.new();tracker.name="bbq_network_"+str(hand);XRServer.add_tracker(tracker);trackers.append(tracker)
   var controller:XRController3D=g.left if hand==0 else g.right;controller.tracker=tracker.name;controller.pose="grip"
   tracker.set_pose("grip",Transform3D(Basis.IDENTITY,Vector3(0,1.2,0)),Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
  g.xr=true;g.tracking_manager.focused=true;g.tracking_manager.calibration_pending=false
  var journal:Array=g.game.journal.duplicate(true)
  net.display_name=role;net.voice.set_mode(0)
  if role=="host":net.host(int(args[1]))
  else:net.join("127.0.0.1",int(args[1]))
  check(await wait_for(func():return net.active and net.players.size()>=2),"Prototype protocol handshake")
  await create_timer(.3).timeout
  if role in ["leader","host"]:
   await request("start")
   check(await wait_for(func():return net.bbq.model.stations.has("fish_hoek_beach")),"Shared kit arrives")
   await request("cooler")
   await request("grab",6,1)
   check(await wait_for(func():return item(6).owner==net.bbq.local_id()),"Client receives utensil ownership")
   await request("cook",0,1,Vector3(0,1,0))
   check(await wait_for(func():return item(0).place=="grill" and item(0).cook[0]>.02),"Host advances cooking independently")
   check(await wait_for(func():return item(1).place=="grill"),"Second cook acquired tongs before menu test")
   g._toggle_avatar_menu();await create_timer(.7).timeout
   check(item(0).cook[0]>.025,"Opening a menu does not pause shared cooking")
   g._toggle_avatar_menu()
   await request("grab",6,1);await create_timer(.3).timeout
   await request("cook",0,1);await create_timer(.5).timeout
   await request("cook",0,1)
   check(await wait_for(func():return item(0).place in ["served","hand","gone"]),"Serving synchronizes")
   await create_timer(8).timeout
  elif role=="observer":
   check(await wait_for(func():return item(6).owner>0),"Observer sees first cook")
   await request("start")
   var first:int=item(6).owner
   await request("grab",6,1);await create_timer(.4).timeout
   print("OWNERSHIP_CHECK ",first," → ",item(6).owner," self ",net.bbq.local_id())
   check(item(6).owner==first,"Simultaneous grab cannot steal tongs")
   check(net.bbq.model.stations.size()==1 and g.bbq.item_nodes.size()==10,"Repeated starts keep one shared station and inventory")
   await request("grab",7,1)
   check(await wait_for(func():return item(7).owner==net.bbq.local_id()),"Observer joins with second tongs")
   await request("cook",1,1)
   check(await wait_for(func():return item(1).place=="grill"),"Second player cooks independently")
   await request("drop",7,1)
   check(await wait_for(func():return item(0).place=="served"),"Observer sees served food")
   await request("grab",0,1)
   check(await wait_for(func():return item(0).owner==net.bbq.local_id()),"Observer can take another cook's serving")
   await request("eat",0,1)
   check(await wait_for(func():return item(0).place=="gone"),"Eating is synchronized")
   await create_timer(5).timeout
  else:
   check(await wait_for(func():return not item(1).is_empty() and item(1).place=="grill"),"Late join receives existing cooking state")
   check(item(1).cook[0]>0,"Late join preserves elapsed cooking")
   check(net.bbq.model.stations["fish_hoek_beach"].cooler_open,"Late join receives the shared cooler state")
   await create_timer(4).timeout
  check(g.game.journal==journal,"Shared cooking leaves fishing journal unchanged")
 print("BBQ_NETWORK_RESULT ",role," ",JSON.stringify(failures))
 net.leave()
 for p in g.find_children("*","AudioStreamPlayer",true,false):p.stop()
 for tracker in trackers:XRServer.remove_tracker(tracker)
 g.queue_free();await process_frame;await create_timer(.3).timeout;quit(0 if failures.is_empty() else 1)
