extends SceneTree
## Eight destinations, seven relayed origins each; fake time and one congested peer.
const Queue = preload("res://scripts/network/packet_scheduler.gd")
const R = MultiplayerPeer.TRANSFER_MODE_RELIABLE
const U = MultiplayerPeer.TRANSFER_MODE_UNRELIABLE
var failures: Array = []
func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label); push_error(label)
func bytes(size: int) -> PackedByteArray:
	var value:=PackedByteArray();value.resize(size);return value
func _initialize() -> void:
	var q:=Queue.new();var control:=bytes(64);var pose:=bytes(485);var voice:=bytes(114);var bulk:=bytes(32768)
	var sent:Dictionary={};var bulk_bytes:Dictionary={};var reliable_offsets:Dictionary={}
	var peak:=0;var realtime_age:=0;var control_age:=0
	for now in range(0,4000,2):
		for peer in range(2,10):
			if not q.streams.has(Vector3i(peer,4,R)):check(q.enqueue([peer],4,R,bulk,0,now)==OK,"Bulk admission")
			if now%200==0:check(q.enqueue([peer],0,R,control,0,now)==OK,"Control admission")
			for owner in range(2,10):
				if owner==peer:continue
				if now%50==0:check(q.enqueue([peer],1,U,pose,owner,now)==OK,"Pose admission")
				if now%20==0:check(q.enqueue([peer],6,U,voice,0,now)==OK,"Voice admission")
		check(q.maintain(now).is_empty(),"No reliable timeouts")
		peak=maxi(peak,q.queued_bytes)
		var blocked:Dictionary={}
		for i in 32:
			var item:=q.next(now,blocked)
			if item.is_empty():break
			var row:Dictionary=item.row
			# A bounded 120 ms transport refusal must not stall the other seven peers.
			if row.peer==3 and now>=1000 and now<1120:
				blocked[row.key]=true;q.backpressure+=1;continue
			check(item.packet.size()<=994,"Wire bound under load")
			if row.kind=="bulk":bulk_bytes[row.peer]=bulk_bytes.get(row.peer,0)+item.content
			elif row.kind=="control" and row.peer!=3:control_age=maxi(control_age,item.age)
			elif row.kind in ["pose","voice"]:
				check(item.age<Queue.TTL[row.kind],"Never send expired realtime data")
				if row.peer!=3:realtime_age=maxi(realtime_age,item.age)
			if row.mode==R:
				var expected:int=reliable_offsets.get(row.key,0)
				check(row.offset==expected,"Reliable stream stays ordered across scheduling and backpressure")
				reliable_offsets[row.key]=0 if row.offset+item.content==row.bytes.size() else row.offset+item.content
			sent[row.kind]=sent.get(row.kind,0)+1
			q.commit(item)
	for kind in Queue.RATES:check(q.sent_bytes[kind]<=Queue.BURSTS[kind]+4*Queue.RATES[kind],"Aggregate class budget: "+kind)
	check(bulk_bytes.size()==8 and bulk_bytes.values().max()-bulk_bytes.values().min()<32768,"Bulk progresses fairly despite congested recipient")
	check(control_age<30 and realtime_age<50,"Healthy control and realtime queues stay responsive")
	check(q.expired.voice>0 and q.coalesced>0 and q.backpressure>0,"Congestion exercises voice expiry, pose replacement and retry")
	check(peak<524288,"Bounded queued memory under mixed load")
	print("SCHEDULER_STRESS_RESULT ",JSON.stringify({"failures":failures,"control_max_age_ms":control_age,"healthy_realtime_max_age_ms":realtime_age,"peak_queued_bytes":peak,"bulk_bytes":bulk_bytes,"sent_packets":sent,"scheduler":q.diagnostics(4000)}))
	quit(0 if failures.is_empty() else 1)
