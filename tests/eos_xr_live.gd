extends SceneTree
## Real OpenXR rendering + two EOS clients. Hand poses are explicitly simulated.
const Probe=preload("res://tests/eos_live_game.gd").Probe
const Config=preload("res://scripts/network/eos/config.gd")
var game:Node
var net:Node
var probe:Probe
var role:=""
var output:=""
var handoff:=""
var failures:Array=[]
var samples:Array=[]
var trackers:Array[XRControllerTracker]=[]
var effect=preload("res://tests/xr_capture.gd").new()
var remote_xr:=false
var remote_hands:=false
var received_poses:=0
var last_serial:Dictionary={}
var maximum_players:=0
var elapsed:=0.0
var observing:=false
var trace_due:=0.0
func arg(key:String,fallback:String="")->String:
 var args:=OS.get_cmdline_user_args();var i:=args.find(key)
 return args[i+1] if i>=0 and i+1<args.size() else fallback
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->bool:
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
 return ok
func until(test:Callable,seconds:=30.0)->bool:
 var end:=Time.get_ticks_msec()+int(seconds*1000)
 while Time.get_ticks_msec()<end:
  if test.call():return true
  await create_timer(.05).timeout
 return false
func write(path:String,data:Dictionary)->void:
 FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(data,"\t"))
func _process(delta:float)->bool:
 if not observing:return false
 elapsed+=delta
 if elapsed>=trace_due:
  trace_due=elapsed+5.0
  var native:MultiplayerPeer=net.online.backend.peer
  print("EOS_XR_PROGRESS ",JSON.stringify({"role":role,"status":net.status,"active":net.active,"busy":net.online.busy,"members":net.online.backend.members.size(),"native_peers":native.get_all_peers().size() if native else 0,"native_status":native.get_connection_status() if native else 0,"admission_rejections":net.online.backend.rejected,"fps":Engine.get_frames_per_second(),"received_poses":received_poses}))
 for i in trackers.size():
  var pose:=Transform3D(Basis.IDENTITY,Vector3(-.3 if i==0 else .3,1.35,-.45+sin(elapsed)*.08))
  for key in ["grip","aim","default"]:trackers[i].set_pose(key,pose,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
 maximum_players=maxi(maximum_players,net.players.size())
 if net.active:
  for id in net.states:
   if id==net.multiplayer.get_unique_id():continue
   remote_xr=remote_xr or net.states[id].xr
   remote_hands=remote_hands or (net.states[id].left_valid and net.states[id].right_valid)
   if last_serial.get(id,-1)!=net.states[id].serial:
    received_poses+=1;last_serial[id]=net.states[id].serial
 return false
func capture(label:String)->void:
 effect.request_capture(label)
 if not check(await until(func():return effect.completed==label,15),"Stereo readback "+label):return
 check(effect.results.size()==2,"Two eye buffers "+label)
 for i in effect.results.size():
  var frame:Image=effect.results[i];frame.convert(Image.FORMAT_RGBA8);frame.linear_to_srgb()
  frame.save_png(output.path_join(label+"-eye%d.png"%i))
func run()->void:
 role=arg("--role");output=arg("--output");handoff=output.path_join("handoff.json")
 if role not in ["host","xr"] or output.is_empty():quit(2);return
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);current_scene=game
 net=game.network
 if net==null:quit(1);return
 net.display_name="EOS desktop fixture" if role=="host" else "EOS simulated XR"
 net.voice_enabled=false;net.voice.set_mode(0)
 game.motor.set_physics_process(false)
 game.fishing_feedback.set_process(false) # Synthetic trackers have no native haptic device.
 game._select_location("lakeside",false)
 game.motor.global_position=Vector3(1.3,0,-2.0) if role=="host" else Vector3.ZERO
 # The headless peer is a complete gameplay client with synthetic placement.
 if role=="host":game.head.position=Vector3(0,1.65,0);game.head.rotation.y=PI
 if not check(await until(func():return is_instance_valid(game.avatar) and not game.avatar_loading,90),"Local avatar ready"):await finish();return
 probe=Probe.new();probe.name="EOSProbe";game.add_child(probe)
 if role=="xr":
  if not check(game.xr and game.head.get_viewport().use_xr,"Native simulated OpenXR session"):await finish();return
  for i in 2:
   var tracker:=XRControllerTracker.new();tracker.type=XRServer.TRACKER_CONTROLLER;tracker.name="/eos_test_hand_%d"%i
   tracker.hand=XRPositionalTracker.TRACKER_HAND_LEFT if i==0 else XRPositionalTracker.TRACKER_HAND_RIGHT
   XRServer.add_tracker(tracker);trackers.append(tracker)
   var hand:XRController3D=game.left if i==0 else game.right;hand.tracker=tracker.name;hand.pose="grip"
  var compositor:=Compositor.new();compositor.compositor_effects=[effect];game.head.compositor=compositor
 observing=true
 if role=="host":
  if not check(await net.online.start(true,"","","Emulated XR crossplay test","xr-fixture")==OK,"Create named protected EOS lobby"):await finish();return
  write(handoff,{"reference":net.online.join_reference()})
  check(await until(func():return FileAccess.file_exists(handoff+".done"),240),"XR client completed")
  check(maximum_players==2 and remote_xr and remote_hands and received_poses>20,"XR state and simulated hands replicated to desktop")
  check(probe.received==4 and not probe.corrupt,"Bulk traffic across reconnect")
  await finish();return
 var reference:String=JSON.parse_string(FileAccess.get_file_as_string(handoff)).reference
 var found:=false
 for attempt in 10:
  await net.online.browse_lobbies()
  for row in net.online.lobbies:
   if row.id==Config.parse_reference(net.online.config,reference):found=row.title=="Emulated XR crossplay test" and row.locked and row.capacity==8
  if found:break
  await create_timer(2).timeout
 if not check(found,"Listed named eight-player password lobby"):await finish();return
 game._toggle_avatar_menu();game.avatar_menu.show_page("together")
 var menu=game.avatar_menu.multiplayer_page.get_child(2)
 menu.page(menu.browser);menu.selected=Config.parse_reference(net.online.config,reference);menu.refresh()
 await create_timer(1).timeout
 await capture("lobby-browser")
 # Exercise the menu's selected-lobby join action and password entry.
 menu.browser_password.text="xr-fixture";menu.join_button.pressed.emit()
 if not check(await until(func():return net.active and net.players.size()==2,45),"XR menu joins desktop over EOS"):await finish();return
 if not check(await until(func():return net.fighters.has(1) and not net.fighters[1].avatar_hash.is_empty(),60),"Remote avatar loaded in XR"):await finish();return
 await create_timer(1).timeout
 await capture("together-connected")
 game.avatar_menu_view.get_texture().get_image().save_png(output.path_join("together-panel.png"))
 if game.menu_open:game._toggle_avatar_menu()
 for connection in 2:
  var payload:=PackedByteArray();payload.resize(200000);payload.fill(53)
  probe.bulk.rpc_id(1,payload);probe.bulk.rpc_id(1,payload)
  var voice:=PackedByteArray();voice.resize(400)
  for i in 150:
   probe.voice.rpc_id(1,voice)
   if i%30==0:samples.append({"fps":Engine.get_frames_per_second(),"focused":game.tracking_manager.focused,"head":game.tracking_manager.head_tracked(),"players":net.players.size()})
   await create_timer(.02).timeout
  check(await until(func():return probe.received==(connection+1)*2,30),"Bulk echo %d"%connection)
  if connection==0:
   await capture("world-connected")
   net.leave();await until(func():return not net.online.busy and not net.online.stop_due)
   check(await net.online.start(false,reference,"","","xr-fixture")==OK,"Reconnect EOS")
   if not check(await until(func():return net.active and net.players.size()==2),"Reconnect gameplay"):await finish();return
 check(received_poses>20 and probe.voice_count>0 and not probe.corrupt,"Remote state and unreliable packets alongside reliable transfers")
 net.rankings.request("fishing","catches")
 check(await until(func():return net.rankings.view.get("players",0)==2),"Two records retained after reconnect")
 await finish()
func finish()->void:
 observing=false
 var stats:Dictionary=net.multiplayer.multiplayer_peer.diagnostics() if net.multiplayer.multiplayer_peer.has_method("diagnostics") else {}
 var route:String=net.online.backend.transport
 check(stats.get("wire_max_bytes",9999)+6<=1000 and not stats.get("failed",true),"EOS packet budget")
 if arg("--relay")=="force":check(route=="2","Forced EOS relay")
 net.leave()
 check(await until(func():return not net.online.busy and not net.online.stop_due and net.online.backend.lobby_id.is_empty()) and net.online.cleanup_ok,"EOS cleanup")
 write(output.path_join(role+".json"),{"role":role,"ok":failures.is_empty(),"failures":failures,"runtime":"Monado simulated" if role=="xr" else "headless desktop fixture","native_quest_tested":false,"meta_identity_tested":false,"renderer":RenderingServer.get_current_rendering_method(),"samples":samples,"maximum_players":maximum_players,"remote_xr":remote_xr,"remote_hands":remote_hands,"received_poses":received_poses,"bulk_received":probe.received if probe else 0,"voice_received":probe.voice_count if probe else 0,"network_type":route,"transport":stats})
 if role=="xr":write(handoff+".done",{})
 for tracker in trackers:XRServer.remove_tracker(tracker)
 game.head.compositor=null;game.ambience.stop();game.queue_free();await process_frame;await create_timer(.3).timeout
 print("EOS_XR_RESULT ",role," ",failures);quit(0 if failures.is_empty() else 1)
