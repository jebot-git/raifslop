extends RefCounted
## Server-owned turn/score state. Identity keys come from Fishing's authenticated roster.
const Handicap=preload("res://addons/golfminus/scripts/golf/handicap.gd")
var stats:Dictionary={}
const RETURN_SECONDS:=300.0
const COURSES:=["spyglass","pebble","dalkey","alpine"]
var games:Dictionary={}
var serial:=0
var run_id:=Crypto.new().generate_random_bytes(8).hex_encode()
signal completed(key:String,course:String,scores:Array)
signal forfeited(key:String,course:String,hole:int)
func membership(key:String)->Dictionary:
	for id in games:
		if games[id].members.has(key):return {"course":games[id].course,"game":games[id],"player":games[id].members[key]}
	return {}
func command(key:String,name:String,action:String,data:Dictionary,now:float)->bool:
	if key.is_empty():return false
	var m:=membership(key)
	if action=="join":
		var course:String=str(data.get("course",""))
		if course not in COURSES:return false
		if not m.is_empty():
			if not m.player.retired and not m.game.finished:return m.course==course and m.game.mode==data.get("mode","solo")
			m.game.members.erase(key);m.game.order.erase(key)
		var mode:String=data.get("mode","solo")
		var game_key:String=course if mode=="competition" else course+"/"+key
		if games.has(game_key) and mode=="competition" and games[game_key].started and not games[game_key].finished:return false
		if not games.has(game_key) or games[game_key].finished:
			serial+=1;games[game_key]={"course":course,"mode":mode,"started":mode=="solo","owner":key,"id":"%s/%d"%[run_id,serial],"hole":0,"turn":"","epoch":0,"deadline":0.0,"flight":false,"finished":false,"members":{},"order":[]}
		var g:Dictionary=games[game_key]
		if g.members.values().filter(func(p):return not p.retired).size()>=8:return false
		var scores:Array=[]
		for i in g.hole:scores.append(-1)
		g.members[key]={"name":name,"handicap":roundi(Handicap.index(stats.get(key,{}))),"present":false,"scores":scores,"strokes":0,"done":false,"retired":false}
		g.order.append(key)
		if g.started and g.turn.is_empty():_next(g,now)
		return true
	if m.is_empty():return false
	var g:Dictionary=m.game;var p:Dictionary=m.player
	if action=="retire":
		if p.retired:return false
		p.retired=true;p.present=false
		if g.owner==key:
			for member in g.order:
				if not g.members[member].retired:g.owner=member;break
		if g.turn==key:_next(g,now)
		elif g.members.values().all(func(member):return member.retired):g.finished=true;g.deadline=0.0
		return true
	if p.retired or g.finished:return false
	if action=="start":
		if g.started or g.owner!=key or g.members.values().filter(func(member):return not member.retired).size()<2:return false
		g.started=true;_next(g,now);return true
	if not g.started:return false
	if action=="presence":
		var present:bool=data.get("present",false)==true
		# Returning at or after the deadline cannot rescue the forfeited hole.
		tick(now)
		if g.finished:return false
		if p.present==present:return true
		p.present=present
		if g.turn==key:g.deadline=0.0 if present or g.mode=="solo" else now+RETURN_SECONDS
		return true
	if g.turn!=key or int(data.get("epoch",-1))!=g.epoch or not p.present:return false
	if action=="shot":
		if g.flight or p.done or p.strokes>=Handicap.cap(g.course,g.hole,p.handicap):return false
		p.strokes+=1;g.flight=true;return true
	if action=="settled":
		if not g.flight:return false
		g.flight=false
		if data.get("hazard",false)==true:p.strokes=mini(100,p.strokes+1)
		if data.get("holed",false)==true or p.strokes>=Handicap.cap(g.course,g.hole,p.handicap):
			p.done=true;p.scores.append(mini(p.strokes,Handicap.cap(g.course,g.hole,p.handicap)))
		_next(g,now);return true
	if action=="penalty" and not g.flight and p.strokes>0:
		p.strokes=mini(Handicap.cap(g.course,g.hole,p.handicap),p.strokes+1)
		if p.strokes>=Handicap.cap(g.course,g.hole,p.handicap):
			p.done=true;p.scores.append(p.strokes);_next(g,now)
		return true
	return false
func tick(now:float)->bool:
	var changed:=false
	for course in games:
		var g:Dictionary=games[course]
		if g.finished or g.turn.is_empty() or g.deadline<=0 or now<g.deadline:continue
		var key:String=g.turn;var p:Dictionary=g.members[key]
		p.done=true;p.strokes=Handicap.cap(g.course,g.hole,p.handicap);p.scores.append(p.strokes);g.flight=false
		forfeited.emit(key,g.course,g.hole)
		_next(g,now);changed=true
	return changed
func _next(g:Dictionary,now:float)->void:
	var available:Array=[]
	for key in g.order:
		if not g.members[key].retired:available.append(key)
	if available.is_empty():g.finished=true;g.turn="";g.deadline=0.0;g.flight=false;return
	var pending:Array=available.filter(func(key):return not g.members[key].done)
	if pending.is_empty():
		g.hole+=1
		if g.hole==18:
			g.finished=true;g.turn="";g.deadline=0.0
			for key in available:
				var course:String=membership(key).course
				completed.emit(key,course,g.members[key].scores.duplicate())
			return
		for key in available:g.members[key].done=false;g.members[key].strokes=0
		pending=available
	var start:int=g.order.find(g.turn)
	for offset in range(1,g.order.size()+1):
		var candidate:String=g.order[(start+offset)%g.order.size()]
		if candidate not in pending:continue
		g.turn=candidate;g.epoch+=1;g.flight=false
		g.deadline=0.0 if g.members[candidate].present or g.mode=="solo" else now+RETURN_SECONDS
		return
func mark_absent(key:String,now:float)->void:
	command(key,"","presence",{"present":false},now)
func view(key:String)->Dictionary:
	var m:=membership(key)
	if m.is_empty():return {}
	var g:Dictionary=m.game
	var p:Dictionary=m.player
	var roster:Array=[]
	for member in g.order:
		var row:Dictionary=g.members[member]
		roster.append({"name":row.name,"handicap":row.handicap,"net":Handicap.net(m.course,row.scores,row.handicap),"scores":row.scores.duplicate(),"retired":row.retired,"present":row.present})
	return {"course":m.course,"mode":g.mode,"started":g.started,"owner":g.owner==key,"handicap":p.handicap,"cap":Handicap.cap(m.course,mini(g.hole,17),p.handicap),"id":g.id,"hole":g.hole,"epoch":g.epoch,"your_turn":g.turn==key,"turn_name":g.members[g.turn].name if not g.turn.is_empty() else "","deadline":g.deadline,"present":p.present,"retired":p.retired,"finished":g.finished,"done":p.done,"strokes":p.strokes,"scores":p.scores.duplicate(),"roster":roster,"flight":g.flight}
