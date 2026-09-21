extends RefCounted
## Shared, original vector symbols; no font glyph or translated-text dependency.
const KEYS=["cast","extend","left","right","up","mend","reel","stop","warning","fish","lost","tracking","menu","grip","radio","transmit","feeder","lure","bbq","tongs","flip","serve","eat","drink","cooler","open_can","burger","trigger","ready"]
static var enabled:=true
static var textures:Dictionary={}
static func texture(key:String)->Texture2D:
 if key not in KEYS:key="warning"
 if not textures.has(key):textures[key]=load("res://assets/ui/pictograms/"+key+".svg")
 return textures[key]
