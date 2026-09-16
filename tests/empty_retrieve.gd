extends SceneTree
const S=preload("res://scripts/fishing_session.gd")
var failures:Array=[]
func check(ok:bool,label:String)->void:
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func _initialize()->void:
 for location in ["lakeside","meadow_bend","boulder_run"]:
  var g=S.new();g.location_id=location;g.select_bait(1)
  var anchor:=Vector3(4,-.3,1)
  g.landing_distance=3;g.cast(12,anchor+Vector3.FORWARD*12,anchor);g.tick(.8,0,0)
  g.timer=100
  var before:Vector3=g.fly.start+g.fly.offset if g.is_fly_fishing() else g.cast_position
  g.tick(.1,1,0)
  var after:Vector3=g.fly.start+g.fly.offset if g.is_fly_fishing() else g.cast_position
  check(after.distance_to(anchor)<before.distance_to(anchor),"Empty retrieve visibly brings bait toward the angler: "+location)
  for i in 500:
   g.tick(.02,2,0)
   if g.state==S.State.READY:break
  check(g.state==S.State.READY and g.bait==1 and g.journal.is_empty() and g.catches==0,"Full empty retrieve rearms selected bait without awarding fish: "+location)
  g.cast(12,anchor+Vector3.FORWARD*12,anchor)
  check(g.state==S.State.CASTING,"Rearmed tackle accepts the next cast: "+location)
 print("EMPTY_RETRIEVE_RESULT ",failures);quit(0 if failures.is_empty() else 1)
