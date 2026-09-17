extends SceneTree
const S=preload("res://scripts/fishing_session.gd")
const Guide=preload("res://scripts/fish_guide.gd")
const Board=preload("res://scripts/network/leaderboard.gd")
var checks:=0
var failures:Array=[]
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize():
 var old=["Perca fluviatilis","Cyprinus carpio","Esox lucius","Rutilus rutilus","Tinca tinca","Abramis brama","Sander lucioperca","Scardinius erythrophthalmus","Carassius carassius","Squalius cephalus","Oncorhynchus mykiss","Salmo trutta","Thymallus thymallus","Barbus barbus","Leuciscus leuciscus","Alburnus alburnus","Gobio gobio","Salvelinus fontinalis","Diplodus capensis","Dichistius capensis","Pachymetopon blochii","Chrysoblephus laticeps","Lithognathus lithognathus","Pomatomus saltatrix","Seriola lalandi","Chelon richardsonii","Silurus glanis","Carcharhinus brachyurus","Argyrosomus japonicus","Rhabdosargus globiceps","Diplodus hottentotus","Trachurus capensis"]
 for i in old.size():check(S.SPECIES[i].latin==old[i],"Existing catch ID preserved: "+str(i))
 check(S.SPECIES.size()==40,"Expanded roster has 40 species")
 check(S.FightProfiles.SPECIES.size()==S.SPECIES.size(),"Every fish has explicit fight profile")
 var seen:Dictionary={};var g=S.new();g.rng.seed=61345
 for location in S.LOCATION_SPECIES:
  for rig in 3:
   if not S.rig_supported(rig,location):continue
   g.reset();g.location_id=location;g.select_rig(rig);g.prepare_population()
   for bait in g.bait_count():
    g.select_bait(bait)
    var preferred:Array=g.current_species()
    check(not preferred.is_empty(),"Every supported method/bait has local targets")
    for fish in preferred:
     check(fish in S.LOCATION_SPECIES[location],"Preferred fish belongs to habitat")
     if fish>=32:
      var key:String=str(fish)+":"+("fly" if g.is_fly_fishing() else str(rig));seen[key]=true
    for n in 200:
     var caught:int=g.choose_fish(n%9)
     check(caught in S.LOCATION_SPECIES[location],"Random choice stays in habitat")
     if rig==1:check(caught in S.Feeder.POOLS[location],"Feeder excludes lure predators")
     elif rig==2:check(caught in S.Lure.POOLS[location],"Lure excludes bottom-only fish")
     elif g.is_fly_fishing():check(caught in preferred,"Fly pool respects dry/nymph choice")
 for key in ["32:0","32:1","33:0","33:1","34:0","34:1","34:2","34:fly","35:0","35:2","36:0","36:2","37:0","37:2"]:check(seen.has(key),"New fish is targetable with intended method "+key)
 check(not seen.has("32:2") and not seen.has("33:2") and not seen.has("35:1"),"No incompatible default rig assignment")
 check(14 in S.Fly.preferred(0,"meadow_bend") and not 14 in S.Fly.preferred(1,"meadow_bend"),"Fly preferences distinguish surface-feeding dace")
 check(17 in S.LOCATION_SPECIES.boulder_run and 17 in S.Fly.preferred(1,"boulder_run"),"Brook trout distribution extends into cold stream")
 var guide=Guide.new();var previous=S.SPECIES[6].duplicate();previous.length=71.0;guide.ingest([previous])
 for i in range(32,38):
  var species:Dictionary=S.SPECIES[i];check(Guide.DESCRIPTIONS.has(species.latin),"New fish has guide description")
  check(preload("res://scripts/fish_guide_icons.gd").contour(species.latin,Vector2.ZERO,1).size()>=20,"New fish has identifiable silhouette")
  check(guide.ingest([species]),"New catch unlocks guide")
  var hints:Dictionary=Guide.discovery_hint(i)
  check(not hints.methods.is_empty() and not hints.waters.is_empty() and not hints.bait.is_empty(),"Guide provides methods, bait and actual waters")
 check(guide.entries[previous.latin].length==71.0,"Expanded guide retains earlier personal best")
 check(guide.ordered_entries().size()==40,"Guide paging includes undiscovered additions")
 guide.free()
 var board=Board.new();board.connect_player(2,"c".repeat(64),"Roster")
 for example in [[32,"lakeside",1,2,true],[33,"gray_pier",1,0,true],[34,"meadow_bend",0,1,true],[35,"meadow_bend",2,2,true],[36,"fish_hoek_beach",2,2,true],[37,"simons_town_rocks",0,2,true],[35,"meadow_bend",1,0,false],[33,"meadow_bend",0,1,false],[36,"lakeside",2,0,false]]:
  var d={"state":1,"location":example[1],"rig":example[2],"bait":example[3],"species":example[0],"length":S.SPECIES[example[0]].length,"caught":false}
  board.observe(2,d);d.state=4;board.observe(2,d);d.state=5;d.caught=true
  check(board.observe(2,d)==example[4],"Server validates new species method/habitat")
 print("ROSTER_RESULT ",checks," checks, ",failures);quit(0 if failures.is_empty() else 1)
