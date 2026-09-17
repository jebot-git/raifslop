extends SceneTree
const S=preload("res://scripts/fishing_session.gd")
const Board=preload("res://scripts/network/leaderboard.gd")
var failures:Array=[]
var checks:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize():
 var g=S.new();g.rng.seed=931
 for location in S.Lure.POOLS:
  g.reset();g.location_id=location
  check(g.select_rig(S.Rig.LURE),"Lure supported at "+location)
  check(not g.is_fly_fishing() and not g.is_feeder_fishing(),"Lure mechanics override river defaults")
  g.prepare_population()
  for bait in 3:
   g.select_bait(bait)
   check(not g.current_species().is_empty(),"Every lure has local fish")
   for fish in S.Lure.POOLS[location]:check(fish in S.species_for_location(location,false),"Local lure roster is a subset of habitat roster")
   for sector in 9:
    for n in 20:check(g.choose_fish(sector) in S.Lure.POOLS[location],"Lure cannot select bottom-only species")
   g.cast(20);g.tick(.81,0,0)
   var timer:float=g.timer;g.tick(5,0,0)
   check(g.state==S.State.WAITING and g.timer==timer,"Unworked lure cannot attract bites")
   g.timer=.01;g.tick(.02,.5,.1)
   check(g.state==S.State.BITE,"Worked lure produces a strike")
   check(not g.select_rig(0),"Rig switch blocked during bite")
   g.strike();check(g.state==S.State.FIGHT,"Lift hooks lure fish")
   g.reset()
 check(S.Lure.preferred(0,"lake_pier")!=S.Lure.preferred(1,"lake_pier"),"Lures have distinct preferences")
 for location in S.Feeder.POOLS:
  g.location_id=location;g.select_rig(1)
  check(g.bait_count()>=2,"Feeder retains multiple baits")
  check(S.Feeder.preferred(0,location)!=S.Feeder.preferred(1,location),"Feeder preferences differ")
 var lure=S.Lure.new()
 check(lure.work(.1,.75,0,0,false)>lure.work(.1,2,0,0,false),"Steady spinner retrieve beats excessive speed")
 check(lure.work(.1,0,0,0,false)==0,"Spinner stops working immediately")
 for bait in [1,2]:
  lure.reset();lure.work(.1,.5,0,bait,false)
  check(lure.work(.2,0,0,bait,false)>0,"Worked jig/minnow can be hit on short pause")
  check(lure.work(2,0,0,bait,false)==0,"Pause cannot become unattended bait fishing")
 lure.reset();lure.work(10,.5,0,1,false);var deep:float=lure.depth
 lure.reset();lure.work(10,.5,0,1,true);check(lure.depth<deep,"River retrieve keeps lure shallower")
 g.reset();g.location_id="lakeside";g.select_rig(2);g.cast(5);g.tick(.81,0,0);g.tick(5,1,0)
 check(g.state==S.State.READY and g.rig==2,"Empty retrieve rearms lure")
 var b=Board.new();b.connect_player(2,"b".repeat(64),"Lure")
 for species in [2,5]:
  var d={"state":1,"location":"lakeside","rig":2,"bait":2,"species":species,"length":S.SPECIES[species].length,"caught":false}
  b.observe(2,d);d.state=4;b.observe(2,d);d.state=5;d.caught=true
  check(b.observe(2,d)==(species==2),"Server accepts lure pike and rejects bream")
 print("LURE_RESULT ",checks," checks, ",failures);quit(0 if failures.is_empty() else 1)
