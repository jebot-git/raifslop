extends SceneTree
var failures:=0
var checks:=0
var net:Node
var role:=""
func _initialize()->void:run.call_deferred()
func check(ok:bool,message:String)->void:
 checks+=1
 if ok:print("PASS ",message)
 else:failures+=1;push_error(message)
func until(fn:Callable,seconds:=18.0)->bool:
 var deadline:=Time.get_ticks_msec()+int(seconds*1000)
 while Time.get_ticks_msec()<deadline:
  if fn.call():return true
  await create_timer(.04).timeout
 return false
func send_pose(course:bool,serial:int)->void:
 var schema=load("res://scripts/network/state.gd")
 var location:String="golf_spyglass_clubhouse" if course else "lakeside"
 var at:Vector3=load("res://scripts/bbq/sites.gd").arrival(location)
 var data:Dictionary={"user_height":1.78,"serial":serial,"location":location,"body":{},"face":{},"visemes":PackedFloat32Array([0,0,0,0,0]),"state":0,"bait":0,"species":0,"rod_tier":0,"rig":0,"length":10.0,"curl":0.0,"reel_angle":0.0,"golf_club":0 if course else -1,"golf_stowed":course}
 for key in schema.TRANSFORMS:data[key]=Transform3D(Basis.IDENTITY,at+Vector3(0,1.7,0))
 for key in schema.VECTORS:data[key]=at
 for key in ["caught","in_hand","xr","bobber_visible","bait_visible"]:data[key]=false
 data.left_valid=true;data.right_valid=true
 check(schema.valid(data),"Activity pose passes shared schema validation")
 net.states[net.multiplayer.get_unique_id()]=data
 net._submit_event.rpc_id(1,net.PoseCodec.encode(data))
func run()->void:
 var args:=OS.get_cmdline_user_args();role=args[0];var port:=int(args[1])
 # No render, microphone, or fake pose traffic: exercise the real ENet/session RPCs.
 var owner:=Node.new();root.add_child(owner)
 net=load("res://scripts/network/session.gd").new();owner.add_child(net);net.setup(owner,true)
 net.voice_enabled=false
 net.player_token=("a" if role=="A" else "b").repeat(64);net.display_name=role
 if role=="server":
  check(net.host(port,"127.0.0.1")==OK,"Dedicated host starts")
  check(await until(func():return net.players.size()==2),"Both clients complete shared Fishing handshake")
  check(net.voice.recipients(net.players.keys()[0],true).size()==1,"Radio recipients cross activity/location boundaries")
  check(await until(func():return net.states.size()==2 and not net.same_location(net.players.keys()[0],net.players.keys()[1])),"Proximity voice remains location-scoped")
  check(await until(func():
   var m:Dictionary=net.golf.rules.membership("a".repeat(64).sha256_text())
   return not m.is_empty() and m.game.hole==0 and m.game.epoch>=3 and m.game.deadline>0),"Fishing player remains enrolled with return deadline")
  check(not net.same_location(net.players.keys()[0],net.players.keys()[1]) and net.voice.recipients(net.players.keys()[0],true).size()==1,"Radio still routes between actual fishing and golf poses")
  var game:Dictionary=net.golf.rules.games.spyglass
  net.golf.rules.tick(game.deadline);net.golf.publish()
  check(await until(func():return net.golf.rules.games.spyglass.finished,25),"Retirement removes every active participant")
  var record_key:String="a".repeat(64).sha256_text()
  net.leaderboard.records[record_key].catches=7
  var scores:Array=[];scores.resize(18);scores.fill(4)
  load("res://addons/golfminus/scripts/golf/server_records.gd").finish(net.leaderboard.records,record_key,"spyglass",scores)
  net.leaderboard.dirty=true;check(net.leaderboard.save()==OK,"Golf and Fishing use one atomic persistence write")
  var restored=load("res://scripts/network/leaderboard.gd").new();restored.start(net.leaderboard.path)
  check(restored.error.is_empty() and restored.records[record_key].golf.spyglass.best==72 and restored.records[record_key].catches==7,"Fishing and golf records survive server file reload together")
  check(await until(func():return net.players.is_empty(),25),"Clients acknowledge final retirement before server stops")
 else:
  net.join("127.0.0.1",port)
  check(await until(func():return net.active),"Client connects through existing identity protocol")
  if role=="B":await create_timer(1).timeout
  send_pose(true,1)
  await create_timer(.3).timeout
  net.golf.request("join",{"course":"spyglass","mode":"competition"})
  check(await until(func():return not net.golf.view.is_empty()),"Course membership arrives by reliable RPC")
  check(await until(func():return net.golf.view.roster.size()==2),"Players gather in clubhouse")
  if role=="A":net.golf.request("start")
  check(await until(func():return net.golf.view.started),"Competition starts explicitly")
  send_pose(role=="B",2)
  if role=="A":
   net.golf.request("presence",{"present":true})
   check(await until(func():return net.golf.can_shoot() and net.golf.view.roster.size()==2),"First player claims turn after both enroll")
   var epoch:int=net.golf.view.epoch
   net.golf.request("shot",{"epoch":epoch})
   check(await until(func():return net.golf.view.flight),"Server grants shot before local launch")
   net.golf.request("settled",{"epoch":epoch,"holed":false})
   check(await until(func():return net.golf.view.your_turn and net.golf.view.epoch>epoch),"Turn returns after other player's hole")
   net.golf.request("presence",{"present":false})
   check(await until(func():return net.golf.view.hole==1),"Server timeout advances forfeited hole while away")
   check(net.golf.view.scores==[load("res://addons/golfminus/scripts/golf/handicap.gd").cap("spyglass",0,54)],"Client receives net-double-bogey timeout score")
   net.golf.request("retire")
   check(await until(func():return net.golf.view.get("retired",false)),"Retirement acknowledged")
  else:
   net.bbq.request("start")
   check(await until(func():return net.bbq.model.stations.has("golf_spyglass_clubhouse")),"Remote player starts existing BBQ on golf course")
   var state:Dictionary=net.states[net.multiplayer.get_unique_id()]
   var site:Transform3D=load("res://scripts/bbq/sites.gd").pose("golf_spyglass_clubhouse")
   state.serial+=1;state.right=site*Transform3D(Basis.IDENTITY,net.bbq.model.stations.golf_spyglass_clubhouse.items[6].pos)
   net._submit_event.rpc_id(1,net.PoseCodec.encode(state));await create_timer(.25).timeout
   net.bbq.request("grab",6,1)
   check(await until(func():return net.bbq.model.stations.golf_spyglass_clubhouse.items[6].owner==net.multiplayer.get_unique_id()),"Shared BBQ grants remote tongs ownership")
   var food:Dictionary=net.bbq.model.stations.golf_spyglass_clubhouse.items[0]
   state.serial+=1;state.right=site*Transform3D(Basis.IDENTITY,load("res://scripts/bbq/model.gd").resting_pose(food).origin+Vector3(0,0,.25))
   net._submit_event.rpc_id(1,net.PoseCodec.encode(state));await create_timer(.25).timeout
   net.bbq.request("clamp",0,1)
   check(await until(func():return net.bbq.model.stations.golf_spyglass_clubhouse.items[0].place=="tongs"),"Clubhouse food clamps to the held tongs")
   food=net.bbq.model.stations.golf_spyglass_clubhouse.items[0]
   state.serial+=1;state.right=site*Transform3D(Basis.IDENTITY,load("res://scripts/bbq/sites.gd").grill(1)-food.grip_offset.origin)
   net._submit_event.rpc_id(1,net.PoseCodec.encode(state));await create_timer(.25).timeout
   net.bbq.request("unclamp",0,1)
   check(await until(func():return net.bbq.model.stations.golf_spyglass_clubhouse.items[0].cook[0]>0),"Server cooks golf BBQ food while course turn is pending")
   net.bbq.request("release")
   check(await until(func():return net.golf.view.your_turn),"Turn notification state reaches player outside course")
   check(net.golf.view.remaining>290 and not net.golf.view.present,"Away notification carries five-minute deadline")
   net.golf.request("presence",{"present":true})
   check(await until(func():return net.golf.can_shoot()),"Player can rejoin ongoing course")
   var epoch:int=net.golf.view.epoch
   net.golf.request("shot",{"epoch":epoch})
   check(await until(func():return net.golf.view.flight),"Second player gets shot grant")
   net.golf.request("settled",{"epoch":epoch,"holed":true})
   check(await until(func():return net.golf.view.hole==1),"Peer observes server hole advance")
   net.leave();await create_timer(.4).timeout;net.join("127.0.0.1",port)
   check(await until(func():return net.active and not net.golf.view.is_empty()),"Reconnect restores membership by Fishing identity")
   check(net.golf.view.scores==[1],"Reconnect preserves completed scorecard")
   net.golf.request("retire")
   check(await until(func():return net.golf.view.get("retired",false)),"Reconnected player can retire")
  await create_timer(.5).timeout
 net.leave();owner.queue_free();await process_frame
 print("HOST GOLF NETWORK ",role," ",checks-failures,"/",checks," passed");quit(1 if failures else 0)
