extends SceneTree
const Board=preload("res://scripts/network/leaderboard.gd")
var failures:Array=[]
var checks:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);push_error(label)
func catch_sequence(b,peer:int,index:int=0,ratio:float=1.14):
 var d={"state":1,"location":"lakeside","species":index,"length":Board.Fish.SPECIES[index].length*ratio,"caught":false}
 b.observe(peer,d);d.state=4;b.observe(peer,d);d.state=5;d.caught=true
 return b.observe(peer,d)
func _initialize():
 var b=Board.new();var path="user://board-unit.json"
 DirAccess.remove_absolute(path);b.start(path)
 var token="a".repeat(64);b.connect_player(2,token,"One")
 check(catch_sequence(b,2),"Observed cast/fight/landing awards catch")
 var d={"state":5,"location":"lakeside","species":0,"length":Board.Fish.SPECIES[0].length*1.14,"caught":true}
 check(not b.observe(2,d),"Duplicate landing rejected")
 check(not catch_sequence(b,2,0,9.0),"Impossible length rejected")
 check(not catch_sequence(b,2,18),"Wrong habitat rejected")
 check(not catch_sequence(b,999),"Unknown peer rejected")
 var record:Dictionary=b.records.values()[0]
 check(record.catches==1 and record.exceptional==1,"Totals are issued only once")
 check(record.earned==Board.Tackle.reward(Board.Fish.SPECIES[0],d.length),"Earnings computed on host")
 check(is_equal_approx(record.heaviest,Board.Fish.SPECIES[0].weight*pow(1.14,3)),"Weight derived from validated length")
 check(b.save()==OK,"Atomic server save")
 b.disconnect_player(2);b.connect_player(3,token,"Renamed")
 check(b.records.size()==1 and b.records.values()[0].catches==1,"Reconnect and rename retain identity")
 check(not b.observe(3,d),"Reconnecting with held catch adds nothing")
 b.save();var restored=Board.new();restored.start(path)
 check(restored.records.size()==1 and restored.records.values()[0].name=="Renamed","Restart restores offline players")
 var view:Dictionary=restored.snapshot()
 check(view.categories.size()==5 and not JSON.stringify(view).contains(token.sha256_text()),"Public rankings contain no identity secrets")
 for i in 60:restored.connect_player(100+i,"%064x"%i,"Angler %02d"%i)
 check(restored.snapshot().categories.catches.size()==50,"Network rankings remain bounded")
 var corrupt:=FileAccess.open(path,FileAccess.WRITE);corrupt.store_string("broken");corrupt.close()
 restored.start(path);restored.connect_player(2,token,"One")
 check(restored.save()==ERR_FILE_CORRUPT and FileAccess.get_file_as_string(path)=="broken","Corrupt store is not overwritten")
 print("LEADERBOARD_RESULT ",checks," checks, ",failures);quit(0 if failures.is_empty() else 1)
