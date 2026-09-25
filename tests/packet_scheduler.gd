extends SceneTree
const Queue = preload("res://scripts/network/packet_scheduler.gd")
const Budget = preload("res://scripts/network/bulk_read_budget.gd")
const R = MultiplayerPeer.TRANSFER_MODE_RELIABLE
const U = MultiplayerPeer.TRANSFER_MODE_UNRELIABLE
var failures: Array = []
func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label); push_error(label)
func payload(size: int, value: int = 42) -> PackedByteArray:
	var bytes := PackedByteArray(); bytes.resize(size); bytes.fill(value); return bytes
func _initialize() -> void:
	var q := Queue.new()
	check(q.enqueue([2],4,R,payload(32768),0,0)==OK,"Bulk accepted")
	q.enqueue([2],0,R,payload(20),0,0)
	q.maintain(0)
	var item := q.next(0)
	check(item.row.kind=="control","Control preempts existing bulk")
	q.commit(item)
	q.enqueue([2],1,U,payload(400,1),11,0)
	q.enqueue([2],1,U,payload(400,2),12,0)
	q.enqueue([2],1,U,payload(400,3),11,1)
	check(q.coalesced==1 and q.class_counts.pose==2,"Pose coalescing distinguishes relayed origins")
	var seen: Dictionary = {}
	for i in 20:
		item=q.next(1)
		if item.is_empty(): break
		if item.row.kind=="pose":seen[item.row.source]=item.row.bytes[0]
		q.commit(item)
	check(seen=={11:3,12:2},"Only latest unsent pose retained per origin")
	q.enqueue([2],6,U,payload(100),0,10)
	q.enqueue([2],1,U,payload(400),11,10)
	q.maintain(160)
	check(q.class_counts.pose==0 and q.class_counts.voice==0 and q.expired.pose==1 and q.expired.voice==1,"Stale pose and voice expire")

	q=Queue.new();q.enqueue([2],4,R,payload(32768),0,0);q.maintain(0)
	item=q.next(0)
	var retry:=q.next(0)
	check(item.packet==retry.packet and q.queued_bytes==32768 and q.tokens.bulk==Queue.BURSTS.bulk,"Uncommitted frame retries without consuming budget or advancing")
	q.commit(retry)
	check(q.next(0).row.offset==Queue.Frames.CONTENT,"Successful send advances exactly once")
	q.enqueue([3],4,R,payload(32768,43),0,0)
	check(q.next(0,{Vector3i(2,4,R):true}).row.peer==3,"Backpressured stream does not block another peer")

	q=Queue.new()
	for peer in range(2,9):q.enqueue([peer],4,R,payload(262144,peer),0,0)
	var counts:Dictionary={}
	for now in range(0,2001,2):
		q.maintain(now)
		for i in 32:
			item=q.next(now)
			if item.is_empty():break
			counts[item.row.peer]=counts.get(item.row.peer,0)+1
			check(item.packet.size()<=994,"Fragment budget retained")
			q.commit(item)
	check(counts.size()==7 and counts.values().max()-counts.values().min()<=1,"Seven bulk recipients share bandwidth fairly")
	check(q.sent_bytes.bulk<=Queue.BURSTS.bulk+2*Queue.RATES.bulk and q.sent_bytes.bulk>2*Queue.RATES.bulk-2000,"Aggregate bulk wire budget includes headers")
	var total:int=q.queued_bytes
	q.drop(2)
	check(q.queued_bytes==total-262144 and not q.peer_bytes.has(2),"Disconnect releases partial-message reservation")
	check(q.maintain(Queue.RELIABLE_TTL).size()==6 and q.queued_bytes==0,"Stalled reliable peers time out explicitly")

	q=Queue.new()
	for peer in [2,3]:
		for i in 2:check(q.enqueue([peer],4,R,payload(Queue.Frames.MAX_MESSAGE),0,0)==OK,"Bulk reservation admitted")
	check(q.enqueue([4],4,R,payload(1),0,0)==ERR_OUT_OF_MEMORY,"Bulk cannot consume control reserve")
	check(q.enqueue([4],0,R,payload(100),0,0)==OK,"Control remains admissible with full bulk budget")
	var before:=q.queued_bytes
	check(q.enqueue([4,2],0,R,payload(100),0,0)==ERR_OUT_OF_MEMORY and q.queued_bytes==before,"Broadcast admission is atomic")

	var budget:=Budget.new();var available:Dictionary={};var totals:Dictionary={}
	for peer in range(2,9):available[peer]=Budget.QUANTUM;totals[peer]=0
	for i in 1000:
		var grants:=budget.grants(available,.01)
		for peer in grants:totals[peer]+=grants[peer]
	check(totals.values().max()-totals.values().min()<=Budget.QUANTUM,"Avatar disk grants are fair across seven transfers")
	var bytes:=0
	for value in totals.values():bytes+=value
	check(bytes<=10*Budget.RATE and bytes>=10*Budget.RATE-Budget.QUANTUM,"Avatar content rate is aggregate")
	budget=Budget.new();budget.grants({},100)
	check(budget.credit==Budget.BURST,"Idle time cannot accumulate an unbounded burst")
	check(budget.grants({9:17},0)=={9:17},"Short final chunk can complete")
	budget.last_peer=4;budget.credit=Budget.QUANTUM
	check(budget.grants({2:Budget.QUANTUM,5:Budget.QUANTUM},0)=={5:Budget.QUANTUM},"Busy/disconnected recipient does not reset fair read order")
	print("PACKET_SCHEDULER_RESULT ",failures," bulk_peer_packets=",counts," avatar_bytes=",bytes)
	quit(0 if failures.is_empty() else 1)
