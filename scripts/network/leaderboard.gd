extends RefCounted
## Host-owned records. No client journal import, balances or supplied rewards.
const Fish=preload("res://scripts/fishing_session.gd")
const Tackle=preload("res://scripts/tackle.gd")
const CATEGORIES=["catches","earned","heaviest","longest","exceptional"]
var records:Dictionary={}
var peers:Dictionary={}
var attempts:Dictionary={}
var path:=""
var error:=""
var dirty:=false
static func valid_token(token:String)->bool:
 if token.length()!=64:return false
 for c in token:
  if c not in "0123456789abcdef":return false
 return true
func start(file_path:String)->void:
 records.clear();peers.clear();attempts.clear();path=file_path;dirty=false;error=""
 if not FileAccess.file_exists(path):return
 var file:=FileAccess.open(path,FileAccess.READ)
 if file==null or file.get_length()>16_000_000:error="Leaderboard could not be read";return
 var parser:=JSON.new()
 if parser.parse(file.get_as_text())!=OK:error="Leaderboard file is invalid";return
 var data=parser.data
 if not data is Dictionary or data.get("version")!=1 or not data.get("players") is Dictionary:
  error="Leaderboard file is invalid";return
 for key in data.players:
  var row=data.players[key]
  if key is String and valid_token(key) and valid_row(row):records[key]=row
static func valid_row(row:Variant)->bool:
 if not row is Dictionary or not row.get("name") is String or row.name.length()>32:return false
 if not preload("res://addons/golfminus/scripts/golf/server_records.gd").valid(row.get("golf",{})):return false
 for field in CATEGORIES:
  var value=row.get(field)
  if not (value is float or value is int) or not is_finite(value) or value<0 or value>1e12:return false
 for field in ["biggest","longest_fish","noteworthy"]:
  if not valid_fish(row.get(field)):return false
 return true
static func valid_fish(fish:Variant)->bool:
 if not fish is Dictionary:return false
 if fish.is_empty():return true
 if not fish.get("name") is String or fish.name.length()>64:return false
 if not fish.get("location") is String or not Fish.LOCATION_SPECIES.has(fish.location):return false
 for key in ["length","weight","ratio","species"]:
  var value=fish.get(key)
  if not (value is int or value is float) or not is_finite(value) or value<0 or value>10000:return false
 return fish.species==int(fish.species) and fish.species<Fish.SPECIES.size() and fish.ratio>=.8499 and fish.ratio<=1.1501
func connect_player(peer:int,token:String,player_name:String)->void:
 var key:=token.sha256_text()
 peers[peer]=key;attempts.erase(peer)
 if not records.has(key):
  records[key]={"name":player_name,"catches":0,"earned":0,"heaviest":0.0,"longest":0.0,"exceptional":0,"biggest":{},"longest_fish":{},"noteworthy":{}}
 records[key].name=player_name;dirty=true
func disconnect_player(peer:int)->void:
 peers.erase(peer);attempts.erase(peer)
func observe(peer:int,data:Dictionary)->bool:
 if not peers.has(peer):return false
 var state:int=data.state
 if state==Fish.State.CASTING:
  if not attempts.has(peer) or attempts[peer].get("phase")!=state:
   attempts[peer]={"phase":state,"location":data.location,"rig":data.get("rig",0),"bait":data.get("bait",0),"fought":false}
  return false
 if not attempts.has(peer):return false
 var attempt:Dictionary=attempts[peer]
 if data.location!=attempt.location or data.get("rig",0)!=attempt.rig or data.get("bait",0)!=attempt.bait or state in [Fish.State.READY,Fish.State.LOST]:attempts.erase(peer);return false
 if state==Fish.State.FIGHT:
  attempt.fought=true;attempt.species=data.species;attempt.phase=state;return false
 if state!=Fish.State.LANDED:return false
 # Consume once even if the landing payload is invalid. Repeated reliable poses,
 # reconnects while holding fish and client-side journal replays cannot add catches.
 attempts.erase(peer)
 if not attempt.fought or data.species!=attempt.species or not data.caught:return false
 var index:int=data.species
 if index not in Fish.species_for_location(data.location):return false
 if attempt.rig==0 and Fish.Fly.river(data.location) and index not in Fish.Fly.preferred(attempt.bait,data.location) and index not in Fish.PREDATOR_LOCATIONS.get(data.location,[]):return false
 if attempt.rig==1 and (not Fish.Feeder.supported(data.location) or index not in Fish.Feeder.POOLS[data.location] and index not in Fish.PREDATOR_LOCATIONS.get(data.location,[])):return false
 if attempt.rig==2 and (not Fish.Lure.supported(data.location) or index not in Fish.Lure.POOLS[data.location] and index not in Fish.PREDATOR_LOCATIONS.get(data.location,[])):return false
 var species:Dictionary=Fish.SPECIES[index]
 var ratio:float=float(data.length)/float(species.length)
 if not is_finite(ratio) or ratio<.8499 or ratio>1.1501:return false
 var fish:Dictionary={"name":species.name,"species":index,"length":data.length,"weight":float(species.weight)*pow(ratio,3),"location":data.location,"ratio":ratio}
 var row:Dictionary=records[peers[peer]]
 row.catches+=1;row.earned+=Tackle.reward(species,float(data.length))
 if fish.weight>row.heaviest:row.heaviest=fish.weight;row.biggest=fish.duplicate()
 if fish.length>row.longest:row.longest=fish.length;row.longest_fish=fish.duplicate()
 # Upper end of the actual 0.85–1.15 size distribution, or a rare predator.
 if ratio>=1.12 or int(species.rarity)>=4:
  row.exceptional+=1
  if row.noteworthy.is_empty() or ratio>row.noteworthy.ratio:row.noteworthy=fish.duplicate()
 dirty=true;return true
func snapshot()->Dictionary:
 var result:Dictionary={"players":records.size(),"categories":{}}
 for category in CATEGORIES:
  var rows:Array=records.values().duplicate(true)
  rows.sort_custom(func(a,b):return a.name.naturalnocasecmp_to(b.name)<0 if a[category]==b[category] else a[category]>b[category])
  result.categories[category]=rows.slice(0,50)
 return result
func save()->Error:
 if not dirty or path.is_empty():return OK
 # A damaged file remains available for recovery, rather than being overwritten.
 if not error.is_empty():return ERR_FILE_CORRUPT
 var result:=DirAccess.make_dir_recursive_absolute(path.get_base_dir())
 if result!=OK:return result
 var file:=FileAccess.open(path+".tmp",FileAccess.WRITE)
 if file==null:return FileAccess.get_open_error()
 file.store_string(JSON.stringify({"version":1,"players":records}));file.flush()
 result=file.get_error();file.close()
 if result==OK:result=DirAccess.rename_absolute(path+".tmp",path)
 if result==OK:dirty=false
 return result
