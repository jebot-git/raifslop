extends SceneTree
const Protocol=preload("res://scripts/network/state.gd")
const Fixture=preload("res://tests/opus_fixture.gd")
var game
var net
var role := ""
var failures: Array = []
var observations: Dictionary = {}
func _initialize() -> void: run.call_deferred()
func check(ok: bool, title: String) -> void:
	print("PASS " if ok else "FAIL ",title)
	if not ok: failures.append(title)
func wait_for(condition: Callable, seconds: float=15) -> bool:
	var end:=Time.get_ticks_msec()+seconds*1000
	while Time.get_ticks_msec()<end:
		if condition.call(): return true
		await create_timer(.02).timeout
	return false
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	role=args[0]
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	net=game.network
	if role=="server":
		check(game.server_only and not is_instance_valid(game.head),"Dedicated server skips scene assets and XR rig")
		check(await wait_for(func(): return net.players.size()==2),"Two clients joined dedicated server")
		check(await wait_for(func(): return net.voice.relayed_packets>50),"Dedicated server relays voice")
		check(await wait_for(func(): return net.avatars.choices.size()==2,25),"Dedicated server verifies both avatar offers")
		await create_timer(9).timeout
	else:
		game.set_process(false); game.motor.set_physics_process(false)
		net.headless=false # Exercise remote GLTF loading even with the dummy renderer.
		net.voice.test_receive=true
		if role=="host": net.display_name="sender"; net.host(int(args[1]))
		else:
			net.display_name=role
			net.join("127.0.0.1",int(args[1]))
		if role in ["sender","host"]:
			game.avatars.selected_path=args[2]
		check(await wait_for(func(): return net.active and net.players.size()>=2),"Session handshake and roster")
		var baseline: Array=game.game.journal.duplicate(true)
		check(Protocol.valid(Protocol.capture(game,1)),"Live game state satisfies wire schema")
		var invalid:=Protocol.capture(game,1); invalid.head.origin.x=NAN
		check(not Protocol.valid(invalid),"Non-finite tracked pose rejected")
		invalid=Protocol.capture(game,1); invalid.species=999
		check(not Protocol.valid(invalid),"Unknown species rejected")
		if role in ["sender","host"]:
			var enc:=Fixture.encoder()
			for frame in range(430):
				game.head.position.x=.4+sin(frame*.03)*.2
				game.desktop_left.position=Vector3(-.3,1.3,-.2)
				game.rod.rotation.y=sin(frame*.03)*.3
				game.motor.last_motion=Vector3(.5,0,0)
				game.tracking_manager.body={"hips":Transform3D(Basis(Vector3.UP,.3),Vector3(0,.92,0)),"left_foot":Transform3D(Basis.IDENTITY,Vector3(-.13,.3,0)),"left_curls":PackedFloat32Array([0,.2,.4,.6,.8])}
				game.tracking_manager.face={"look":Vector2(.1,.05),"blink":Vector2(.4,.2),"gaze":true,"lids":true}
				net.voice.set_mouth_pose(net.multiplayer.get_unique_id(),PackedFloat32Array([.7,.1,0,0,0]))
				game.game.state=game.Session.State.CASTING if frame<80 else game.Session.State.LANDED
				if frame==80:
					game.game.fish_index=6
					game.game.journal.append({"length":63.0})
					game._show_fish()
					game.fish_display.transform=Transform3D(Basis(Vector3.FORWARD,-PI/2),Vector3(.4,1.25,-.5))
				if frame==200: game.catch_in_hand=true
				if frame==330: game.fish_display.visible=false; game.game.state=game.Session.State.READY
				game.bobber.position=Vector3(0,0,-10)
				net.voice.send_packet(Fixture.packet(enc,frame*960))
				await create_timer(.02).timeout
			check(net.voice.received_packets==0,"Voice sender has no network echo")
			await create_timer(2).timeout
		else:
			var until:=Time.get_ticks_msec()+(7000 if role=="late" else 11000)
			var sender:=0
			var mute_tested:=false
			while Time.get_ticks_msec()<until:
				for id in net.players:
					if net.players[id].name=="sender": sender=id
				if net.voice.decoded_packets>25 and not mute_tested:
					mute_tested=true
					net.voice.set_muted(sender,true)
					var before: int=net.voice.received_packets
					await create_timer(.15).timeout
					check(net.voice.received_packets==before,"Per-player mute blocks received audio")
					net.voice.set_muted(sender,false)
				if net.states.has(sender):
					var s: Dictionary=net.states[sender]
					if s.body.has("left_foot") and s.body.left_foot.origin.y>.25: observations.body=true
					if s.body.get("left_curls",PackedFloat32Array()).size()==5 and s.body.left_curls[4]>.7: observations.fingers=true
					if s.face.get("gaze",false) and s.face.blink.x>.3: observations.face=true
					if s.visemes[0]>.6: observations.visemes=true
					if s.state==1: observations.casting=true
					if s.caught and s.species==6 and s.length==63: observations.catch=true
					if s.in_hand and s.caught: observations.hand=true
					if observations.has("catch") and not s.caught: observations.release=true
					if s.head.origin.x>.3 and s.motion.x==.5: observations.movement=true
				if net.fighters.has(sender) and not net.fighters[sender].avatar_hash.is_empty(): observations.avatar=true
				await create_timer(.02).timeout
			for key in (["catch","hand","release","movement","avatar","body","fingers","face","visemes"] if role=="late" else ["casting","catch","hand","release","movement","avatar","body","fingers","face","visemes"]): check(observations.has(key),"Remote "+key)
			check(net.voice.decoded_packets>20 and net.voice.decoded_peak>.01,"Real Opus voice decoded with audible signal")
			check(game.game.journal==baseline,"Remote catches never write local Fish Guide")
			if net.fighters.has(sender):
				game.current_location="gray_pier"; await process_frame
				check(await wait_for(func(): return not net.fighters.has(sender) or not net.fighters[sender].visible,1),"Different locations hide remote anglers")
				check(not net.same_location(root.get_multiplayer().get_unique_id(),sender) or await wait_for(func(): return not net.same_location(root.get_multiplayer().get_unique_id(),sender),1),"Voice location filtering follows travel")
				game.current_location="lakeside"
	print("MULTIPLAYER_RESULT ",role," ",failures)
	net.leave()
	if is_instance_valid(game.ambience):game.ambience.stop()
	await create_timer(.3).timeout
	game.queue_free(); await process_frame; await create_timer(.3).timeout
	quit(0 if failures.is_empty() else 1)
