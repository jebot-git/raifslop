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
 for bait in 3:
  for side in [-1.0,1.0]:
   lure.reset()
   check(lure.work(.05,0,0,bait,false,side)>0.8,"Either sideways twitch attracts every lure species")
   var worked:float=lure.action
   check(lure.work(.05,0,0,bait,false)<worked,"Stationary lure loses attraction")
   check(lure.work(2,0,0,bait,false)==0,"Stationary lure eventually stops attracting")
  lure.reset()
  check(lure.work(.05,.06,0,bait,false)>0,"Slow reeling attracts fish")
  lure.reset();var gentle:float=lure.work(.05,0,0,bait,false,.1)
  check(lure.work(.05,0,0,bait,false)<gentle,"Stopping a gentle twitch cannot increase attraction")
  g.reset();g.location_id="lakeside";g.select_rig(2);g.select_bait(bait)
  g.cast(20,Vector3(0,0,-20),Vector3.ZERO);g.tick(.81,0,0)
  var before:float=g.timer
  g.tick(.05,0,0,false,-1)
  check(g.cast_position.x<0 and g.timer<before,"Left twitch moves lure left and advances bite timer")
  var left_at:Vector3=g.cast_position
  g.tick(.05,0,0,false,1)
  check(g.cast_position.x>left_at.x+.2 and g.cast_position.z>left_at.z,"Right twitch moves lure right and slightly toward the angler")
 lure.reset()
 check(lure.sample_motion(Vector3.ZERO,Basis.IDENTITY,.02)==0,"First tracking sample cannot twitch")
 check(lure.sample_motion(Vector3(.08,0,0),Basis.IDENTITY,.02)>1,"Physical sideways rod motion is sampled")
 check(lure.sample_motion(Vector3(.08,0,0),Basis(Vector3.UP,.7),.02)==0,"Turning view alone cannot twitch")
 check(lure.sample_motion(Vector3(3,0,0),Basis.IDENTITY,.02)==0,"Tracking teleport cannot twitch")
 # A single excursion cannot be milked for repeated twitches while held out.
 lure.reset();lure.sample_motion(Vector3.ZERO,Basis.IDENTITY,.02)
 var speed:float=lure.sample_motion(Vector3(.12,0,0),Basis.IDENTITY,.02)
 var start:=Vector3(0,0,-20)
 var moved:Vector3=lure.move_sideways(start,Vector3.ZERO,speed,.02)
 check(moved.distance_to(start)>.3,"One twitch produces noticeable lure travel")
 for at in [.18,.25,.20,.10]:
  check(lure.sample_motion(Vector3(at,0,0),Basis.IDENTITY,.02)==0,"Further motion away from neutral cannot retrigger")
 check(lure.sample_motion(Vector3(.02,.25,0),Basis.IDENTITY,.02)==0 and not lure.twitch_ready,"Rod must return near neutral in height too")
 check(lure.sample_motion(Vector3(.02,0,0),Basis.IDENTITY,.02)==0,"Return near neutral rearms without twitching")
 check(lure.move_sideways(moved,Vector3.ZERO,0,.2).is_equal_approx(moved),"Rod recovery does not undo lure travel")
 check(lure.sample_motion(Vector3(-.12,0,0),Basis.IDENTITY,.02)<-1,"Fresh opposite twitch works after neutral recovery")
 for yaw in [0.0,PI/2,-.8]:
  for sign in [-1.0,1.0]:
   lure.reset()
   var outward:=Basis(Vector3.UP,yaw)*Vector3(0,0,-20)
   lure.move_sideways(outward,Vector3.ZERO,sign*2,.02)
   var side:Vector3=(outward.normalized().cross(Vector3.UP)*sign-outward.normalized()*.35).normalized()
   check(lure.twitch_heading.dot(side)>.999,"Wake follows signed twitch for every cast bearing")
   lure.work(.02,0,0,1,false,sign*2)
   check(lure.twitch_wake>0,"Twitch wake survives release briefly")
   lure.work(.5,0,0,1,false)
   check(lure.twitch_wake==0,"Directional twitch wake expires")
 lure.reset_motion()
 check(lure.twitch_heading==Vector3.ZERO and lure.twitch_wake==0,"Tracking reset discards stale ripple direction")
 check(lure.sample_motion(Vector3(-1,0,0),Basis.IDENTITY,.02)==0,"Resume starts a fresh motion baseline")
 g.reset();g.location_id="lakeside";g.select_rig(2);g.cast(5);g.tick(.81,0,0);g.tick(5,1,0)
 check(g.state==S.State.READY and g.rig==2,"Empty retrieve rearms lure")
 var b=Board.new();b.connect_player(2,"b".repeat(64),"Lure")
 for species in [2,5]:
  var d={"state":1,"location":"lakeside","rig":2,"bait":2,"species":species,"length":S.SPECIES[species].length,"caught":false}
  b.observe(2,d);d.state=4;b.observe(2,d);d.state=5;d.caught=true
  check(b.observe(2,d)==(species==2),"Server accepts lure pike and rejects bream")
 print("LURE_RESULT ",checks," checks, ",failures);quit(0 if failures.is_empty() else 1)
