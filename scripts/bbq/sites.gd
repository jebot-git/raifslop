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
}
static func pose(location:String) -> Transform3D:
 var site:Array=SITES.get(location,[Vector3.ZERO,0.0])
 return Transform3D(Basis(Vector3.UP,site[1]),site[0])
static func arrival(location:String,seat:=0) -> Vector3:
 if location=="lake_pier":return Vector3(.15+(seat%4)*.55,.09,1.1+floori(seat/4.0)*.55)
 return pose(location)*Vector3((seat%4-1.5)*.6,.09,1.2+floori(seat/4.0)*.55)
static func grill(slot:int) -> Vector3:
 return Vector3((slot%3-1)*.25,.96,-.19+floori(slot/3.0)*.34)
static func pantry(slot:int) -> Vector3:
 return Vector3(-.93+(slot%2)*.22,.91,-.24+floori(slot/2.0)*.22)
static func plate(slot:int) -> Vector3:
 return Vector3(.81+(slot%2)*.26,.91,-.22+floori(slot/2.0)*.30)
static func home(item:Dictionary) -> Vector3:
 if item.kind=="tongs":return Vector3(-.59,.92,.30+(item.id-6)*.14)
 if item.kind=="drink":return Vector3(1.00,.96,.43+(item.id-8)*.16)
 return pantry(item.id)
