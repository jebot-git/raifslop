extends SceneTree
const S=preload("res://scripts/fishing_session.gd")
const Board=preload("res://scripts/network/leaderboard.gd")
var failures:Array=[]
var checks:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize():
 var g=S.new();g.rng.seed=5711
 for location in S.Feeder.POOLS:
  g.reset();g.location_id=location
  check(g.select_rig(S.Rig.FEEDER),"Feeder supported: "+location)
  check(not g.is_fly_fishing(),"Feeder does not strip or drift: "+location)
  g.prepare_population()
  for bait in 4:
   g.select_bait(bait);var preferred:Array=g.current_species()
   check(not preferred.is_empty(),"Every offered bait has local fish")
   for fish in preferred:check(fish in S.species_for_location(location,false),"Bait pool belongs to location")
   for sector in 9:
    for n in 20:check(g.choose_fish(sector) in S.Feeder.POOLS[location],"Feeder never draws a surface or lure-only species")
  g.select_bait(0);g.cast(12);g.tick(.81,0,0)
  check(g.state==S.State.WAITING,"Cast reaches feeder settling")
  var timer:float=g.timer;g.tick(.2,0,0)
  check(g.timer==timer and not g.feeder.deposited,"No bite before feeder settles")
  g.tick(g.feeder.settle_time,0,0)
  check(g.feeder.deposited and g.feeder.drop()>0,"Feeder sinks and deposits groundbait")
  var sector:int=g.population.sector_for(location,g.cast_position)
  var feed:float=g.feeder.attraction(location,sector)
  g.feeder.settle(.1,location,sector)
  check(is_equal_approx(feed,g.feeder.attraction(location,sector)),"One deposit per cast")
  g.timer=100;g.feeder.settle(30,location,sector);g.tick(.1,1,0)
  check(g.feeder.drop()<g.feeder.depth,"Reeling lifts a long-settled cage immediately")
  g.tick(g.feeder.settle_time,0,0)
  g.timer=.01;g.tick(.02,0,0);check(g.state==S.State.BITE,"Settled feeder gets a tip bite")
  check(not g.select_rig(0),"Cannot change rigs during bite")
  g.strike();check(g.state==S.State.FIGHT,"Lift hooks feeder fish")
  g.reset();g.cast(12);g.tick(.81,0,0);g.tick(g.feeder.settle_time,0,0)
  check(g.feeder.attraction(location,sector)>feed,"Accurate recast builds feed")
  g.feeder.tick(200);check(g.feeder.patches.is_empty(),"Feed patches decay")
 for location in ["boulder_run","fish_hoek_beach","simons_town_rocks"]:
  g.reset();g.rig=0;g.location_id=location
  check(not g.select_rig(1),"Unsuitable location refuses feeder: "+location)
 g.location_id="meadow_bend";g.rig=0;g.prepare_population()
 for i in 100:check(g.choose_fish(i%9) in [11,12,9,14,34],"Fly pool excludes feeder-only river fish")
 g.location_id="lakeside";g.rig=1;g.bait=2
 check(g.bait_name(2)=="Maggots" and g.bait_model()==3,"Feeder bait selection maps to correct visual")
 g.reset();g.cast(5);g.tick(.81,0,0);g.tick(5,1,0)
 check(g.state==S.State.READY and g.rig==S.Rig.FEEDER and not g.feeder.deposited,"Empty retrieve rearms the selected feeder")
 var b=Board.new();b.connect_player(2,"a".repeat(64),"Feeder")
 for species in [5,2]:
  var d={"state":1,"location":"lakeside","rig":1,"bait":1,"species":species,"length":S.SPECIES[species].length,"caught":false}
  b.observe(2,d);d.state=4;b.observe(2,d);d.state=5;d.caught=true
  check(b.observe(2,d)==(species==5),"Server accepts bream and rejects feeder pike")
 print("FEEDER_RESULT ",checks," checks, ",failures);quit(0 if failures.is_empty() else 1)
