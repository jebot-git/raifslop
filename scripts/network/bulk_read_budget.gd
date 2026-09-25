extends RefCounted
## Fair disk-read admission. Retain 32 KiB disk jobs despite sub-KiB wire frames.
const RATE := 196_608 # 192 KiB/s total content; leaves framing headroom below 256 KiB/s.
const BURST := 65_536
const QUANTUM := 32_768
var credit := 0.0
var last_peer := 0

func grants(available: Dictionary, delta: float) -> Dictionary:
	credit = minf(BURST, credit + maxf(0,delta)*RATE)
	var result: Dictionary = {}
	var peers := available.keys(); peers.sort()
	if peers.is_empty(): return result
	var start := 0
	# Preserve the cursor when the last recipient is temporarily busy/disconnected.
	for i in peers.size():
		if peers[i] > last_peer: start=i; break
	for i in peers.size():
		var peer: int = peers[(start+i)%peers.size()]
		var count := mini(QUANTUM, available[peer])
		if count <= 0 or credit < count: continue
		result[peer] = count; credit -= count; last_peer=peer
	return result

func refund(count: int) -> void: credit=minf(BURST,credit+count)
