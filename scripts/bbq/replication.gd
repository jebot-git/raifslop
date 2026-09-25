extends RefCounted
## Reliable per-recipient baselines; cooking is reconstructed from server time anchors.
const Model=preload("res://scripts/bbq/model.gd")
const Sites=preload("res://scripts/bbq/sites.gd")
const ANCHOR_SECONDS:=5.0
static func cook(state:Dictionary,seconds:float)->void:
 for item in state.get("items",[]):
  if item.place=="grill":
   var rate:=1.0 if item.slot%3==1 else .68
   item.cook[item.side]=minf(3.0,item.cook[item.side]+maxf(0,seconds)*rate/Model.COOK_SECONDS)
static func structure(item:Dictionary)->Dictionary:
 var result:=item.duplicate(true);result.erase("cook")
 return result
# Returns both the wire message and the next private sender baseline.
static func build(previous:Dictionary,location:String,state:Dictionary,clock:float)->Dictionary:
 var full:bool=previous.is_empty() or previous.location!=location or previous.state.is_empty()!=state.is_empty()
 var items:Array=[]
 if not state.is_empty():
  for item in state.items:
   if full or structure(item)!=structure(previous.state.items[item.id]) or (item.place=="grill" and clock-previous.clock>=ANCHOR_SECONDS):items.append(item.duplicate(true))
 if not full and items.is_empty() and (state.is_empty() or state.revision==previous.state.revision):return {}
 var seq:int=int(previous.get("seq",0))+1
 var data:Dictionary={"location":location,"seq":seq,"base":0 if full else int(previous.seq),"clock":clock,"exists":not state.is_empty(),"items":items,"cooler_open":state.get("cooler_open",false),"revision":state.get("revision",0)}
 return {"data":data,"baseline":{"location":location,"seq":seq,"state":state.duplicate(true),"clock":clock}}
static func valid(data:Dictionary)->bool:
 if data.size()!=8 or not data.get("location") is String or not Sites.supported(data.location):return false
 for key in ["seq","base","revision"]:
  if not data.get(key) is int or data[key]<0:return false
 if data.seq<=data.base or not (data.get("clock") is float or data.get("clock") is int) or not is_finite(data.clock) or data.clock<0:return false
 if not data.get("exists") is bool or not data.get("cooler_open") is bool or not data.get("items") is Array or data.items.size()>10:return false
 if not data.exists and not data.items.is_empty():return false
 if data.base==0 and data.exists and data.items.size()!=10:return false
 var ids:Array=[]
 for item in data.items:
  if not item is Dictionary or item.size()>16:return false
  for key in ["id","owner","hand","slot","side","sips"]:
   if not item.get(key) is int:return false
  if item.id<0 or item.id>=10 or item.id in ids:return false
  ids.append(item.id)
  var kind:String=Model.FOODS[item.id%4] if item.id<6 else ("tongs" if item.id<8 else "drink")
  if item.get("kind")!=kind or item.owner<0 or item.hand not in [0,1] or item.side not in [0,1] or item.slot<0 or item.slot>9 or item.sips<0 or item.sips>3:return false
  if item.get("place") not in ["pantry","hand","tongs","grill","served","gone"] or not item.get("open") is bool:return false
  if not item.get("pos") is Vector3 or not item.pos.is_finite():return false
  if not item.get("cook") is Array or item.cook.size()!=2:return false
  for value in item.cook:
   if not (value is float or value is int) or not is_finite(value) or value<0 or value>3:return false
  if not (item.get("reset_at") is float or item.get("reset_at") is int) or not is_finite(item.reset_at) or item.reset_at<0:return false
  if item.has("basis") and (not item.basis is Basis or not item.basis.is_finite()):return false
  if item.place=="tongs" and not item.has("grip_offset"):return false
  if item.has("grip_offset") and (not item.grip_offset is Transform3D or not item.grip_offset.is_finite()):return false
 return true
static func apply(previous:Dictionary,data:Dictionary)->Dictionary:
 if not valid(data):return {}
 if not previous.is_empty() and data.seq<=previous.seq:return {}
 if data.base!=0 and (previous.is_empty() or previous.seq!=data.base or previous.location!=data.location or data.clock<previous.clock):return {}
 var state:Dictionary={}
 if data.exists:
  if data.base==0:
   var items:Array=[];items.resize(10)
   for item in data.items:items[item.id]=item.duplicate(true)
   state={"items":items}
  else:
   if previous.state.is_empty():return {}
   state=previous.state.duplicate(true);cook(state,data.clock-previous.clock)
   for item in data.items:state.items[item.id]=item.duplicate(true)
  state.cooler_open=data.cooler_open;state.revision=data.revision;state.idle=data.clock
 return {"location":data.location,"seq":data.seq,"clock":data.clock,"state":state}
