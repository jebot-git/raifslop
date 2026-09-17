extends RefCounted
## Cage feeder: bait packed inside the basket and one bottom feed deposit per cast.
## Location pools are authored gameplay habitats, not surveys of photographed waters.
const BAIT_NAMES=["Earthworm","Sweetcorn","Maggots","Bread"]
const BAIT_MODELS=[0,1,3,4]
const POOLS={
 "lakeside":[0,1,3,4,5,8,16,32,33,34],
 "lake_pier":[0,1,3,5,32,33,34],
 "gray_pier":[0,1,3,4,5,8,16,32,33],
 "bell_park_pier":[0,1,3,4,5,8,9,16,32,34],
 "meadow_bend":[3,9,13,14,16,33,34]
}
const PREFERENCES={0:[0,3,4,5,9,13,16,32,33,34],1:[1,3,4,5,8,13,32,34],2:[0,3,5,9,13,14,16,32,33,34],3:[1,3,5,8,9,14,32,34]}
const DEPTHS={"lakeside":1.7,"lake_pier":2.8,"gray_pier":2.2,"bell_park_pier":1.9,"meadow_bend":1.1}
var age:=0.0
var depth:=0.0
var settle_time:=0.0
var deposited:=false
var patches:Dictionary={}
static func supported(id:String)->bool:return POOLS.has(id)
static func preferred(bait:int,id:String)->Array:
 var result:Array=[]
 for species in POOLS.get(id,[]):
  if species in PREFERENCES.get(bait,[]):result.append(species)
 return result
func reset()->void:
 age=0;depth=0;settle_time=0;deposited=false
func cast(id:String,sector:int)->void:
 reset();depth=float(DEPTHS.get(id,1.5))*(.8+.1*(sector/3))
 settle_time=depth/.8+.7
func tick(delta:float)->void:
 for key in patches.keys():
  patches[key]=maxf(0,patches[key]-delta/150.0)
  if patches[key]<=0:patches.erase(key)
func settle(delta:float,id:String,sector:int)->bool:
 age=minf(settle_time,age+delta)
 if age<settle_time:return false
 if not deposited:
  var key:=id+":"+str(sector)
  patches[key]=minf(1.0,float(patches.get(key,0))+.3);deposited=true
 return true
func attraction(id:String,sector:int)->float:return 1.0+float(patches.get(id+":"+str(sector),0))*.55
func drop()->float:return depth*clampf(age/maxf(.01,settle_time),0,1)
