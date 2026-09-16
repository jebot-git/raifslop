extends SceneTree
class Transfers extends "res://scripts/network/avatars.gd":
	var sent:Array=[]
	func send_avatar(peer:int, method:String, args:Array)->void:sent.append([peer,method,args])
	func publish()->void:pass
var failures:Array=[]
func check(ok:bool,label:String)->void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize()->void:run.call_deferred()
func run()->void:
	var g=load("res://scenes/main.tscn").instantiate();root.add_child(g)
	await process_frame
	var t=Transfers.new();g.add_child(t);t.setup(g.network);t.set_process(false)
	g.network.players[2]={"name":"Fixture"}
	var a:="a".repeat(64);var b:="b".repeat(64);var c:="c".repeat(64)
	for hash in [a,b,c]:
		t.offer_times.clear();t.accept_offer(2,hash,1024)
	check(t.pending[2].hash==c and t.expected.keys()==[c],"Rapid A/B/C offers retain only latest pending selection")
	check(t.sent.any(func(row):return row[1]=="_cancel" and row[2]==[a]),"Superseded transfer explicitly cancelled")
	check(t.sent.filter(func(row):return row[1]=="_offer_result" and row[2][1]).size()==3,"Accepted selections acknowledged")
	t.accept_offer(2,b,1024)
	check(t.pending[2].hash==c and t.sent.back()==[2,"_offer_result",[b,false]],"Throttled new offer receives a retry response and cannot replace accepted choice")
	for i in 3:t.retry_request(c,"fixture timeout")
	check(t.expected.has(c) and t.expected[c].attempt==3,"Request retries are bounded with backoff")
	t.retry_request(c,"fixture timeout")
	check(not t.expected.has(c) and not t.pending.has(2) and g.network.loading.message=="fixture timeout","Retry exhaustion ends request and exposes recoverable error")
	var loading=g.network.loading
	loading.begin_item("model:"+c,1024,"Avatar")
	check(loading.message.is_empty(),"Retry clears that asset's stale error")
	loading.fail("other","Other failure");loading.complete("model:"+c)
	check(loading.message=="Other failure","Unrelated completion does not hide another error")
	loading.cancel("other");check(loading.message.is_empty(),"Superseded error clears")
	t.offer_times.clear();t.accept_offer(2,c,1024)
	t.expected[c].started=Time.get_ticks_msec()-t.QUEUE_TIMEOUT-1
	t.retry_request(c,"queue timeout")
	check(not t.expected.has(c),"Busy queue has a hard overall deadline")
	t.offer_times.clear();t.accept_offer(2,a,1024)
	var partial:="user://stalled-avatar.part"
	var file:=FileAccess.open(partial,FileAccess.WRITE);file.store_8(0);file.close()
	t.disk.track(partial)
	t.incoming[a]={"peer":2,"size":1024,"offset":1,"written":1,"path":partial,"time":Time.get_ticks_msec()-30001,"started":Time.get_ticks_msec()-31000,"attempt":0,"transfer_id":99}
	t.expected.erase(a);t._process(.01)
	check(not t.incoming.has(a) and t.expected[a].attempt==1 and t.pending[2].hash==a,"Stalled download cancels sender and retries without losing the desired avatar")
	g.network.players[3]={"name":"Alternate"};t.pending[3]={"hash":a,"size":1024}
	t.remove_peer(2)
	check(t.expected.has(a) and t.expected[a].peer==3,"Shared avatar retries with another owner after sender disconnects")
	loading.fail("model:"+b,"Obsolete image failure");t.cancel_obsolete()
	check(not loading.errors.has("model:"+b),"Superseded avatar clears its old import error")
	t.reset();check(t.expected.is_empty() and t.pending.is_empty() and t.offer_attempts==0,"Reconnect clears transfers and resets offer retries")
	g.ambience.stop();await create_timer(.3).timeout
	g.queue_free();await process_frame;await create_timer(.3).timeout
	quit(0 if failures.is_empty() else 1)
