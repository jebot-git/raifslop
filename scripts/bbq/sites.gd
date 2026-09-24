extends RefCounted
## Authored gathering anchors, shared by render clients and the headless host.
const SITES := {
 "lakeside": [Vector3(-2.8,0,5.0),0.0],
 "lake_pier": [Vector3(-1.3,0,2.2),PI/2],
 "gray_pier": [Vector3(.6,0,7.7),0.0],
 "bell_park_pier": [Vector3(3.4,0,7.25),0.0],
 "simons_town_rocks": [Vector3(1.5,0,4.5),0.0],
 "blouberg_sunrise_2": [Vector3(-2.0,0,4.5),0.0],
 "secluded_beach": [Vector3(-2.0,0,4.0),0.0],
 "fish_hoek_beach": [Vector3(3.0,0,4.0),0.0],
 "meadow_bend": [Vector3(3.0,.05,2.0),0.0],
 "boulder_run": [Vector3(3.0,.05,2.0),0.0],
 "cedar_creek": [Vector3(3.0,.05,2.0),0.0],
 "glacier_run": [Vector3(3.0,.05,2.0),0.0],
}
static func supported(location:String)->bool:
 return SITES.has(location) or preload("res://addons/golfminus/scripts/golf/host_locations.gd").is_clubhouse(location)
static func pose(location:String) -> Transform3D:
 if preload("res://addons/golfminus/scripts/golf/host_locations.gd").valid(location):return preload("res://addons/golfminus/scripts/golf/host_locations.gd").pose(location)
 var site:Array=SITES.get(location,[Vector3.ZERO,0.0])
 return Transform3D(Basis(Vector3.UP,site[1]),site[0])
static func arrival(location:String,seat:=0) -> Vector3:
 if location=="lake_pier":return Vector3(.15+(seat%4)*.55,.09,1.1+floori(seat/4.0)*.55)
 return pose(location)*Vector3((seat%4-1.5)*.6,.09,1.2+floori(seat/4.0)*.55)
const COOLER_POSITION := Vector3(.66,.48,0)
const COOLER_HANDLE := Vector3(.66,.87,.16)
static func grill(slot:int) -> Vector3:
 return Vector3((slot%3-1)*.19,.947,-.105+floori(slot/3.0)*.21)
static func pantry(slot:int) -> Vector3:
 return Vector3(-.76+(slot%2)*.22,.95,-.18+floori(slot/2.0)*.18)
static func plate(slot:int) -> Vector3:
 return pantry(slot)
static func home(item:Dictionary) -> Vector3:
 if item.kind=="tongs":return Vector3(-.81+(item.id-6)*.32,.915,.22)
 if item.kind=="drink":return COOLER_POSITION+Vector3(-.07+(item.id-8)*.14,.19,0)
 return pantry(item.id)
