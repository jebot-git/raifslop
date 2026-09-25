extends Node
## Server owns shared props and cooking; held meshes reuse replicated controller poses.
const Replication=preload("res://scripts/bbq/replication.gd")
var sent:Dictionary={}
var received:Dictionary={}
var resync_limits:Dictionary={}
var anchor_age:=0.0
var sync_due:=0.0
const Model=preload("res://scripts/bbq/model.gd")
const Sites=preload("res://scripts/bbq/sites.gd")
var model=Model.new()
var session:Node
var elapsed:=0.0
var limits:Dictionary={}
signal updated

func setup(owner_session:Node) -> void:
 session=owner_session
 name="BBQ"

func local_id() -> int:
 return multiplayer.get_unique_id() if session.active else 1

func actor(peer:int) -> Dictionary:
 if not session.active or (peer==local_id() and not session.dedicated):
  var g=session.root_game
  if not is_instance_valid(g) or not is_instance_valid(g.get("head")):return {}
  return {"location":g.current_location,"feet":g.motor.global_position,"head":g.head.global_transform,"left":g.controller_pose(0),"right":g.controller_pose(1),"left_valid":g.left.get_has_tracking_data(),"right_valid":g.right.get_has_tracking_data(),"xr":g.xr,"state":g.game.state}
 var data:Dictionary=session.states.get(peer,{})
 for key in ["location","feet","head","left","right","left_valid","right_valid","xr","state"]:
  if not data.has(key):return {}
 return data

func request(action:String,id:=-1,hand:=1,at:=Vector3.ZERO) -> void:
 var command:Dictionary={"action":action,"id":id,"hand":hand,"at":at}
 if not session.active or multiplayer.is_server():accept(local_id(),command)
 else:_request.rpc_id(1,command)

@rpc("any_peer","call_remote","reliable",0)
func _request(command:Dictionary) -> void:
 if session.active and multiplayer.is_server():accept(multiplayer.get_remote_sender_id(),command)

func accept(peer:int,command:Dictionary) -> bool:
 if session.active and not session.players.has(peer):return false
 if command.size()!=4 or not command.get("action") is String or not command.get("id") is int or not command.get("hand") is int or not command.get("at") is Vector3:return false
 if not command.at.is_finite() or command.at.length()>8 or command.hand not in [0,1]:return false
 # Returning ownership must remain possible after rapid input or location changes.
 if command.action=="release":
  var owned:=false
  for state in model.stations.values():
   for item in state.items:
    if item.owner==peer:owned=true
  if owned:model.release_peer(peer);broadcast()
  return true
 var guard:Dictionary=limits.get(peer,{"time":model.clock,"tokens":12.0})
 guard.tokens=minf(12,guard.tokens+maxf(0,model.clock-guard.time)*10);guard.time=model.clock;limits[peer]=guard
 if guard.tokens<1:return false
 guard.tokens-=1
 var who:=actor(peer)
 if who.is_empty() or not Sites.supported(who.location):return false
 var location:String=who.location
 if who.state!=0:return false
 if command.action=="start":
  var ok:bool=model.start(location)
  if ok:broadcast()
  return ok
 if not model.stations.has(location) or who.state!=0:return false
 var pose:=Sites.pose(location)
 if who.feet.distance_to(pose.origin)>5:return false
 var hand_name:String="left" if command.hand==0 else "right"
 if not who[hand_name+"_valid"]:return false
 if command.action=="cooler":
  var reach:float=.35
  var from:Vector3=who[hand_name].origin
  if from.distance_to(pose*Sites.COOLER_HANDLE)>reach:return false
  var changed:bool=model.apply(location,peer,command.hand,"cooler",-1)
  if changed:broadcast()
  return changed
 if command.id<0 or command.id>=10:return false
 var item:Dictionary=model.stations[location].items[command.id]
 if command.action in ["grab","clamp"]:
  var reach:float=.8
  var reach_from:Vector3=who[hand_name].origin
  if reach_from.distance_to(pose*Model.resting_pose(item).origin)>reach:return false
  if command.action=="clamp":
   var tip:Vector3=who[hand_name]*Vector3(0,0,-.25)
   if tip.distance_to(pose*Model.resting_pose(item).origin)>.25:return false
 if command.action in ["eat","sip"] and (command.action=="eat" or item.open):
  if who[hand_name].origin.distance_to(who.head.origin)>.45:return false
 var ok:bool=model.apply(location,peer,command.hand,command.action,command.id,command.at,pose.affine_inverse()*who[hand_name])
 if ok:broadcast()
 return ok

func broadcast() -> void:
 updated.emit()
 if not session.active or not multiplayer.is_server():return
 for peer in session.players:
  if peer==1:continue
  var who:=actor(peer)
  if who.is_empty():continue
  var location:String=who.location
  if not Sites.supported(location):
   if sent.has(peer):sent[peer].location=""
   continue
  var update:=Replication.build(sent.get(peer,{}),location,model.stations.get(location,{}),model.clock)
  if not update.is_empty():
   sent[peer]=update.baseline
   _delta.rpc_id(peer,update.data)

@rpc("authority","call_remote","reliable",0)
func _delta(data:Dictionary) -> void:
 if multiplayer.is_server():return
 var next:=Replication.apply(received,data)
 if next.is_empty():
  if Replication.valid(data) and (received.is_empty() or data.seq>received.seq) and Time.get_ticks_msec()>=sync_due:
   sync_due=Time.get_ticks_msec()+1000
   _resync.rpc_id(1)
  return
 received=next;anchor_age=0.0
 _render_anchor()
 updated.emit()

@rpc("any_peer","call_remote","reliable",0)
func _resync() -> void:
 if not session.active or not multiplayer.is_server():return
 var peer:=multiplayer.get_remote_sender_id()
 if not session.players.has(peer):return
 var prior:Dictionary=sent.get(peer,{})
 if prior.is_empty() or model.clock-float(resync_limits.get(peer,-10))<1:return
 # Keep sequence monotonic when replacing an invalid/missing receiver baseline.
 prior.location="";resync_limits[peer]=model.clock
 broadcast()

func _render_anchor() -> void:
 model.stations.clear()
 if received.is_empty():return
 model.clock=received.clock+anchor_age
 if not received.state.is_empty():
  var state:Dictionary=received.state.duplicate(true)
  Replication.cook(state,anchor_age)
  model.stations[received.location]=state

func _process(delta:float) -> void:
 if session==null:return
 if session.active and not multiplayer.is_server():
  anchor_age+=maxf(0,delta);model.clock+=maxf(0,delta)
  for state in model.stations.values():Replication.cook(state,delta)
  return
 var occupied:Array=[]
 var peers:Array=session.players.keys() if session.active else [1]
 for peer in peers:
  var who:=actor(peer)
  if who.is_empty():continue
  if Sites.supported(who.location) and who.feet.distance_to(Sites.pose(who.location).origin)<5:occupied.append(who.location)
 for location in model.stations:
  for item in model.stations[location].items:
   if item.owner==0:continue
   var who:=actor(item.owner) if item.owner in peers else {}
   if who.is_empty() or who.location!=location or who.feet.distance_to(Sites.pose(location).origin)>6 or who.state!=0 or not who.get("left_valid" if item.hand==0 else "right_valid",false):
    model.release_peer(item.owner)
 model.tick(delta,occupied)
 elapsed+=delta
 if elapsed>=.25:elapsed=0;broadcast()

func reset() -> void:
 model=Model.new();limits.clear();sent.clear();received.clear();resync_limits.clear();anchor_age=0;sync_due=0;elapsed=0;updated.emit()
