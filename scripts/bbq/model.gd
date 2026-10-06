extends RefCounted
## Bounded leisure state. No fishing session, journal, currency or population access.
const Sites=preload("res://scripts/bbq/sites.gd")
const FOODS=["fish_burger","sausage","corn","mushroom"]
# Measured centred half-heights after the activity's 17.5 cm width clamp.
const HALF_HEIGHT={"fish_burger":.05230104,"sausage":.02004437,"corn":.02649241,"mushroom":.04729418}
const COOK_SECONDS := 42.0
const THROW_RESPAWN_SECONDS := 20.0
const IDLE_SECONDS := 180.0
var stations:Dictionary={}
var clock:=0.0

func start(location:String) -> bool:
 if not Sites.supported(location):return false
 if stations.has(location):return true
 var items:Array=[]
 for i in 10:
  var kind:String=FOODS[i%FOODS.size()] if i<6 else ("tongs" if i<8 else "drink")
  var item:Dictionary={"id":i,"kind":kind,"owner":0,"hand":0,"place":"pantry","slot":i,"side":0,"cook":[0.0,0.0],"open":false,"sips":0,"reset_at":0.0}
  item.pos=Sites.home(item);items.append(item)
 stations[location]={"items":items,"cooler_open":false,"idle":clock,"revision":1}
 return true

func held(location:String,peer:int,hand:int) -> int:
 if not stations.has(location):return -1
 for item in stations[location].items:
  if item.owner==peer and item.hand==hand and item.place!="tongs":return item.id
 return -1

func clamped(location:String,peer:int,hand:int) -> int:
 if not stations.has(location):return -1
 for item in stations[location].items:
  if item.owner==peer and item.hand==hand and item.place=="tongs":return item.id
 return -1

static func resting_pose(item:Dictionary) -> Transform3D:
 var pos:Vector3=item.pos
 if item.kind in FOODS and item.place!="thrown":pos.y+=HALF_HEIGHT[item.kind]-.041
 return Transform3D(item.get("basis",Basis.IDENTITY),pos)

func place_food(location:String,item:Dictionary,pose:Transform3D) -> void:
 item.side=0 if pose.basis.y.dot(Vector3.UP)>=0 else 1
 var x:=Vector3(pose.basis.x.x,0,pose.basis.x.z).normalized()
 if x.length_squared()<.1:x=Vector3.RIGHT
 var up:=Vector3.UP if item.side==0 else Vector3.DOWN
 item.basis=Basis(x,up,x.cross(up)).orthonormalized()
 item.owner=0;item.erase("grip_offset")
 var slot:=-1;var distance:=INF
 if absf(pose.origin.x)<.38 and absf(pose.origin.z)<.32 and pose.origin.y>.82 and pose.origin.y<1.4:
  var occupied:Array=[]
  for other in stations[location].items:
   if other.place=="grill":occupied.append(other.slot)
  for i in 6:
   var d:=Vector2(pose.origin.x-Sites.grill(i).x,pose.origin.z-Sites.grill(i).z).length()
   if not i in occupied and d<distance:slot=i;distance=d
 if slot>=0:
  item.place="grill";item.slot=slot;item.pos=Sites.grill(slot);item.reset_at=0.0
 else:
  item.place="served";item.pos=Sites.plate(item.id);item.reset_at=clock+90

func release_peer(peer:int) -> void:
 for location in stations:
  for item in stations[location].items:
   if item.owner==peer: _return(item);stations[location].revision+=1

func _return(item:Dictionary) -> void:
 item.owner=0;item.place="pantry";item.pos=Sites.home(item);item.basis=Basis.IDENTITY;item.erase("grip_offset")
 if item.kind in FOODS:
  item.cook=[0.0,0.0];item.side=0
 item.open=false;item.sips=0;item.reset_at=0.0;item.erase("velocity");item.erase("spin")

func apply(location:String,peer:int,hand:int,action:String,id:int,at:Vector3=Vector3.ZERO,pose:Transform3D=Transform3D.IDENTITY) -> bool:
 if not stations.has(location) or hand not in [0,1] or peer<1 or not pose.is_finite() or absf(pose.basis.determinant())<.01:return false
 var state:Dictionary=stations[location]
 if action=="cooler":
  state.cooler_open=not state.cooler_open;state.idle=clock;state.revision+=1;return true
 if id<0 or id>=10:return false
 var item:Dictionary=state.items[id]
 var tool_id:=held(location,peer,hand)
 match action:
  "grab":
   if item.owner!=0 or tool_id!=-1 or item.place in ["grill","gone"]:return false
   if item.kind=="drink" and item.place=="pantry" and not state.cooler_open:return false
   item.owner=peer;item.hand=hand;item.place="hand";item.reset_at=0;item.erase("velocity");item.erase("spin")
  "drop":
   if item.owner!=peer or item.hand!=hand:return false
   if item.kind=="tongs":
    var carried:=clamped(location,peer,hand)
    if carried>=0:
     var food:Dictionary=state.items[carried]
     if at.length()>1.0:throw_item(food,pose*food.grip_offset,at)
     else:place_food(location,food,pose*food.grip_offset)
   if item.kind=="tongs":_return(item)
   else:throw_item(item,pose,at)
  "clamp":
   if tool_id<0 or state.items[tool_id].kind!="tongs" or clamped(location,peer,hand)>=0 or item.owner!=0 or item.kind not in FOODS or item.place=="gone":return false
   item.grip_offset=pose.affine_inverse()*resting_pose(item)
   item.owner=peer;item.hand=hand;item.place="tongs";item.reset_at=0.0
  "unclamp":
   if tool_id<0 or state.items[tool_id].kind!="tongs" or clamped(location,peer,hand)!=id:return false
   if at.length()>1.0:throw_item(item,pose*item.grip_offset,at)
   else:place_food(location,item,pose*item.grip_offset)
  "eat":
   if item.owner!=peer or item.hand!=hand or item.kind not in FOODS:return false
   item.owner=0;item.place="gone";item.reset_at=clock+3
  "sip":
   if item.owner!=peer or item.hand!=hand or item.kind!="drink":return false
   if not item.open:item.open=true
   else:
    item.sips+=1
    if item.sips>=3:item.owner=0;item.place="gone";item.reset_at=clock+3
  _ :return false
 state.idle=clock;state.revision+=1
 return true

func tick(delta:float,occupied:Array) -> void:
 clock+=maxf(delta,0.0)
 for location in stations.keys():
  var state:Dictionary=stations[location]
  if location in occupied:state.idle=clock
  elif clock-state.idle>IDLE_SECONDS:stations.erase(location);continue
  for item in state.items:
   if item.place=="thrown":advance_throw(item,delta,location)
   if item.place=="grill":
    var rate:=1.0 if item.slot%3==1 else .68
    item.cook[item.side]=minf(3.0,item.cook[item.side]+delta*rate/COOK_SECONDS)
   if item.reset_at>0 and clock>=item.reset_at:_return(item);state.revision+=1

static func doneness(item:Dictionary) -> String:
 if maxf(item.cook[0],item.cook[1])>=1.85:return "Charred! Fresh food is free."
 if minf(item.cook[0],item.cook[1])>=.85:return "Golden · ready to share"
 if maxf(item.cook[0],item.cook[1])>=.85:return "Browning · turn it over"
 return "Warming gently"

func throw_item(item:Dictionary,pose:Transform3D,velocity:Vector3)->void:
 item.owner=0;item.place="thrown";item.erase("grip_offset")
 item.pos=pose.origin;item.basis=pose.basis.orthonormalized()
 if item.kind=="drink":item.basis*=Basis(Vector3.RIGHT,-PI/2)
 item.velocity=velocity.limit_length(8.0);item.spin=Vector3(2,1,3)*minf(velocity.length(),4)
 item.reset_at=clock+THROW_RESPAWN_SECONDS

static func advance_throw(item:Dictionary,delta:float,location:String)->void:
 var remaining:=minf(maxf(delta,0),.25)
 while remaining>0:
  var step:=minf(remaining,1.0/72);remaining-=step
  item.velocity.y-=9.81*step
  item.pos+=item.velocity*step
  var speed:float=item.spin.length()
  if speed>.001:item.basis=(Basis(item.spin/speed,speed*step)*item.basis).orthonormalized()
  var radius:float=HALF_HEIGHT[item.kind] if item.kind in FOODS else .06
  var floor_y:float=-Sites.pose(location).origin.y+radius
  if location in ["meadow_bend","boulder_run","cedar_creek","glacier_run"]:
   var world:Vector3=Sites.pose(location)*item.pos
   floor_y=preload("res://scripts/river_geometry.gd").ground_height(world.x,world.z,false)-Sites.pose(location).origin.y+radius
  # The station top catches dropped props; elsewhere they bounce on the bank.
  if absf(item.pos.x)<.94 and absf(item.pos.z)<.27 and item.pos.y>.82:floor_y=.91+radius
  if item.pos.y<floor_y:
   item.pos.y=floor_y
   item.velocity.y=absf(item.velocity.y)*.3
   item.velocity.x*=.78;item.velocity.z*=.78;item.spin*=.7
   if item.velocity.length()<.15:item.velocity=Vector3.ZERO;item.spin=Vector3.ZERO
