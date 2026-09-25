extends SceneTree
const Pages=preload("res://scripts/network/rankings.gd")
class Session extends Node:
 var leaderboard=preload("res://scripts/network/leaderboard.gd").new()
 var rankings=Pages.new()
 var root_game:Node
 var active:=false
 signal changed
var failures:Array=[]
func check(ok:bool,label:String)->void:
 if not ok:failures.append(label);push_error(label)
func _initialize()->void:run.call_deferred()
func run()->void:
 var net=Session.new();root.add_child(net);net.set_process(false)
 net.add_child(net.rankings);net.rankings.setup(net)
 for i in 63:
  net.leaderboard.connect_player(i+1,"%064x"%i,"Angler %02d"%i)
  var row:Dictionary=net.leaderboard.records.values()[i];row.catches=100-i
  var scores:Array=[];scores.resize(18);scores.fill(i+1)
  Pages.Golf.finish(net.leaderboard.records,net.leaderboard.peers[i+1],"spyglass",scores)
 var names:Array=[]
 for p in 5:
  var data:Dictionary=net.rankings.make_page("fishing","catches",p)
  check(Pages.valid_page(data) and data.rows.size()==10 and data.total==50 and data.players==63,"Bounded fishing page %d"%p)
  for row in data.rows:names.append(row.name)
 check(names.size()==50 and names[0]=="Angler 00" and names[49]=="Angler 49","Pages preserve sorted rank without overlaps")
 var golf:Dictionary=net.rankings.make_page("golf","spyglass",1)
 check(Pages.valid_page(golf) and golf.rows[0].best==198 and not str(golf).contains("history"),"Golf page excludes score history and other courses")
 for bad in [-1,5,999]:check(net.rankings.make_page("fishing","catches",bad).is_empty(),"Reject out-of-range page")
 check(not Pages.valid_query("fishing","spyglass",0) and not Pages.valid_query("golf","catches",0),"Reject wrong category/course")
 net.rankings.serial=3
 net.rankings._receive(2,golf)
 check(net.rankings.view.is_empty(),"Stale response cannot replace newer selection")
 net.rankings._receive(3,golf)
 check(net.rankings.view==golf,"Current response accepted")
 var bad:Dictionary=golf.duplicate(true);bad.rows.append(bad.rows[0])
 check(not Pages.valid_page(bad),"Oversized page rejected")
 net.leaderboard.records.clear()
 check(Pages.valid_page(net.rankings.make_page("fishing","earned",0)),"Empty standings remain valid")
 net.rankings.reset();check(net.rankings.view.is_empty(),"Leaving clears response cache")
 # Real panel visibility controls request generation, including inherited hiding.
 net.root_game=Node.new();root.add_child(net.root_game);net.active=true
 var parent:=Control.new();root.add_child(parent);parent.hide()
 var menu=preload("res://scripts/network/leaderboard_menu.gd").new();menu.session=net;parent.add_child(menu)
 var serial:int=net.rankings.serial
 menu.poll();check(net.rankings.serial==serial,"Hidden menu requests no rankings")
 parent.show();menu.poll();check(net.rankings.serial>serial,"Visible menu requests its page")
 parent.hide();serial=net.rankings.serial;menu._process(3)
 check(net.rankings.serial==serial,"Closing menu stops polling")
 parent.free();net.root_game.free();net.active=false;net.free()
 await process_frame
 print("RANKING_PAGES_RESULT ",failures);quit(0 if failures.is_empty() else 1)
