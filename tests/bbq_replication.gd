extends SceneTree
const R=preload("res://scripts/bbq/replication.gd")
var failures:Array=[]
func check(ok:bool,label:String)->void:
 if not ok:failures.append(label);push_error(label)
func _initialize()->void:
 var model=R.Model.new();var location:="lakeside"
 var update:=R.build({},location,{},0)
 var receiver:=R.apply({},update.data)
 var sender:Dictionary=update.baseline
 check(not receiver.is_empty() and receiver.state.is_empty(),"Initial empty station baseline")
 check(R.build(sender,location,{},1).is_empty(),"No repeated empty snapshots")
 model.start(location)
 update=R.build(sender,location,model.stations[location],model.clock);sender=update.baseline
 receiver=R.apply(receiver,update.data)
 check(receiver.state.items.size()==10 and update.data.base==0,"Creation supplies complete late-join state")
 var full_bytes:=var_to_bytes(update.data).size()
 model.apply(location,2,1,"grab",6)
 update=R.build(sender,location,model.stations[location],model.clock);sender=update.baseline
 check(update.data.items.size()==1 and update.data.items[0].id==6,"Ownership change sends only affected item")
 check(var_to_bytes(update.data).size()<full_bytes/3,"Single-item delta is substantially smaller")
 receiver=R.apply(receiver,update.data)
 check(receiver.state.items[6].owner==2,"Delta applies ownership")
 check(R.apply(receiver,update.data).is_empty(),"Duplicate rejected")
 var food:Dictionary=model.stations[location].items[0]
 model.place_food(location,food,Transform3D(Basis.IDENTITY,R.Sites.grill(1)))
 model.stations[location].revision+=1
 update=R.build(sender,location,model.stations[location],model.clock);sender=update.baseline
 receiver=R.apply(receiver,update.data)
 model.tick(4,[location])
 check(R.build(sender,location,model.stations[location],model.clock).is_empty(),"Cooking needs no quarter-second snapshots")
 var predicted:Dictionary=receiver.state.duplicate(true);R.cook(predicted,4)
 check(is_equal_approx(predicted.items[0].cook[0],food.cook[0]),"Cooking anchor extrapolates server result")
 model.tick(1,[location])
 update=R.build(sender,location,model.stations[location],model.clock);sender=update.baseline
 check(update.data.items.size()==1,"Five-second anchor refresh includes cooking item only")
 receiver=R.apply(receiver,update.data)
 check(is_equal_approx(receiver.state.items[0].cook[0],food.cook[0]),"Fresh anchor corrects cooking time")
 model.apply(location,2,1,"cooler",-1)
 update=R.build(sender,location,model.stations[location],model.clock);sender=update.baseline
 check(update.data.items.is_empty(),"Cooler change sends no item array payload")
 var gap:Dictionary=receiver.duplicate(true);gap.seq-=1
 check(R.apply(gap,update.data).is_empty(),"Missing baseline requires full resync")
 receiver=R.apply(receiver,update.data)
 sender.location="" # The service invalidates location for requested resync.
 update=R.build(sender,location,model.stations[location],model.clock);sender=update.baseline
 receiver=R.apply(gap,update.data)
 check(not receiver.is_empty() and update.data.base==0,"Full state recovers missing baseline")
 var malformed:Dictionary=update.data.duplicate(true);malformed.items[1].id=0
 check(not R.valid(malformed),"Duplicate item IDs rejected")
 malformed=update.data.duplicate(true);malformed.items[0].cook[0]=NAN
 check(not R.valid(malformed),"Nonfinite cooking anchor rejected")
 model.release_peer(2)
 update=R.build(sender,location,model.stations[location],model.clock);sender=update.baseline
 receiver=R.apply(receiver,update.data)
 check(receiver.state.items[6].owner==0,"Disconnect ownership release replicated")
 model.tick(181,[])
 update=R.build(sender,location,{},model.clock);sender=update.baseline
 receiver=R.apply(receiver,update.data)
 check(receiver.state.is_empty() and R.build(sender,location,{},model.clock+1).is_empty(),"Expiry sends one tombstone")
 sender.location="";model.start(location)
 update=R.build(sender,location,model.stations[location],model.clock)
 check(not R.apply(receiver,update.data).is_empty(),"Return from unsupported location preserves monotonic sequence")
 print("BBQ_REPLICATION_RESULT full_bytes=",full_bytes," failures=",failures)
 quit(0 if failures.is_empty() else 1)
