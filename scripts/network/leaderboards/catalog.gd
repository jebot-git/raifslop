extends RefCounted
## Versioned non-expiring boards. Never reinterpret a server-local total as a global total.
const Courses=preload("res://addons/golfminus/scripts/golf/catalog.gd")
const MAX_SCORE=2147483647 # EOS IngestAmount is signed int32; Meta accepts int64.
const START_TIME=1790330760 # v1 begins 2026-09-25 10:06 UTC; EOS portal requires a start.
static func boards()->Dictionary:
 var result:Dictionary={
  "heaviest":{"stat":"ubs_v1_heaviest_g","board":"ubs_v1_heaviest_g","meta":"ubs_v1_heaviest_g","aggregation":"MAX","scale":1000},
  "longest":{"stat":"ubs_v1_longest_mm","board":"ubs_v1_longest_mm","meta":"ubs_v1_longest_mm","aggregation":"MAX","scale":10}}
 for course in Courses.ALL:
  var name:String="ubs_v1_golf_"+course
  result["golf/"+course]={"stat":name,"board":name,"meta":name,"aggregation":"MIN","scale":1}
 return result
static func valid_score(value:Variant)->bool:
 return (value is int or value is float) and is_finite(float(value)) and value>=1 and value<=MAX_SCORE and value==int(value)
static func encode(key:String,value:float)->int:
 var definition:Dictionary=boards().get(key,{})
 if definition.is_empty() or not is_finite(value) or value<=0:return 0
 var scaled:float=value*definition.scale
 if scaled>MAX_SCORE:return 0
 return roundi(scaled)
static func better(key:String,value:int,previous:int)->bool:
 return previous==0 or (value<previous if boards()[key].aggregation=="MIN" else value>previous)
