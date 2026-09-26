extends RefCounted
## Shared fishing categories and per-course stats, with retry-safe absolute totals.
const Courses=preload("res://addons/golfminus/scripts/golf/catalog.gd")
const MAX_SCORE=2147483647 # EOS IngestAmount is signed int32; Meta accepts int64.
const START_TIME=1790330760 # v1 begins 2026-09-25 10:06 UTC; EOS portal requires a start.
static func boards()->Dictionary:
 var result:Dictionary={
  "heaviest":{"stat":"ubs_v1_heaviest_g","board":"ubs_v1_heaviest_g","meta":"ubs_v1_heaviest_g","aggregation":"MAX","scale":1000},
  "longest":{"stat":"ubs_v1_longest_mm","board":"ubs_v1_longest_mm","meta":"ubs_v1_longest_mm","aggregation":"MAX","scale":10}}
 for key in ["catches","earned","exceptional"]:
  var name:String="ubs_v2_"+key
  result[key]={"stat":name,"board":name,"meta":name,"aggregation":"MAX","scale":1,"counter":true}
 for course in Courses.ALL:
  var name:String="ubs_v1_golf_"+course
  result["golf/"+course]={"stat":name,"board":name,"meta":name,"aggregation":"MIN","scale":1}
  for field in ["rounds","forfeits","last","handicap"]:
   var stat:String="ubs_v2_golf_%s_%s"%[course,field]
   result["golf_%s/%s"%[field,course]]={"stat":stat,"board":stat,"meta":stat,"aggregation":"MAX" if field in ["rounds","forfeits"] else "LATEST","scale":10 if field=="handicap" else 1,"offset":1 if field=="handicap" else 0,"counter":field in ["rounds","forfeits"]}
 return result
static func valid_score(value:Variant)->bool:
 return (value is int or value is float) and is_finite(float(value)) and value>=1 and value<=MAX_SCORE and value==int(value)
static func encode(key:String,value:float)->int:
 var definition:Dictionary=boards().get(key,{})
 if definition.is_empty() or not is_finite(value) or value<0 or (value==0 and not definition.has("offset")):return 0
 var scaled:float=value*definition.scale+definition.get("offset",0)
 if scaled>MAX_SCORE:return 0
 return roundi(scaled)
static func better(key:String,value:int,previous:int)->bool:
 if boards()[key].aggregation=="LATEST":return value!=previous
 return previous==0 or (value<previous if boards()[key].aggregation=="MIN" else value>previous)
static func aggregation_code(value:String)->int:
 return {"MIN":0,"MAX":1,"SUM":2,"LATEST":3}.get(value,-1)
static func decode(key:String,value:int)->float:
 var definition:Dictionary=boards()[key]
 return float(value-definition.get("offset",0))/definition.scale
