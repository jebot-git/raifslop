extends SceneTree
const S=preload("res://scripts/fishing_session.gd")
const Visual=preload("res://scripts/rod_visual.gd")
var failures:Array=[]
var checks:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);push_error(label)
func fight(tier:int,rig:int,location:String):
 var g=S.new();g.location_id=location;g.select_rig(rig);g.tackle.equipped=tier
 g.predator_encounters_enabled=false;g.fish_index=11;g.rng.seed=451;g.state=S.State.BITE;g.distance=24;g.strike()
 return g
func _initialize():run.call_deferred()
func run():
 var v=Visual.new();root.add_child(v)
 var g=S.new();g.tackle.shekels=1600
 for tier in 4:
  check(g.tackle.purchase_or_equip(tier,true),"Purchase tier "+str(tier))
  var balance:int=g.tackle.shekels
  for mode in 4:
   var rig:int=[0,0,1,2][mode];var location:String="meadow_bend" if mode==1 else "lakeside"
   g.reset();g.location_id=location;g.select_rig(rig)
   check(g.tackle.equipped==tier and g.tackle.shekels==balance,"Rig changes preserve tier and wallet")
   v.equip(tier,mode==1,mode==2,mode==3)
   var name:String=Visual.MODELS[tier]+["","_fly","_feeder","_lure"][mode]
   check(v.model.scene_file_path.ends_with(name+".glb"),"Tier/style selects authored held model: "+name)
   check(v.folded_model.scene_file_path.ends_with(name+"_folded.glb"),"Matching folded tier/style: "+name)
   v.set_folded(true);check(v.folded_model.visible and not v.model.visible and not v.crank.visible,"Stow does not expose expanded tackle")
   v.set_folded(false);check(v.model.visible and v.crank.visible and v.quiver.visible==(mode==2),"Unfold restores selected rig")
   var reference=fight(tier,0,"lakeside");var actual=fight(tier,rig,location)
   reference.tick(.3,.7,.2);actual.tick(.3,.7,.2)
   check(is_equal_approx(reference.stamina,actual.stamina) and is_equal_approx(reference.tension,actual.tension),"Same tier grants same fatigue and durability across styles")
   if tier>0:
    var weak=fight(tier-1,rig,location);weak.tick(.3,.7,.2)
    check(actual.stamina<weak.stamina,"Each upgrade improves fatigue for every style")
 var restored=S.Tackle.new();restored.load_profile()
 check(restored.equipped==3 and restored.owned.size()==4 and restored.shekels==0,"Progression persists once across all styles")
 v.queue_free();await process_frame
 print("RIG_PROGRESSION_RESULT ",checks," checks, ",failures);quit(0 if failures.is_empty() else 1)
