extends RefCounted
## Single-owner, transport-independent egress scheduling. Call under the worker lock.
const Frames = preload("res://scripts/network/packet_frames.gd")
const RELIABLE = MultiplayerPeer.TRANSFER_MODE_RELIABLE
const UNRELIABLE = MultiplayerPeer.TRANSFER_MODE_UNRELIABLE
const MAX_BYTES := 8_388_608
const MAX_PEER_BYTES := 2_097_152
const MAX_BULK_BYTES := 4_194_304 # Reserve space for control/realtime traffic.
const MAX_MESSAGES := 4096
const MAX_BULK_MESSAGES := 2048
const RELIABLE_TTL := 60_000
const TTL = {"pose":150, "voice":100}
# Application budgets, including framing and the reserved EOSG header; not EOS quotas.
const RATES = {"control":262144, "pose":655360, "voice":393216, "bulk":262144}
const BURSTS = {"control":8192, "pose":8192, "voice":8192, "bulk":4096}
const CYCLE = ["control", "control", "control", "control", "pose", "voice", "pose", "voice", "bulk"]
var streams: Dictionary = {}
var peer_bytes: Dictionary = {}
var queued_bytes := 0
var message_count := 0
var class_bytes := {"control":0, "pose":0, "voice":0, "bulk":0}
var class_counts := {"control":0, "pose":0, "voice":0, "bulk":0}
var tokens: Dictionary = BURSTS.duplicate()
var sent_bytes := {"control":0, "pose":0, "voice":0, "bulk":0}
var max_age := {"control":0, "pose":0, "voice":0, "bulk":0}
var expired := {"pose":0, "voice":0}
var coalesced := 0
var rejected := 0
var backpressure := 0
var last_time := -1
var serial := 0
var cycle_cursor := 0
var last_stream: Dictionary = {}

static func category(channel: int, mode: int) -> String:
	if channel == 4: return "bulk" # Preserve avatar command/data order on this channel.
	if mode == UNRELIABLE and channel == 1: return "pose"
	if mode == UNRELIABLE and channel == 6: return "voice"
	return "control"

func enqueue(targets: Array, channel: int, mode: int, bytes: PackedByteArray, pose_source: int, now: int) -> Error:
	if bytes.is_empty() or bytes.size() > Frames.MAX_MESSAGE or channel < 0 or channel > 6:
		return ERR_INVALID_PARAMETER
	if mode != RELIABLE and bytes.size() > Frames.CONTENT: return ERR_INVALID_PARAMETER
	var kind := category(channel, mode)
	var replaced: Array = []
	var extra := 0
	# Admission is atomic for broadcasts: no partial delivery on queue rejection.
	for peer in targets:
		var key := Vector3i(peer, channel, mode)
		var old: Dictionary = {}
		if kind == "pose" and pose_source > 0:
			for row in streams.get(key, []):
				if row.source == pose_source: old = row; break
		var growth: int = bytes.size() - (old.bytes.size() if not old.is_empty() else 0)
		if peer_bytes.get(peer, 0) + growth > MAX_PEER_BYTES:
			rejected += 1; return ERR_OUT_OF_MEMORY
		extra += growth
		if not old.is_empty(): replaced.append(old)
	var count := targets.size() - replaced.size()
	if queued_bytes + extra > MAX_BYTES or message_count + count > MAX_MESSAGES or (kind == "bulk" and (class_bytes.bulk + extra > MAX_BULK_BYTES or class_counts.bulk + count > MAX_BULK_MESSAGES)):
		rejected += 1; return ERR_OUT_OF_MEMORY
	for row in replaced: remove(row); coalesced += 1
	for peer in targets:
		var key := Vector3i(peer, channel, mode)
		serial = (serial + 1) & 0xffffffff
		var row := {"key":key, "peer":peer, "channel":channel, "mode":mode, "kind":kind, "bytes":bytes.duplicate(), "source":pose_source, "created":now, "serial":serial, "offset":0}
		if not streams.has(key): streams[key] = []
		streams[key].append(row)
		queued_bytes += bytes.size(); message_count += 1
		peer_bytes[peer] = peer_bytes.get(peer, 0) + bytes.size()
		class_bytes[kind] += bytes.size(); class_counts[kind] += 1
	return OK

func remove(row: Dictionary) -> void:
	var key: Vector3i = row.key
	streams[key].erase(row)
	if streams[key].is_empty(): streams.erase(key)
	queued_bytes -= row.bytes.size(); message_count -= 1
	peer_bytes[row.peer] -= row.bytes.size()
	if peer_bytes[row.peer] == 0: peer_bytes.erase(row.peer)
	class_bytes[row.kind] -= row.bytes.size(); class_counts[row.kind] -= 1

func drop(peer: int) -> void:
	for key in streams.keys():
		if key.x != peer: continue
		for row in streams[key].duplicate(): remove(row)

func maintain(now: int) -> Array:
	if last_time < 0: last_time = now
	var delta := maxi(0, now - last_time)/1000.0
	last_time = now
	for kind in RATES: tokens[kind] = minf(BURSTS[kind], tokens[kind] + delta*RATES[kind])
	var timed_out: Array = []
	for key in streams.keys():
		for row in streams[key].duplicate():
			var age: int = now - row.created
			if TTL.has(row.kind) and age >= TTL[row.kind]:
				expired[row.kind] += 1; remove(row)
			elif age >= RELIABLE_TTL and row.peer not in timed_out:
				timed_out.append(row.peer)
	# Never silently discard accepted reliable RPCs: the caller disconnects these peers.
	for peer in timed_out: drop(peer)
	return timed_out

func next(now: int, blocked: Dictionary = {}) -> Dictionary:
	for attempt in CYCLE.size():
		var kind: String = CYCLE[cycle_cursor]; cycle_cursor = (cycle_cursor + 1) % CYCLE.size()
		var keys: Array = []
		for key in streams:
			if streams[key][0].kind == kind: keys.append(key)
		if keys.is_empty(): continue
		var start := (keys.find(last_stream.get(kind)) + 1) % keys.size()
		for i in keys.size():
			var key: Vector3i = keys[(start + i) % keys.size()]
			if blocked.has(key): continue
			var row: Dictionary = streams[key][0]
			var size := mini(Frames.CONTENT, row.bytes.size() - row.offset)
			var cost := Frames.HEADER + Frames.EOS_HEADER + size
			if tokens[kind] < cost: continue
			last_stream[kind] = key
			return {"row":row, "packet":Frames.fragment(row.bytes, row.serial, row.offset), "cost":cost, "content":size, "age":maxi(0,now-row.created)}
	return {}

func commit(item: Dictionary) -> bool:
	var row: Dictionary = item.row
	tokens[row.kind] -= item.cost; sent_bytes[row.kind] += item.cost
	max_age[row.kind] = maxi(max_age[row.kind], item.age)
	row.offset += item.content
	if row.offset == row.bytes.size(): remove(row); return true
	return false

func diagnostics(now: int) -> Dictionary:
	var ages := {"control":0, "pose":0, "voice":0, "bulk":0}
	for key in streams:
		var row: Dictionary = streams[key][0]
		ages[row.kind] = maxi(ages[row.kind], now-row.created)
	return {"queued_bytes":queued_bytes, "queued_messages":message_count, "class_bytes":class_bytes.duplicate(), "oldest_ms":ages, "sent_bytes":sent_bytes.duplicate(), "max_send_age_ms":max_age.duplicate(), "expired":expired.duplicate(), "coalesced":coalesced, "rejected":rejected, "backpressure":backpressure}
