extends SceneTree
const S=preload("res://scripts/fishing_session.gd")
const Board=preload("res://scripts/network/leaderboard.gd")
var failures:Array=[]
var checks:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize():
 check(is_equal_approx(S.PREDATOR_CHANCE,.03),"Exactly one 3% takeover roll")
 check(S.SPECIES.size()==40 and S.SPECIES[38].latin=="Hucho hucho" and S.SPECIES[39].latin=="Carcharias taurus","Appended predator IDs")
 for location in S.LOCATION_SPECIES:
  for predator in [S.HUCHEN,S.RAGGEDTOOTH]:
   check((predator in S.species_for_location(location))==(predator in S.PREDATOR_LOCATIONS[location]),"Guide and encounter distribution agree")
  for prey in S.species_for_location(location,false):
   for predator in S.predators_for_prey(prey,location):
    check(predator in S.PREDATOR_LOCATIONS[location] and prey in S.PREDATOR_PREY[predator],"Takeover requires local eligible prey")
  for predator in S.PREDATOR_PREY:check(S.predators_for_prey(predator,location).is_empty(),"Predators never trigger chained encounters")
 var coast_hits:=0;var selected:={}
 for seed_value in 20000:
  var g=S.new();g.location_id="fish_hoek_beach";g.fish_index=37;g.state=S.State.FIGHT;g.distance=15;g.cast_distance=18;g.tension=.45;g.encounter_rng.seed=seed_value;g.retrieval_time=6;g.retrieved_metres=2;g.phase=0
  g._try_predator(.02,1,15.1)
  if g.is_predator():coast_hits+=1;selected[g.fish_index]=true
  var state=g.encounter_rng.state
  g._try_predator(.02,1,15.1)
  check(g.encounter_rng.state==state,"No second chance after hit or miss")
 check(coast_hits>=480 and coast_hits<=720,"Multiple coastal predators still total 3%, not 6%")
 check(selected.has(S.BRONZE_WHALER) and selected.has(S.RAGGEDTOOTH),"Both eligible coastal predators selected")
 for fixture in [[S.HUCHEN,"meadow_bend",14,0],[S.HUCHEN,"boulder_run",17,2],[S.RAGGEDTOOTH,"secluded_beach",20,0],[S.RAGGEDTOOTH,"fish_hoek_beach",37,2]]:
  for tier in [0,3]:
   var g=S.new();g.location_id=fixture[1];g.rig=fixture[3];g.fish_index=fixture[2];g.distance=14;g.cast_distance=18;g.state=S.State.BITE;g.tackle.equipped=tier;g.strike();g._takeover(fixture[0])
   check(g.fish_index==fixture[0] and g.takeover_count==1,"New predator replaces prey")
   var elapsed:=0.0
   for frame in 54000:
    if g.state!=S.State.FIGHT:break
    if g.cue>=0:g.gesture(g.cue)
    var rate:=0.0 if g.is_running() or g.tension>.7 else 1.0
    if g.tension<.18:rate=.8
    if g.submerge==S.Submerge.PULL:rate=0
    elif g.submerge==S.Submerge.SLACK:rate=1.4 if g.tension>.7 else 1.8
    g.tick(1.0/90,rate,.2);elapsed+=1.0/90
   check(g.state==S.State.LANDED and elapsed<450,"New predator landable with tier "+str(tier))
   check(g.journal.size()==1 and g.catches==1 and g.journal[0].latin==S.SPECIES[fixture[0]].latin,"Only predator rewarded and recorded")
   print("NEW_PREDATOR_FIGHT ",fixture," tier=",tier," seconds=",elapsed," state=",g.state)
 var board=Board.new();board.connect_player(2,"d".repeat(64),"Predator test")
 for fixture in [[38,"meadow_bend",0,true],[38,"meadow_bend",1,true],[38,"boulder_run",2,true],[39,"fish_hoek_beach",2,true],[39,"blouberg_sunrise_2",0,false],[38,"lakeside",0,false],[39,"meadow_bend",0,false]]:
  var d={"state":1,"location":fixture[1],"rig":fixture[2],"bait":0,"species":fixture[0],"length":S.SPECIES[fixture[0]].length,"caught":false}
  board.observe(2,d);d.state=4;board.observe(2,d);d.state=5;d.caught=true
  check(board.observe(2,d)==fixture[3],"Server accepts only appropriate predator habitat/method")
 print("PREDATOR_EXPANSION_RESULT ",checks," checks ",failures," coastal_hits=",coast_hits)
 quit(0 if failures.is_empty() else 1)
