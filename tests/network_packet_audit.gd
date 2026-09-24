extends SceneTree
## Offline fixtures + loopback RPC serialization. No VR, EOS login or game scene.
const State = preload("res://scripts/network/state.gd")
const Courses = preload("res://addons/golfminus/scripts/golf/catalog.gd")
class Tap extends "res://scripts/network/threaded_peer.gd":
	var sizes: Array = []
	func _put_packet_script(bytes: PackedByteArray) -> Error:
		sizes.append(bytes.size())
		return super._put_packet_script(bytes)
class Wire extends Node:
	@rpc("authority", "call_remote", "unreliable", 1)
	func pose(_state: Dictionary) -> void: pass
	@rpc("authority", "call_remote", "unreliable", 1)
	func relay(_id: int, _state: Dictionary) -> void: pass
	@rpc("authority", "call_remote", "reliable", 4)
	func chunk(_hash: String, _offset: int, _bytes: PackedByteArray) -> void: pass
	@rpc("authority", "call_remote", "reliable", 0)
	func bbq(_location: String, _state: Dictionary, _clock: float) -> void: pass
	@rpc("authority", "call_remote", "reliable", 0)
	func golf(_state: Dictionary, _ranking: Dictionary) -> void: pass
	@rpc("authority", "call_remote", "reliable", 0)
	func board(_ranking: Dictionary) -> void: pass
	@rpc("authority", "call_remote", "unreliable", 6)
	func voice(_id: int, _serial: int, _data: PackedByteArray, _radio: bool) -> void: pass
var host := Tap.new()
var client := Tap.new()
var wire: Node
var results: Dictionary = {}
var peer_id := 0

func _initialize() -> void: _run.call_deferred()

func player(body_count: int = 0, face: bool = false) -> Dictionary:
	var data := {"user_height":1.78,"serial":124,"location":"lakeside","body":{},"face":{},
		"visemes":PackedFloat32Array([.15,.28,.32,.01,.03]),"state":0,"bait":0,"species":0,
		"rod_tier":0,"rig":0,"length":10.0,"curl":.3,"reel_angle":.712,"golf_club":-1,"golf_stowed":false}
	var i := 0
	for key in State.TRANSFORMS:
		i += 1; data[key] = Transform3D(Basis.from_euler(Vector3(.12*i,.24*i,.07*i)), Vector3(10.125+i*.1,1.75,-25.873+i*.3))
	for key in State.VECTORS:
		i += 1; data[key] = Vector3(10.87+i*.02,.123*i,-25.89-i*.03)
	for key in ["caught","in_hand","xr","bobber_visible","bait_visible"]: data[key] = false
	data.left_valid = true; data.right_valid = true
	var body_keys := ["hips","chest","left_foot","right_foot","left_knee","right_knee","left_elbow","right_elbow","left_hand","right_hand"]
	for index in body_count:
		data.body[body_keys[index]] = Transform3D(Basis.from_euler(Vector3(.014*index,.26,.16)),Vector3(.12,.15+.1*index,-.2))
	if body_count > 0:
		data.body.left_curls = PackedFloat32Array([.15,.25,.36,.48,.59]); data.body.right_curls = PackedFloat32Array([.61,.72,.83,.92,1])
	if face:
		data.face = {"look":Vector2(.1,.07),"blink":Vector2(.4,.2),"gaze":true,"lids":true,
			"mouth":PackedFloat32Array([.1,.2,.3,.4,.5]),"expressions":PackedFloat32Array([.5,.4,.3,.2,.1])}
	assert(State.valid(data))
	return data

func sample(label: String, method: String, args: Array) -> void:
	host.sizes.clear()
	wire.callv("rpc_id", [peer_id, method] + args)
	assert(not host.sizes.is_empty())
	var row := {"rpc_bytes":host.sizes.max(),"eos_with_header":host.sizes.max()+6,
		"variant_args_bytes":var_to_bytes(args).size(),"packet_count":host.sizes.size()}
	if args[-1] is Dictionary:
		row["dictionary_bytes"] = var_to_bytes(args[-1]).size()
	results[label] = row
	await create_timer(.03).timeout

func _run() -> void:
	create_timer(30).timeout.connect(func():
		push_error("NETWORK_PACKET_AUDIT timed out"); quit(1))
	var h := Node.new(); h.name = "PacketAuditHost"; root.add_child(h)
	var c := Node.new(); c.name = "PacketAuditClient"; root.add_child(c)
	var ha := SceneMultiplayer.new(); set_multiplayer(ha, h.get_path())
	var ca := SceneMultiplayer.new(); set_multiplayer(ca, c.get_path())
	wire = Wire.new(); wire.name = "Wire"; h.add_child(wire)
	var remote := Wire.new(); remote.name = "Wire"; c.add_child(remote)
	host.set_bind_ip("127.0.0.1")
	assert(host.create_server(25097, 1, 7) == OK)
	assert(client.create_client("127.0.0.1", 25097, 7) == OK)
	ha.multiplayer_peer = host; ca.multiplayer_peer = client
	var deadline := Time.get_ticks_msec() + 5000
	while ha.get_peers().is_empty() and Time.get_ticks_msec() < deadline: await process_frame
	assert(not ha.get_peers().is_empty())
	peer_id = ha.get_peers()[0]
	# Warm the node-path cache; exclude one-time path negotiation from samples.
	wire.rpc_id(peer_id, "pose", player())
	await create_timer(.2).timeout
	await sample("pose_controllers", "pose", [player()])
	await sample("pose_relay", "relay", [2147483000, player()])
	await sample("pose_hips_feet_face", "relay", [2147483000, player(4, true)])
	await sample("pose_full_body_face", "relay", [2147483000, player(10, true)])
	var golf_pose := player(10, true)
	golf_pose.location = "golf_%s_00" % Courses.ALL[0]; golf_pose.golf_club = 3
	assert(State.valid(golf_pose))
	await sample("pose_golf_full_body", "relay", [2147483000,golf_pose])
	var base := player(); var full := player(10,true)
	results["pose_encoding_comparison"] = {"base_dictionary":var_to_bytes(base).size(),"base_values_array":var_to_bytes(base.values()).size(),
		"full_dictionary":var_to_bytes(full).size(),"full_values_array":var_to_bytes(full.values()).size(),
		"base_zstd":var_to_bytes(base).compress(FileAccess.COMPRESSION_ZSTD).size(),"full_zstd":var_to_bytes(full).compress(FileAccess.COMPRESSION_ZSTD).size()}
	for size in [768, 900, 1024, 32768]:
		var bytes := PackedByteArray(); bytes.resize(size); bytes.fill(127)
		await sample("avatar_chunk_%d" % size, "chunk", ["a".repeat(64), 20_000_000, bytes])
	var model := preload("res://scripts/bbq/model.gd").new(); assert(model.start("lakeside"))
	await sample("bbq_empty", "bbq", ["lakeside", {}, 120.0])
	await sample("bbq_stocked", "bbq", ["lakeside", model.stations.lakeside, 120.0])
	for item in model.stations.lakeside.items:
		item.basis = Basis.from_euler(Vector3(.1,.2,.3)); item.grip_offset = Transform3D.IDENTITY
	await sample("bbq_pose_fields", "bbq", ["lakeside", model.stations.lakeside, 120.0])
	var game := preload("res://addons/golfminus/scripts/golf/course_session.gd").new()
	for i in 8: assert(game.command(str(i), "Player %d" % i,"join",{"course":Courses.ALL[0],"mode":"competition"},0))
	assert(game.command("0","Player 0","start",{},0))
	var records: Dictionary = {}
	for i in 50:
		records[str(i)] = {"name":"Player %02d" % i,"golf":{}}
		for course in Courses.ALL: records[str(i)].golf[course] = {"rounds":5,"forfeits":1,"best":72,"last":76}
	var ranking := preload("res://addons/golfminus/scripts/golf/server_records.gd").snapshot(records)
	await sample("golf_competition_no_records", "golf", [game.view("0"),{}])
	await sample("golf_competition_50_records_per_course", "golf", [game.view("0"),ranking])
	var board := preload("res://scripts/network/leaderboard.gd").new()
	for i in 50:
		board.connect_player(i + 1,str(i).sha256_text(),"Player %02d" % i)
		var row: Dictionary = board.records[board.peers[i + 1]]
		row.golf = records[str(i)].golf.duplicate(true)
	await sample("fishing_leaderboard_50_with_golf", "board", [board.snapshot()])
	for row in board.records.values():
		for course in row.golf:
			row.golf[course].history = []
			for i in 20: row.golf[course].history.append({"time":1700000000.0+i,"differential":float(i)})
	await sample("fishing_leaderboard_50_with_golf_history", "board", [board.snapshot()])
	var enc = preload("res://tests/opus_fixture.gd").encoder()
	var voice_sizes: Array = []
	for i in 50: voice_sizes.append(preload("res://tests/opus_fixture.gd").packet(enc,i*960).size())
	var voice_data := PackedByteArray(); voice_data.resize(400)
	await sample("voice_max_allowed", "voice", [2147483000,100000,voice_data,false])
	results["voice_codec"] = {"samples":voice_sizes.size(),"min":voice_sizes.min(),"max":voice_sizes.max(),"frame_ms":20,"bitrate":24000}
	var path := "res://test-results/eos-meta/packet-audit.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path,FileAccess.WRITE); file.store_string(JSON.stringify(results,"\t")); file.close()
	print("NETWORK_PACKET_AUDIT ", JSON.stringify(results))
	ha.multiplayer_peer = OfflineMultiplayerPeer.new(); ca.multiplayer_peer = OfflineMultiplayerPeer.new()
	host.close(); client.close()
	quit()
