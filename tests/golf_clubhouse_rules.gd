extends SceneTree
const Rules=preload("res://addons/golfminus/scripts/golf/course_session.gd")
const H=preload("res://addons/golfminus/scripts/golf/handicap.gd")
const Records=preload("res://addons/golfminus/scripts/golf/server_records.gd")
var failures:=0
var checks:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(label)
	else:print("PASS ",label)
func _initialize()->void:
	var r=Rules.new()
	check(r.command("a","Alice","join",{"course":"spyglass"},0),"Solo joins independently")
	check(r.command("b","Bob","join",{"course":"spyglass"},0),"Other visitor has separate solo round")
	check(r.view("a").id!=r.view("b").id,"Solo rounds do not share turns")
	r.tick(100000)
	check(r.view("a").hole==0 and r.view("a").deadline==0,"Solo absence has no deadline or forfeit")
	r.command("a","","retire",{},0);r.command("b","","retire",{},0)
	r.command("a","Alice","join",{"course":"spyglass","mode":"competition"},0)
	check(not r.command("a","","start",{},0),"Competition needs two players")
	r.command("b","Bob","join",{"course":"spyglass","mode":"competition"},0)
	check(not r.view("a").started and r.view("a").deadline==0,"Clubhouse lobby has no timer")
	check(not r.command("b","","start",{},0),"Only organiser starts competition")
	check(r.command("a","","start",{},10),"Organiser starts group")
	check(not r.command("c","Late","join",{"course":"spyglass","mode":"competition"},11),"No late enrollment into ongoing group")
	var m:Dictionary=r.membership("a");var key:String=m.game.turn
	var cap:int=H.cap("spyglass",0,m.game.members[key].handicap)
	r.tick(310)
	check(r.view(key).scores==[cap],"Timeout records net double bogey instead of negative score")
	check(r.view(key).hole==0,"Group stays on hole until all finish")
	r.tick(610)
	check(r.view(key).hole==1,"Group advances together after both caps")
	check(H.cap("spyglass",0,0)==H.par("spyglass",0)+2,"Scratch maximum is double bogey")
	var allocation:=0
	for i in 18:allocation+=H.strokes("spyglass",i,23)
	check(allocation==23,"Handicap strokes allocated exactly across 18 holes")
	var records:Dictionary={"a":{"name":"Alice"}}
	var scores:Array=[]
	for i in 18:scores.append(H.par("spyglass",i)+1)
	check(Records.finish(records,"a","spyglass",scores),"Completed scores persist")
	check(Records.valid(records.a.golf),"History passes shared persistence validation")
	check(H.index(records.a.golf)==16,"Handicap derives from saved player scores")
	check(H.index({})==54,"New players receive explicit provisional handicap")
	print("CLUBHOUSE_RULES %d/%d"%[checks-failures,checks]);quit(1 if failures else 0)
