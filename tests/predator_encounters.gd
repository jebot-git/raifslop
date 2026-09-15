extends SceneTree
const S=preload("res://scripts/fishing_session.gd")
var failures: Array[String]=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
 if not ok:failures.append(label);push_error(label)
func eligible(seed_value: int, marine:=false):
 var s=S.new();s.rng.seed=7;s.encounter_rng.seed=seed_value
 s.location_id="blouberg_sunrise_2" if marine else "lakeside"
 s.fish_index=25 if marine else 3;s.distance=14;s.cast_distance=18;s.state=S.State.BITE;s.strike()
 s.phase=0 # Fixture begins during active retrieval, after any species opening run.
 s.next_cue=100;s.next_submerge=100;s.retrieval_time=6;s.retrieved_metres=2
 return s
func run():
 var hit_seed:=-1;var miss_seed:=-1;var hits:=0
 for seed_value in 20000:
  var s=eligible(seed_value);s.tick(.02,1,0)
  if s.is_predator():hits+=1;hit_seed=seed_value
  else:miss_seed=seed_value
 check(hits>=310 and hits<=490,"One-roll population stays close to 2 percent: "+str(hits))
 check(hit_seed>=0 and miss_seed>=0,"Deterministic hit and miss seeds exist")
 for id in S.LOCATION_SPECIES:
  if S.Fly.river(id):continue
  var prey_found:=false
  for prey in S.species_for_location(id,false):prey_found=prey_found or S.predator_for_prey(prey,id)>=0
  check(prey_found,"Predator has locally catchable prey at "+id)
  for bait in 6:
   var pool=S.species_for_bait(bait,id)
   check(S.WELS not in pool and S.BRONZE_WHALER not in pool,"Predators excluded from direct bait catches")
 check(S.predator_for_prey(25,"lakeside")==-1 and S.predator_for_prey(3,"blouberg_sunrise_2")==-1,"No cross-habitat takeovers")
 check(S.predator_for_prey(S.WELS,"lakeside")==-1,"Predators cannot be prey for a chained takeover")
 var idle=eligible(hit_seed)
 for i in 40:idle.tick(.02,0,0)
 check(idle.fish_index==3 and not idle.predator_checked,"Waiting without retrieval cannot trigger a predator")
 var near=eligible(hit_seed);near.distance=near.landing_distance+1
 near.tick(.02,1,0);check(near.fish_index==3,"No takeover at the landing point")
 var fresh=eligible(hit_seed);fresh.retrieval_time=0;fresh.retrieved_metres=0
 fresh.tick(.02,1,0);check(fresh.fish_index==3 and not fresh.predator_checked,"Freshly hooked fish must first be retrieved")
 var miss=eligible(miss_seed);miss.tick(.02,1,0)
 var random_state=miss.encounter_rng.state
 for i in 1000:miss._try_predator(.02,1,miss.distance+.1)
 check(miss.fish_index==3 and miss.encounter_rng.state==random_state,"Waiting or repeated samples never reroll a missed encounter")
 var wrong=eligible(hit_seed);wrong.fish_index=1;wrong.tick(.02,1,0)
 check(wrong.fish_index==1,"Large unsuitable prey cannot trigger takeover")
 # Opening rush: no frozen physics, brief reaction time, inherited danger.
 for marine in [false,true]:
  for start_tension in [.45,.88]:
   var prompt=eligible(hit_seed,marine);prompt.tension=start_tension
   prompt._takeover(S.BRONZE_WHALER if marine else S.WELS)
   check(is_equal_approx(prompt.tension,start_tension),"Takeover preserves existing tension")
   var start_distance:float=prompt.distance
   for i in 100:prompt.tick(.02,1.0 if i<20 else 0.0,0)
   check(prompt.state==S.State.FIGHT and prompt.distance>start_distance+2,"Prompt stop survives opening run and line is drawn out")
  var ignored=eligible(hit_seed,marine);ignored._takeover(S.BRONZE_WHALER if marine else S.WELS)
  for i in 120:
   if ignored.state==S.State.FIGHT:ignored.tick(.02,1,0)
  check(ignored.state==S.State.LOST,"Continued reeling breaks starter line within 2.4 seconds")
 var weak=eligible(hit_seed);weak.tension=.96;weak.danger_side=1;weak.danger_time=.4
 weak._takeover(S.WELS);weak.tick(.08,0,0)
 check(weak.state==S.State.LOST,"Previously overloaded starter line can break despite stopping")
 var strong=eligible(hit_seed);strong.tackle.equipped=3;strong.tension=.96;strong.danger_side=1;strong.danger_time=.4
 strong._takeover(S.WELS);strong.tick(.08,0,0)
 check(strong.state==S.State.FIGHT,"Upgraded line tolerates more inherited strain")
 for marine in [false,true]:
  var times:=[]
  for tier in [0,3]:
   var s=eligible(hit_seed,marine);s.tackle.equipped=tier
   s.stamina=.2;s.failed_counters=2;s.resistance=.4;s.tick(.02,1,0)
   var predator: int=S.BRONZE_WHALER if marine else S.WELS
   check(s.fish_index==predator and s.state==S.State.FIGHT,"A predator replaces the hooked prey without landing it")
   check(s.stamina==1 and s.failed_counters==0 and s.resistance==1,"Predator starts with fresh strength and counter state")
   check(s.journal.is_empty() and s.catches==0 and s.tackle.shekels==0,"Consumed prey is never credited")
   check(absf(s.distance-14)<.1,"Takeover preserves fish position")
   var h=preload("res://scripts/line_haptics.gd").new();h.state=S.State.FIGHT
   check(h.sample(s,.02).get("kind")=="predator","Takeover produces one acknowledgement pulse")
   check(h.sample(s,.02).get("kind", "")!="predator","Takeover pulse does not repeat")
   var elapsed:=0.0;var seen:={};var minimum_stamina:=1.0
   for frame in 54000:
    if s.state!=S.State.FIGHT:break
    if s.cue>=0:s.gesture(s.cue);seen[s.cue]=true
    if s.submerge!=S.Submerge.NONE:seen[2+int(s.submerge)]=true
    if s.is_running():seen[5]=true
    var rate:=0.0 if s.is_running() or s.tension>.7 else 1.0
    if s.tension<.18:rate=.8
    if s.submerge==S.Submerge.PULL:rate=0
    elif s.submerge==S.Submerge.SLACK:rate=1.4 if s.tension>.7 else 1.8
    s.tick(1.0/90,rate,.2);elapsed+=1.0/90
    minimum_stamina=minf(minimum_stamina,s.stamina)
    check(s.distance<=s.cast_distance+18.01,"Predator runs stay inside the supported fight range")
   print("PREDATOR_FIGHT ",S.SPECIES[predator].name," tier=",tier," seconds=",elapsed," state=",s.state," stamina=",minimum_stamina," moves=",seen)
   check(s.state==S.State.LANDED,"Predator can be landed with rod tier "+str(tier))
   check(seen.has(3) and seen.has(4) and seen.has(5) and seen.size()>=5,"Predator uses runs, directional holds, deep pulls and slack rushes")
   check(elapsed>70 and elapsed<450,"Trophy fight lasts longer but remains bounded")
   check(s.journal.size()==1 and s.catches==1,"Only predator is recorded once")
   if not s.journal.is_empty():
    check(s.journal[0].latin==S.SPECIES[predator].latin and s.journal[0].bait_fish_latin==S.SPECIES[25 if marine else 3].latin,"Journal records predator and consumed bait species")
   var earned=s.tackle.shekels;s.tick(10,1,0)
   check(s.tackle.shekels==earned and s.takeover_count==1,"No duplicate reward or chained predator")
   s.reset();check(s.rebaited_from==-1 and not s.predator_checked and s.predator_run_time==0,"Release clears takeover state for next cast")
   times.append(elapsed)
  check(times[1]<times[0],"Upgraded tackle shortens predator fight")
 print("PREDATOR_ENCOUNTERS_RESULT ",failures," sampled_hits=",hits)
 quit(0 if failures.is_empty() else 1)
