extends RefCounted
## Fishing's outlined mint symbols, extended with original golf pictograms.
static var enabled:=true
static var textures:Dictionary={}
const KEYS=["grip","tracking","menu","left","right","up","warning","stop","flag","course","driver","iron","putter","bag","fit","accept","cancel","return","godview","pan","orbit","zoom","ball","grid","capture","stash","swing","score","wind","reach","flight"]
static func texture(key:String)->Texture2D:
	if key not in KEYS:key="warning"
	if not textures.has(key):textures[key]=load("res://addons/golfminus/assets/ui/pictograms/"+key+".svg")
	return textures[key]
static func club(index:int)->String:
	return "driver" if index<2 else "putter" if index==7 else "iron"
