extends RefCounted
## Bounded leisure state. No fishing session, journal, currency or population access.
const Sites=preload("res://scripts/bbq/sites.gd")
const FOODS=["sausage","corn","mushroom"]
const COOK_SECONDS := 42.0
const IDLE_SECONDS := 180.0
var stations:Dictionary={}
var clock:=0.0

func start(location:String) -> bool:
 if not Sites.SITES.has(location):return false
 if stations.has(location):return true
 var items:Array=[]
 for i in 10:
  var kind:String=FOODS[i%3] if i<6 else ("tongs" if i<8 else "drink")
  var item:Dictionary={"id":i,"kind":kind,"owner":0,"hand":0,"place":"pantry","slot":i,"side":0,"cook":[0.0,0.0],"open":false,"sips":0,"reset_at":0.0}
  item.pos=Sites.home(item);items.append(item)
 stations[location]={"items":items,"idle":clock,"revision":1}
 return true

func held(location:String,peer:int,hand:int) -> int:
 if not stations.has(location):return -1
 for item in stations[location].items:
  if item.owner==peer and item.hand==hand:return item.id
 return -1

func release_peer(peer:int) -> void:
 for location in stations:
  for item in stations[location].items:
   if item.owner==peer: _return(item);stations[location].revision+=1

func _return(item:Dictionary) -> void:
 item.owner=0;item.place="pantry";item.pos=Sites.home(item)
 if item.kind in FOODS:
  item.cook=[0.0,0.0];item.side=0
 item.open=false;item.sips=0;item.reset_at=0.0

func apply(location:String,peer:int,hand:int,action:String,id:int,at:Vector3=Vector3.ZERO) -> bool:
 if not stations.has(location) or hand not in [0,1] or peer<1 or id<0 or id>=10:return false
 var state:Dictionary=stations[location]
 var item:Dictionary=state.items[id]
 var tool_id:=held(location,peer,hand)
 match action:
  "grab":
   if item.owner!=0 or tool_id!=-1 or item.place in ["grill","gone"]:return false
   item.owner=peer;item.hand=hand;item.place="hand"
  "drop":
   if item.owner!=peer or item.hand!=hand:return false
   item.owner=0
   if item.kind in FOODS:
    item.place="served";item.pos=Sites.plate(item.id);item.reset_at=clock+90
   else:_return(item)
  "cook":
   if tool_id<0 or state.items[tool_id].kind!="tongs" or item.owner!=0 or item.kind not in FOODS or item.place=="gone":return false
   if item.place=="pantry" or item.place=="served":
    var taken:Array=[]
    for other in state.items:
     if other.place=="grill":taken.append(other.slot)
    var slot:int=-1
    var distance:=INF
    for i in 6:
     if not i in taken and Sites.grill(i).distance_to(at)<distance:
      slot=i;distance=Sites.grill(i).distance_to(at)
    if slot<0:return false
    item.place="grill";item.slot=slot;item.pos=Sites.grill(slot);item.reset_at=0.0
   elif item.place=="grill":
    if item.side==0:item.side=1
    else:item.place="served";item.pos=Sites.plate(item.id);item.reset_at=clock+90
  "cool":
   if tool_id<0 or state.items[tool_id].kind!="tongs" or item.place!="grill" or item.owner!=0:return false
   var occupied:Array=[]
   for other in state.items:
    if other.place=="grill":occupied.append(other.slot)
   var candidate:int=-1
   for i in [0,2,3,5,1,4]:
    if not i in occupied:candidate=i;break
   if candidate<0:return false
   item.slot=candidate;item.pos=Sites.grill(candidate)
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
   if item.place=="grill":
    var rate:=1.0 if item.slot%3==1 else .68
    item.cook[item.side]=minf(3.0,item.cook[item.side]+delta*rate/COOK_SECONDS)
   if item.reset_at>0 and clock>=item.reset_at:_return(item);state.revision+=1

static func doneness(item:Dictionary) -> String:
 if maxf(item.cook[0],item.cook[1])>=1.85:return "Charred! Fresh food is free."
 if minf(item.cook[0],item.cook[1])>=.85:return "Golden · ready to share"
 if maxf(item.cook[0],item.cook[1])>=.85:return "Browning · turn it over"
 return "Warming gently"
