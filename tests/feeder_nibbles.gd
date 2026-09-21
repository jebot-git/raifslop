extends SceneTree
const S=preload("res://scripts/fishing_session.gd")
const Haptics=preload("res://scripts/line_haptics.gd")
var failures:Array=[]
var checks:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);push_error(label)
func waiting(seed_value:int):
 var g=S.new();g.rng.seed=seed_value;g.location_id="lakeside";g.select_rig(S.Rig.FEEDER)
 g.cast(12);g.tick(.81,0,0);g.timer=100;g.tick(g.feeder.settle_time,0,0)
 g.timer=.01;g.tick(.02,0,0)
 return g
func _initialize():
 for seed_value in 20:
  var g=waiting(seed_value)
  var h=Haptics.new()
  var taps:=0;var bites:=0;var strongest_tap:=0.0;var strongest_bend:=0.0
  for frame in 140:
   var event:Dictionary=h.sample(g,.05)
   if event.get("kind")=="nibble":
    taps+=1;strongest_tap=maxf(strongest_tap,event.strength)
    strongest_bend=maxf(strongest_bend,g.feeder.tip_load(false))
    check(g.state==S.State.WAITING,"A nibble never hooks the fish")
    check(h.sample(g,0).is_empty(),"Each nibble vibrates only once")
   elif event.get("kind")=="bite":
    bites+=1
    check(event.strength>strongest_tap*3 and event.duration>.2,"Actual bite has a clearly stronger, longer vibration")
    check(g.feeder.tip_load(true)>strongest_bend*2,"Actual bite makes a bigger tip pull")
    break
   g.tick(.05,0,0)
  check(taps>=2 and taps<=4 and taps==g.feeder.nibble_count,"Every cast has two to four distinct nibble pulses")
  check(bites==1 and g.state==S.State.BITE,"One real bite follows the nibble sequence")
  for i in 50:
   g.tick(.05,0,0)
   check(h.sample(g,.05).is_empty(),"Bite vibration does not repeat during hook window")
  check(g.state==S.State.BITE,"Hook window remains open after 2.5 seconds")
  g.strike();check(g.state==S.State.FIGHT,"A later strike inside the feeder window hooks successfully")
 for action in ["strike","reel"]:
  for delay in [0.0,.4]:
   var g=waiting(91);g.tick(delay,0,0)
   var distance:float=g.distance
   if action=="strike":g.strike()
   else:g.tick(.05,1,0)
   check(g.state==S.State.LOST,"Early "+action+" fails during both a nibble and its quiet gap")
   check(g.distance==distance,"Failed nibble cannot retrieve the feeder before losing the cast")
   g.tick(10,0,0)
   check(g.state==S.State.READY and not g.feeder.nibbling and g.feeder.nibble_count==0,"Failed cast clears all nibble cues for recasting")
 var missed=waiting(7)
 for i in 120:
  if missed.state==S.State.BITE:break
  missed.tick(.05,0,0)
 missed.tick(S.Feeder.HOOK_WINDOW+.01,0,0)
 check(missed.state==S.State.LOST,"The extended bite window still expires")
 var ordinary=S.new();ordinary.cast(12);ordinary.tick(.81,0,0);ordinary.timer=0;ordinary.tick(.01,0,0)
 check(ordinary.state==S.State.BITE and is_equal_approx(ordinary.timer,1.8),"Float bites retain their existing timing")
 print("FEEDER_NIBBLES_RESULT ",checks," checks, ",failures)
 quit(0 if failures.is_empty() else 1)
