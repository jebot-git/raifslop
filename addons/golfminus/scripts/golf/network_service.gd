extends Node
## Runs beneath Fishing's Network on dedicated servers and every client.
const Rules=preload("res://addons/golfminus/scripts/golf/course_session.gd")
const Records=preload("res://addons/golfminus/scripts/golf/server_records.gd")
var session:Node
var rules=Rules.new()
var view:Dictionary={}
var board:Dictionary={}
var guards:Dictionary={}
var now:=0.0
signal changed
signal result(action:String,accepted:bool)
func setup(value:Node)->void:
	session=value;name="Golf"
	rules.completed.connect(_completed)
	rules.forfeited.connect(_forfeited)
func _completed(key:String,course:String,scores:Array)->void:
	if Records.finish(session.leaderboard.records,key,course,scores,false):session.leaderboard.dirty=true;session.publish_leaderboard()
func _forfeited(key:String,course:String,_hole:int)->void:
	if Records.forfeit(session.leaderboard.records,key,course):session.leaderboard.dirty=true;session.publish_leaderboard()
func reset()->void:
	rules.games.clear();view.clear();board.clear();guards.clear();changed.emit()
func _process(_dt:float)->void:
	now=Time.get_ticks_msec()/1000.0
	if session.active and multiplayer.is_server() and rules.tick(now):publish()
func request(action:String,data:Dictionary={})->void:
	if not session.active:result.emit(action,false);return
	if multiplayer.is_server():_accept(multiplayer.get_unique_id(),action,data)
	else:_command.rpc_id(1,action,data)
@rpc("any_peer","call_remote","reliable",0)
func _command(action:String,data:Dictionary)->void:
	if multiplayer.is_server():_accept(multiplayer.get_remote_sender_id(),action,data)
static func valid_command(action:String,data:Dictionary)->bool:
	match action:
		"join":return data.size() in [1,2] and data.get("course") is String and data.course in Rules.COURSES and data.get("mode","solo") in ["solo","competition"] and data.keys().all(func(k):return k in ["course","mode"])
		"presence":return data.size()==1 and data.get("present") is bool
		"retire","start":return data.is_empty()
		"shot","penalty","settled":
			if not data.get("epoch") is int or data.epoch<0:return false
			if action!="settled":return data.size()==1
			for key in data:
				if key not in ["epoch","holed","hazard"]:return false
				if key!="epoch" and not data[key] is bool:return false
			return true
	return false
func _accept(peer:int,action:String,data:Dictionary)->void:
	if not session.active or not session.leaderboard.peers.has(peer) or not session.players.has(peer):return
	if not valid_command(action,data):
		if peer==multiplayer.get_unique_id():result.emit(action,false)
		else:_reply.rpc_id(peer,action,false)
		return
	var guard:Dictionary=guards.get(peer,{"time":now,"tokens":12.0})
	guard.tokens=minf(12,guard.tokens+maxf(0,now-guard.time)*8);guard.time=now;guards[peer]=guard
	if guard.tokens<1:return
	guard.tokens-=1
	var key:String=session.leaderboard.peers[peer]
	rules.tick(now)
	if action=="join" or action=="start":
		var course:String=data.get("course",rules.view(key).get("course",""))
		var peers:Array=[peer]
		if action=="start":
			var m:Dictionary=rules.membership(key)
			if not m.is_empty():
				for other in session.leaderboard.peers:
					if session.leaderboard.peers[other] in m.game.order and not m.game.members[session.leaderboard.peers[other]].retired and other not in peers:peers.append(other)
				if peers.size()!=m.game.members.values().filter(func(member):return not member.retired).size():peers.append(-1)
		if action=="start" or data.get("mode","solo")=="competition":
			for other in peers:
				var state:Dictionary=session.states.get(other,{})
				var location:String="golf_%s_clubhouse"%course
				var nearby:bool=state.get("feet",Vector3.INF).distance_to(preload("res://addons/golfminus/scripts/golf/host_locations.gd").pose(location).origin)<15 if course in Rules.COURSES else false
				if state.get("location","")!=location or not nearby:
					if peer==multiplayer.get_unique_id():result.emit(action,false)
					else:_reply.rpc_id(peer,action,false)
					return
		rules.stats[key]=session.leaderboard.records.get(key,{}).get("golf",{})
	var accepted:bool=rules.command(key,session.players[peer].name,action,data,now)
	publish()
	if peer==multiplayer.get_unique_id():result.emit(action,accepted)
	else:_reply.rpc_id(peer,action,accepted)
@rpc("authority","call_remote","reliable",0)
func _reply(action:String,accepted:bool)->void:result.emit(action,accepted)
func disconnected(peer:int)->void:
	if session.leaderboard.peers.has(peer):rules.mark_absent(session.leaderboard.peers[peer],now)
	guards.erase(peer);publish.call_deferred()
func publish()->void:
	if not session.active or not multiplayer.is_server():return
	board=Records.snapshot(session.leaderboard.records)
	for peer in session.leaderboard.peers:
		var state:Dictionary=rules.view(session.leaderboard.peers[peer])
		if not state.is_empty():state["remaining"]=maxf(0,float(state.get("deadline",0))-now)
		if peer==multiplayer.get_unique_id():_receive(state)
		else:
			_receive.rpc_id(peer,state)
@rpc("authority","call_remote","reliable",0)
func _receive(state:Dictionary)->void:
	view=state.duplicate(true);changed.emit()
func can_shoot()->bool:
	return not view.is_empty() and view.get("your_turn",false) and view.get("present",false) and not view.get("done",true) and not view.get("flight",false) and not view.get("retired",true) and not view.get("finished",true)
