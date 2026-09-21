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
const HOOK_WINDOW:=3.5
const NIBBLE_DURATION:=.18
const BITE_PULSE_DURATION:=.4
var age:=0.0
var depth:=0.0
var settle_time:=0.0
var deposited:=false
var patches:Dictionary={}
var nibbling:=false
var nibble_count:=0
var nibbles_left:=0
var next_nibble:=0.0
var pulse_age:=NIBBLE_DURATION
var bite_age:=BITE_PULSE_DURATION
static func supported(id:String)->bool:return POOLS.has(id)
static func preferred(bait:int,id:String)->Array:
 var result:Array=[]
 for species in POOLS.get(id,[]):
  if species in PREFERENCES.get(bait,[]):result.append(species)
 return result
func reset()->void:
 age=0;depth=0;settle_time=0;deposited=false
 nibbling=false;nibble_count=0;nibbles_left=0;next_nibble=0
 pulse_age=NIBBLE_DURATION;bite_age=BITE_PULSE_DURATION
func cast(id:String,sector:int)->void:
 reset();depth=float(DEPTHS.get(id,1.5))*(.8+.1*(sector/3))
 settle_time=depth/.8+.7
func tick(delta:float)->void:
 pulse_age+=delta;bite_age+=delta
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
func begin_nibbles(rng:RandomNumberGenerator)->void:
 nibbling=true;nibbles_left=rng.randi_range(2,4)
 _nibble(rng)
func _nibble(rng:RandomNumberGenerator)->void:
 nibble_count+=1;nibbles_left-=1;pulse_age=0
 next_nibble=rng.randf_range(.75,1.25)
func advance_nibbles(delta:float,rng:RandomNumberGenerator)->bool:
 next_nibble-=delta
 if next_nibble>0:return false
 if nibbles_left>0:
  _nibble(rng);return false
 nibbling=false;bite_age=0
 return true
func tip_load(biting:bool)->float:
 # Brief light knocks, then one strong pull that settles into a held bend.
 if biting:return .05+.10*maxf(0,1-bite_age/BITE_PULSE_DURATION)
 return .022+.024*maxf(0,1-pulse_age/NIBBLE_DURATION) if nibbling else .022
