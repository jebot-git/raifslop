extends SceneTree
const S=preload("res://scripts/fishing_session.gd")
var failures:Array=[]
func check(ok:bool,label:String)->void:
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func fight(tier:int,mode:String):
 var s=S.new();s.location_id="meadow_bend";s.state=S.State.BITE;s.fish_index=11;s.strike()
 s.tackle.equipped=tier;s.jumps_enabled=false;s.next_cue=100;s.next_submerge=100;s.distance=20;s.tension=.4;s.stamina=1;s.phase=0;s.cue=-1
 if mode=="rush":s.submerge=S.Submerge.SLACK;s.submerge_time=2
 if mode=="dive":s.submerge=S.Submerge.PULL;s.submerge_time=2
 if mode=="final":s.stamina=.25
 if mode=="jump":s.jump_time=2
 return s
func _initialize()->void:
 for tier in 4:
  for mode in ["healthy","rush","final","dive","jump"]:
   var reel=fight(tier,mode);var strip=fight(tier,mode)
   reel.tick(.1,1,0,true);strip.tick(.1,1,0,false)
   var penalized:bool=mode not in ["rush","final"]
   check(reel.fly_reel_penalty==penalized and not strip.fly_reel_penalty,"Fly reel restrictions: %s, rod %d" % [mode,tier])
   check(reel.tension-strip.tension>.045 if penalized else is_equal_approx(reel.tension,strip.tension),"Strict strain applies only to winding outside rush/final retrieval")
  var lake=fight(tier,"healthy");lake.location_id="lakeside";lake.tick(.1,1,0,true)
  check(not lake.fly_reel_penalty,"Ordinary fishing reel is unaffected")
 var held=fight(0,"healthy")
 for i in 400:
  held.stamina=1 # Keep the test fish fighting throughout the strain grace period.
  held.tick(.02,1,0,true)
  if held.state==S.State.LOST:break
 check(held.state==S.State.LOST and "snapped" in held.message,"Persistently winding against a fighting fly fish breaks the line")
 var exhausted=fight(0,"final");exhausted.stamina=0;exhausted.distance=10;exhausted.landing_distance=3
 exhausted.tick(.1,1,0,true)
 check(exhausted.state==S.State.FIGHT,"Fully exhausted fish cannot be caught mid-water")
 exhausted.distance=exhausted.landing_distance;exhausted.tick(.1,0,0,false)
 check(exhausted.state==S.State.FIGHT,"Reaching the shoreline without active retrieval does not award a catch")
 exhausted.tick(.1,1,0,true)
 check(exhausted.state==S.State.LANDED,"Final reel at the shoreline awards the exhausted fish")
 print("FLY_REEL_PENALTY_RESULT ",failures);quit(0 if failures.is_empty() else 1)
