extends SceneTree
const S=preload("res://scripts/fishing_session.gd")
const P=preload("res://scripts/fish_fight_profiles.gd")
var failures:Array=[]
func check(ok:bool,label:String):
 if not ok:failures.append(label);push_error(label)
func _initialize():
 var signatures:={}
 for index in S.SPECIES.size():
  if S.SPECIES[index].get("predator",false):continue
  var p=P.profile(index)
  var signature=JSON.stringify(p)+str(P.tempo(index))
  check(not signatures.has(signature),"Individual species has distinct cadence: "+str(index))
  signatures[signature]=true
  check((2.0+float(S.SPECIES[index].get("power",1))*.6)*float(p.hold)<S.COUNTER_WINDOW-1.0,"Directional holds leave reaction time")
  for seed_value in [11,28,93]:
   var s=S.new();s.predator_encounters_enabled=false;s.rng.seed=seed_value
   s.fish_index=index;s.state=S.State.BITE;s.cast_distance=22;s.distance=22;s.strike()
   var seconds:=0.0;var counters:=0;var dives:=0;var runs:=0
   var prior_cue:=-1;var prior_dive:=0;var prior_run:=false
   var fps:=30 if seed_value==11 else 90
   for frame in fps*400:
    if s.state!=S.State.FIGHT:break
    if s.cue>=0:
     if prior_cue!=s.cue:counters+=1
     s.gesture(s.cue)
    if s.submerge!=S.Submerge.NONE and prior_dive==0:dives+=1
    if s.is_running() and not prior_run:runs+=1
    prior_cue=s.cue;prior_dive=s.submerge;prior_run=s.is_running()
    var rate:=0.0 if s.is_running() or s.tension>.7 else 1.0
    if s.tension<.18:rate=.8
    if s.submerge==S.Submerge.PULL:rate=0
    elif s.submerge==S.Submerge.SLACK:rate=1.4 if s.tension>.7 else 1.8
    s.tick(1.0/fps,rate,.2);seconds+=1.0/fps
   check(s.state==S.State.LANDED,"Correct play lands %s seed %d: %s" % [S.SPECIES[index].name,seed_value,s.message])
   check(counters>0,"Fish expresses directional pattern before landing")
   if P.SPECIES[index][0] in ["runner","cruiser","ambush"]:
    check(runs>0,"Run-oriented species actually runs during correct play: "+str(index))
   print("PATTERN ",index," seed=",seed_value," seconds=",snappedf(seconds,.1)," counters=",counters," dives=",dives," runs=",runs)
 # Family tendencies are stronger than the per-catch timing variation.
 check(P.profile(4).dives.count(1)>P.profile(4).dives.count(2),"Tench favors bottom pulls")
 check(P.profile(10).dives.count(2)>P.profile(10).dives.count(1),"Rainbow trout favors inward rushes")
 check(P.profile(24).run>P.profile(21).run and P.profile(24).speed>P.profile(21).speed,"Yellowtail runs longer and faster than reef fish")
 check(S.PREDATOR_SEQUENCES[S.WELS].count(3)>S.PREDATOR_SEQUENCES[S.BRONZE_WHALER].count(3),"Catfish favors deep pulls over shark")
 check(S.PREDATOR_SEQUENCES[S.BRONZE_WHALER].count(5)>S.PREDATOR_SEQUENCES[S.WELS].count(5),"Shark favors sustained runs over catfish")
 print("SPECIES_FIGHT_PATTERNS_RESULT ",failures)
 quit(0 if failures.is_empty() else 1)
