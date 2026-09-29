extends SceneTree
const Fixture=preload("res://tests/network_fixture.gd")
var failures:=0
var checks:=0
var net:Node
var role:=""
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func until(fn:Callable,seconds:=15.0)->bool:
	var deadline:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<deadline:
		if fn.call():return true
		await create_timer(.04).timeout
	return false
func send_pose(golfer:bool)->void:
	var data:Dictionary=Fixture.player();data.serial=1;data.location="lakeside";data.golf_club=7 if golfer else -1
	var at:Vector3=preload("res://scripts/bbq/sites.gd").arrival("lakeside")
	for key in Fixture.State.TRANSFORMS:data[key]=Transform3D(Basis.IDENTITY,at+Vector3(0,1.6,0))
	for key in Fixture.State.VECTORS:data[key]=at
	net.states[net.multiplayer.get_unique_id()]=data;net._submit_event.rpc_id(1,net.PoseCodec.encode(data))
func run()->void:
	var args:=OS.get_cmdline_user_args();role=args[0];var port:=int(args[1])
	var owner:=Node.new();root.add_child(owner)
	net=load("res://scripts/network/session.gd").new();owner.add_child(net);net.setup(owner,true);net.voice_enabled=false
	net.player_token=("a" if role=="golfer" else "b" if role=="angler" else "c").repeat(64);net.display_name=role
	if role=="server":
		check(net.host(port,"127.0.0.1")==OK,"Host starts")
		check(await until(func():return net.states.size()==3),"Three separate activity poses arrive")
		if net.states.size()==3:check(net.same_location(net.states.keys()[0],net.states.keys()[1]),"Golfer and angler share water visibility and voice")
		check(await until(func():return net.bbq.model.stations.has("lakeside")),"Cook starts BBQ while golfer and angler play")
		check(await until(func():
			for state in net.states.values():
				if state.golf_club==-1 and state.state==2 and state.bobber_visible:return true
			return false),"Third player fishes independently of cook and golfer")
		check(await until(func():return net.golf.rules.games.has("lakeside") and net.golf.rules.games.lakeside.finished,25),"Shared minigolf round completes")
		var record_key:String="a".repeat(64).sha256_text()
		if net.leaderboard.records.has(record_key):
			check(net.leaderboard.records[record_key].get("golf",{}).get("lakeside",{}).get("best",0)==18,"Only golfer receives completed score")
		check(net.golf.rules.membership("b".repeat(64).sha256_text()).is_empty(),"Angler/BBQ player is not enrolled or blocked")
		check(await until(func():return net.players.is_empty()),"Three clients leave cleanly")
	else:
		net.join("127.0.0.1",port);check(await until(func():return net.active),"Shared identity handshake")
		send_pose(role=="golfer");await create_timer(.4).timeout
		if role=="golfer":
			net.golf.request("join",{"course":"lakeside","mode":"competition"})
			check(await until(func():return not net.golf.view.is_empty()),"Join current-water round")
			net.golf.request("presence",{"present":true});net.golf.request("start")
			for hole in 18:
				await create_timer(.3).timeout
				if not await until(func():return net.golf.can_shoot() and net.golf.view.hole==hole):check(false,"Turn available");break
				var epoch:int=net.golf.view.epoch;net.golf.request("shot",{"epoch":epoch})
				check(await until(func():return net.golf.view.flight),"Server authorizes stroke")
				net.golf.request("settled",{"epoch":epoch,"holed":true})
			check(await until(func():return net.golf.view.get("finished",false)),"Own card completes")
			check(net.golf.view.get("scores",[]).size()==18,"Guide roster receives full scorecard")
			await create_timer(2).timeout
		elif role=="cook":
			net.bbq.request("start")
			check(await until(func():return net.bbq.model.stations.has("lakeside")),"BBQ remains interactive")
			await create_timer(10).timeout
			check(net.golf.view.is_empty(),"Fishing player never inherits golfer input or score state")
			check(net.states[net.multiplayer.get_unique_id()].golf_club==-1,"Fishing tools stay equipped")
		else:
			var own:Dictionary=net.states[net.multiplayer.get_unique_id()]
			own.state=2;own.bobber_visible=true;own.serial=2
			net._submit_event.rpc_id(1,net.PoseCodec.encode(own))
			await create_timer(10).timeout
			check(net.golf.view.is_empty(),"Dedicated angler remains outside minigolf")
			check(own.golf_club==-1 and own.bobber_visible,"Angler keeps fishing line in water")
	net.leave();owner.queue_free();await process_frame
	print("MINIGOLF_NETWORK ",role," ",checks," checks; ",failures," failures");quit(1 if failures else 0)
