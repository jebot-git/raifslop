extends SceneTree
const S=preload("res://scripts/fishing_session.gd")
const H=preload("res://scripts/line_haptics.gd")
var failures: Array=[]
func check(ok: bool,label: String) -> void:
 print("PASS " if ok else "FAIL ",label)
 if not ok: failures.append(label)
func fight():
 var s=S.new();s.state=S.State.BITE;s.strike();s.distance=100;s.next_cue=100;s.next_submerge=100
 return s
func dive(kind: int):
 var s=fight();s.submerge=kind;s.submerge_time=S.SUBMERGE_DURATION;s.tension=.5
 return s
func _initialize() -> void:
 for fps in [30,72,90]:
  var dt:float=1.0/fps
  for kind in [S.Submerge.PULL,S.Submerge.SLACK]:
   var correct=dive(kind);var wrong=dive(kind);var normal=dive(kind)
   var rate:=0.0 if kind==S.Submerge.PULL else 1.8
   for i in fps:
    correct.tick(dt,rate,0);wrong.tick(dt,1.0 if kind==S.Submerge.PULL else 0.0,0);normal.tick(dt,1.0,0)
   check(correct.effective_counter() and not wrong.effective_counter(),"Submerge recognises reel response: %d / %d FPS" % [kind,fps])
   check(correct.tension<.5 and wrong.tension>.7 if kind==S.Submerge.PULL else correct.tension>.55 and wrong.tension<.25 and normal.tension<.5,"Stop / fast reel reverses rapid tension change: %d / %d FPS" % [kind,fps])
   check(correct.cue<0 and not correct.is_running(),"Submerge excludes conflicting directional cue and run")
 var s=fight();s.next_submerge=0;s.counter_rest=.01;s.next_cue=.01;s.tension=.5
 s.tick(.02,.6,0)
 check(s.submerge==S.Submerge.PULL and s.cue<0,"Dive gets a turn after successful counter recovery")
 var tension:float=s.tension
 s.tick(.2,0,0)
 check(not s.submerge_active() and absf(s.tension-tension)<.04,"Dive has a warning before rapid load starts")
 s.submerge_time=.01;s.tick(.02,0,0)
 check(s.submerge==S.Submerge.NONE and s.next_cue>=1.9,"Resurfacing gives time before next counter")
 s.next_submerge=0;s.tick(.02,.6,0)
 check(s.submerge==S.Submerge.SLACK,"Submerging alternates deep pull and rush toward player")
 s.lose("test");check(s.submerge==S.Submerge.NONE and not s.effective_counter(),"Loss clears submerged response")
 s.reset();check(s.submerge_time==0 and s.reel_rate==0,"Reset clears fight input")
 s=dive(S.Submerge.SLACK);s.tick(.1,S.FAST_REEL_RATE,0)
 check(s.tension>.5 and s.effective_counter(),"Minimum accepted fast winding actually recovers slack")
 for kind in [S.Submerge.PULL,S.Submerge.SLACK]:
  for initial in [.25,.5,.75]:
   s=dive(kind);s.tension=initial
   for i in 300:
    if s.submerge==S.Submerge.NONE: break
    var rate:=0.0 if kind==S.Submerge.PULL else 1.4 if s.tension>.7 else 1.8
    s.tick(.02,rate,0)
   check(s.state==S.State.FIGHT and s.tension>S.SLACK_LIMIT and s.tension<S.STRAIN_LIMIT,"Correct play survives complete submerging move at tension "+str(initial))
 s=dive(S.Submerge.PULL);s.stamina=.1;s.distance=s.landing_distance;s.tick(.02,0,0)
 check(s.state==S.State.FIGHT,"Landing still requires active final retrieval")
 s.tick(.02,1,0)
 check(s.state==S.State.LANDED and s.submerge==S.Submerge.NONE,"Landing clears submerged state")
 var h=H.new();s=fight();h.sample(s,.01);s.cue=0;s.cue_time=6
 var onset:Dictionary=h.sample(s,.01)
 s.gesture(0);s.tick(.02,.6,0)
 var strong:Dictionary=h.sample(s,.02)
 check(strong.get("strength",0)>=.78 and strong.strength>onset.get("strength",0)*5,"Correct counter is much stronger than escape announcement")
 check(h.sample(s,.08).get("kind")=="counter","Correct hold keeps pulsing")
 s.gesture(1);s.tick(.02,.6,0)
 check(h.sample(s,.02).get("strength",1)==0,"Wrong counter immediately cancels strong rumble")
 s.tension=.95
 check(h.sample(s,1).is_empty(),"Uncountered escape stays quiet even at high tension")
 for kind in [S.Submerge.PULL,S.Submerge.SLACK]:
  s=dive(kind);h=H.new();h.sample(s,.01);s.tick(.02,0 if kind==S.Submerge.PULL else 1.8,0)
  check(h.sample(s,.1).get("kind")=="counter","Correct submerge response gets strong rod feedback")
 h=H.new();s=fight();var slow:=0;var fast:=0
 for i in 90:
  if not h.sample_reel(s,.5,1.0/90).is_empty(): slow+=1
 h.pause()
 for i in 90:
  if not h.sample_reel(s,1.8,1.0/90).is_empty(): fast+=1
 check(slow>=5 and fast>slow and fast<=25,"Left-hand detents follow actual crank speed with bounded frequency")
 check(h.sample_reel(s,0,.1).is_empty(),"Stopped reel gives no off-hand rumble")
 s.state=S.State.READY
 check(h.sample_reel(s,2,.1).is_empty(),"Reel haptics stay off outside a fight")
 print("FIGHT_MECHANICS_RESULT ",failures)
 quit(0 if failures.is_empty() else 1)
