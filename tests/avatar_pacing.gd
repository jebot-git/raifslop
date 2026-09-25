extends SceneTree
## Real avatar RPCs/disk jobs, synthetic content: model validation is tested separately.
const Transport = preload("res://scripts/network/threaded_peer.gd")
class TestGame extends Node:
	var active:=false
	var dedicated:=true
	var headless:=true
	var clock:=0.0
	var players:Dictionary={}
	var fighters:Dictionary={}
	var loading=preload("res://scripts/network/loading.gd").new()
class TestLibrary extends Node:
	var entries:Dictionary={}
	var selected:=""
class Transfers extends "res://scripts/network/avatars.gd":
	var completed:Dictionary={}
	var control_age:=0
	var control_count:=0
	func setup(owner:Node)->void:
		game=owner;name="AvatarNetwork";add_child(disk)
		library=TestLibrary.new();add_child(library)
	func finish_model(hash:String,transfer:Dictionary)->void:
		completed[hash]={"hash":FileAccess.get_sha256(transfer.path),"bytes":transfer.written,"at":Time.get_ticks_msec()}
		disk.discard(transfer.path);incoming.erase(hash);game.loading.complete("model:"+hash)
	@rpc("any_peer","call_remote","reliable",0)
	func control_probe(sent:int)->void:
		control_age=maxi(control_age,Time.get_ticks_msec()-sent);control_count+=1
var failures:Array=[]
func check(ok:bool,label:String)->void:
	if not ok:failures.append(label);push_error(label)
func _initialize()->void:run.call_deferred()
func run()->void:
	var nodes:Array=[];var transfers:Array=[];var peers:Array=[]
	var port:=26000+OS.get_process_id()%1000
	for i in 3:
		var game:=TestGame.new();game.name="AvatarPacing%d"%i;root.add_child(game);nodes.append(game)
		var api:=SceneMultiplayer.new();set_multiplayer(api,game.get_path())
		var peer:=Transport.new();peer.framed=true;peers.append(peer)
		var error:=peer.create_server(port,2,7) if i==0 else peer.create_client("127.0.0.1",port,7)
		check(error==OK,"Pacing peer starts");api.multiplayer_peer=peer
		var transfer:=Transfers.new();game.add_child(transfer);transfer.setup(game);transfers.append(transfer)
	var deadline:=Time.get_ticks_msec()+5000
	while nodes[0].multiplayer.get_peers().size()!=2 and Time.get_ticks_msec()<deadline:await create_timer(.01).timeout
	check(nodes[0].multiplayer.get_peers().size()==2,"Both transfer recipients connect")
	var content:=PackedByteArray();content.resize(393229)
	for i in content.size():content[i]=(i*31)%256
	var path:="user://paced-content.bin";var file:=FileAccess.open(path,FileAccess.WRITE);file.store_buffer(content);file.close()
	var hash:=FileAccess.get_sha256(path)
	transfers[0].library.entries[hash]={"path":path,"size":content.size()}
	transfers[0].choices[1]={"hash":hash,"size":content.size()}
	for i in [1,2]:nodes[0].players[peers[i].get_unique_id()]={"name":"Recipient"}
	for i in [1,2]:transfers[i].expect_model(hash,1,content.size())
	var started:=Time.get_ticks_msec();var next_probe:=started;var peak_window:=0
	deadline=started+15000
	while (transfers[1].completed.is_empty() or transfers[2].completed.is_empty()) and Time.get_ticks_msec()<deadline:
		var now:=Time.get_ticks_msec()
		if now>=next_probe:
			next_probe=now+50
			for i in [1,2]:transfers[0].control_probe.rpc_id(peers[i].get_unique_id(),now)
		for row in transfers[0].outgoing.values():peak_window=maxi(peak_window,row.sent-row.ack)
		await create_timer(.01).timeout
	var elapsed:=Time.get_ticks_msec()-started
	for i in [1,2]:
		check(transfers[i].completed.has(hash),"Concurrent avatar completes")
		if transfers[i].completed.has(hash):
			check(transfers[i].completed[hash].hash==hash and transfers[i].completed[hash].bytes==content.size(),"Disk reconstruction and hash exact, including short tail")
		check(transfers[i].control_count>20 and transfers[i].control_age<250,"Control remains responsive during avatar disk/RPC traffic")
	check(elapsed>=3500 and elapsed<10000,"Both uploads share 192 KiB/s aggregate content budget")
	check(peak_window<=65536,"Independent 64 KiB upload window enforced")
	check(peers[0].diagnostics().wire_max_bytes<=994,"Avatar fragments retain EOS packet bound")
	print("AVATAR_PACING_RESULT ",JSON.stringify({"failures":failures,"elapsed_ms":elapsed,"control_max_ms":[transfers[1].control_age,transfers[2].control_age],"peak_unacked_bytes":peak_window}))
	for i in 3:transfers[i].reset();peers[i].close();nodes[i].queue_free()
	await process_frame;await create_timer(.1).timeout
	quit(0 if failures.is_empty() else 1)
