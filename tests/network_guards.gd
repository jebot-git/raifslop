extends SceneTree
const Fixture=preload("res://tests/opus_fixture.gd")
var failures: Array=[]
func _initialize() -> void: run.call_deferred()
func check(ok: bool,title: String) -> void:
	print("PASS " if ok else "FAIL ",title)
	if not ok: failures.append(title)
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	await create_timer(.1).timeout
	var net=game.network
	net.active=true; net.players[2]={"name":"Speaker"}
	var data:=Fixture.packet(Fixture.encoder())
	check(net.voice.mode==2 and net.voice.mic==null,"Voice defaults to activation without opening microphone in headless tests")
	check(net.SERVER_MAX_PLAYERS==8,"Multiplayer has eight player slots")
	var preferences=preload("res://scripts/voice/preferences.gd")
	for saved_mode in [0,1]:
		var cfg:=ConfigFile.new();cfg.set_value("voice","mode",saved_mode);cfg.save("user://voice_default_test.cfg")
		check(preferences.read_settings("user://voice_default_test.cfg").mode==saved_mode,"Saved voice mode remains selected: "+str(saved_mode))
	check(net.voice.accept_sender(2,1,data),"Joined speaker accepted")
	check(not net.voice.accept_sender(3,1,data),"Unjoined voice sender rejected")
	check(not net.voice.accept_sender(2,1,data),"Replayed voice sequence rejected")
	check(not net.voice.accept_sender(2,2,PackedByteArray([1,2,3])),"Invalid Opus frame rejected")
	for i in range(2,13): net.voice.accept_sender(2,i,data)
	check(not net.voice.accept_sender(2,13,data),"Voice flood budget enforced")
	net.clock+=.1
	check(net.voice.accept_sender(2,14,data),"Voice budget recovers")
	var state=preload("res://scripts/network/state.gd").capture(game,10)
	net._accept(2,state,true)
	check(net.states.has(2),"Valid fishing state accepted")
	state.serial=9; state.head.origin.x=100
	net._accept(2,state,false)
	check(net.states[2].serial==10,"Old pose cannot overwrite reliable catch event")
	state.serial=11; state.caught=true; state.state=0
	net._accept(2,state,true)
	check(net.states[2].serial==10,"Caught fish must be in landed state")
	check(not net.same_location(1,2),"Missing player location cannot receive voice")
	check(net.avatars.library.valid_hash("a".repeat(64)) and not net.avatars.library.valid_hash("../secret"),"Avatar requests use hashes only")
	var schema=preload("res://scripts/network/state.gd")
	for index in range(12, game.game.SPECIES.size()):
		var expanded: Dictionary = schema.capture(game,20)
		expanded.species = index
		expanded.state = 5
		expanded.caught = true
		expanded.length = game.game.SPECIES[index].length
		check(schema.valid(expanded), "New species catch accepted by network schema: " + game.game.SPECIES[index].name)
	for height in [NAN,INF,.2,4.0]:
		var bad_height:Dictionary=schema.capture(game,20);bad_height.user_height=height
		check(not schema.valid(bad_height),"Invalid remote user height rejected")
	var invalid: Dictionary=schema.capture(game,20); invalid.body={"left_curls":PackedFloat32Array([0,0,NAN,0,0])}
	check(not schema.valid(invalid),"Non-finite finger curl rejected")
	invalid=schema.capture(game,20); invalid.body={"hips":Transform3D(Basis.IDENTITY,Vector3(100,0,0))}
	check(not schema.valid(invalid),"Out-of-reach body tracking rejected")
	invalid=schema.capture(game,20); invalid.face={"look":Vector2(NAN,0),"blink":Vector2.ZERO,"gaze":true,"lids":true}
	check(not schema.valid(invalid),"Invalid face tracking rejected")
	invalid=schema.capture(game,20); invalid.visemes=PackedFloat32Array([2,0,0,0,0])
	check(not schema.valid(invalid),"Out-of-range visemes rejected")
	for key in ["bobber_visible", "bait_visible"]:
		invalid=schema.capture(game,20); invalid[key]=1
		check(not schema.valid(invalid), "Non-boolean tackle visibility rejected: "+key)
	invalid=schema.capture(game,20); invalid.bait_position=Vector3(NAN,0,0)
	check(not schema.valid(invalid), "Non-finite bait position rejected")
	check(net.host(80)==ERR_INVALID_PARAMETER,"Invalid server port rejected")
	check(net.join("",24567)==ERR_INVALID_PARAMETER,"Empty join address rejected")
	print("NETWORK_GUARDS_RESULT ",failures)
	net.leave(); game.queue_free(); await process_frame; await create_timer(.15).timeout
	quit(0 if failures.is_empty() else 1)
