extends RefCounted
## Transport-independent framing, beneath SceneMultiplayer and above ENet/EOSG.
## Reliable fragments must arrive in order on each sender/channel stream.
const EOS_HEADER := 6
const WIRE_BUDGET := 1000 - EOS_HEADER
const HEADER := 16
const CONTENT := WIRE_BUDGET - HEADER
const MAX_MESSAGE := 1_048_576
const MAX_PEER_BYTES := 2 * MAX_MESSAGE
const MAX_BYTES := 8 * MAX_MESSAGE
const TIMEOUT_MS := 60_000 # Allows fair pacing of maximum messages across eight peers.
const MAGIC := 0xe051
var pending: Dictionary = {}
var reserved := 0
var rejected := 0

static func split(bytes: PackedByteArray, serial: int, reliable: bool) -> Array:
	if bytes.is_empty() or bytes.size() > MAX_MESSAGE or (not reliable and bytes.size() > CONTENT): return []
	var result: Array = []
	for offset in range(0, bytes.size(), CONTENT):
		result.append(fragment(bytes, serial, offset))
	return result

static func fragment(bytes: PackedByteArray, serial: int, offset: int) -> PackedByteArray:
	var frame := PackedByteArray(); frame.resize(HEADER)
	frame.encode_u16(0, MAGIC); frame[2] = 1; frame[3] = 0
	frame.encode_u32(4, serial); frame.encode_u32(8, bytes.size()); frame.encode_u32(12, offset)
	frame.append_array(bytes.slice(offset, mini(offset + CONTENT, bytes.size())))
	return frame

func drop(peer: int) -> void:
	for key in pending.keys():
		if key.x == peer:
			reserved -= pending[key].total; pending.erase(key)

func expire(now: int) -> Array:
	var peers: Array = []
	for key in pending:
		if now - pending[key].started >= TIMEOUT_MS and key.x not in peers: peers.append(key.x)
	for peer in peers: drop(peer)
	return peers

func fail(peer: int) -> Dictionary:
	rejected += 1; drop(peer)
	return {"error":true}

func receive(peer: int, channel: int, reliable: bool, frame: PackedByteArray, now: int) -> Dictionary:
	if frame.size() <= HEADER or frame.size() > WIRE_BUDGET or channel < 0 or channel > 6: return fail(peer)
	if frame.decode_u16(0) != MAGIC or frame[2] != 1 or frame[3] != 0: return fail(peer)
	var serial := frame.decode_u32(4); var total := frame.decode_u32(8); var offset := frame.decode_u32(12)
	var count := frame.size() - HEADER
	if total < 1 or total > MAX_MESSAGE or offset >= total or offset % CONTENT != 0 or count != mini(CONTENT, total-offset): return fail(peer)
	var key := Vector2i(peer, channel)
	# Unreliable snapshots are never fragmented, and cannot interfere with a
	# reliable stream using the same logical channel (ENet channel 0, for example).
	if not reliable:
		if offset != 0 or total != count: return fail(peer)
		return {"packet":frame.slice(HEADER)}
	if pending.has(key):
		var row: Dictionary = pending[key]
		if now-row.started >= TIMEOUT_MS or row.serial != serial or row.total != total or row.bytes.size() != offset: return fail(peer)
		row.bytes.append_array(frame.slice(HEADER))
		if row.bytes.size() == total:
			reserved -= total; pending.erase(key)
			return {"packet":row.bytes}
		return {}
	if offset != 0: return fail(peer)
	if total == count: return {"packet":frame.slice(HEADER)}
	var peer_bytes := 0
	for other in pending:
		if other.x == peer: peer_bytes += pending[other].total
	if reserved + total > MAX_BYTES or peer_bytes + total > MAX_PEER_BYTES: return fail(peer)
	pending[key] = {"serial":serial, "total":total, "bytes":frame.slice(HEADER), "started":now}
	reserved += total
	return {}
