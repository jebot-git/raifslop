extends SceneTree
const Frames = preload("res://scripts/network/packet_frames.gd")
var failures: Array = []
func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label); push_error(label)
func _initialize() -> void:
	for size in [1,978,979,32768,200000,Frames.MAX_MESSAGE]:
		var bytes := PackedByteArray(); bytes.resize(size)
		for i in size: bytes[i] = (i*37+11) % 256
		var packets := Frames.split(bytes,12,true)
		var receiver := Frames.new(); var result: Dictionary = {}
		for packet in packets:
			check(packet.size()+Frames.EOS_HEADER <= 1000, "Wire size bound")
			result = receiver.receive(2,4,true,packet,0)
		check(result.get("packet") == bytes and receiver.reserved == 0, "Exact reassembly %d" % size)
	var big := PackedByteArray(); big.resize(32768)
	check(Frames.split(big,1,false).is_empty(), "Oversize unreliable data never fragments")
	var parts := Frames.split(big,1,true)
	var receiver := Frames.new()
	check(receiver.receive(2,0,true,parts[1],0).has("error"), "Missing first fragment rejected")
	receiver.receive(2,0,true,parts[0],0)
	check(receiver.receive(2,0,true,parts[0],1).has("error") and receiver.reserved == 0, "Duplicate fragment rejects and frees reservation")
	receiver.receive(2,0,true,parts[0],0)
	check(receiver.expire(Frames.TIMEOUT_MS) == [2] and receiver.reserved == 0, "Absolute reassembly deadline")
	receiver.receive(2,0,true,parts[0],0)
	receiver.receive(3,0,true,parts[0],0)
	receiver.drop(2)
	check(receiver.reserved == big.size(), "Disconnect clears only its peer")
	var short: PackedByteArray = Frames.split(PackedByteArray([7]),9,false)[0]
	check(receiver.receive(3,0,false,short,1).packet == PackedByteArray([7]), "Unreliable same-channel packet does not disturb reliable assembly")
	for i in range(1,parts.size()): receiver.receive(3,0,true,parts[i],1)
	check(receiver.reserved == 0, "Reliable assembly survives interleaved unreliable message")
	big.resize(Frames.MAX_MESSAGE)
	parts = Frames.split(big,2,true)
	receiver.receive(2,0,true,parts[0],0); receiver.receive(2,1,true,parts[0],0)
	check(receiver.receive(2,2,true,parts[0],0).has("error") and receiver.reserved == 0, "Per-peer allocation limit")
	for peer in range(2,10): receiver.receive(peer,0,true,parts[0],0)
	check(receiver.receive(10,0,true,parts[0],0).has("error") and receiver.reserved == Frames.MAX_BYTES, "Aggregate allocation limit")
	var malformed: PackedByteArray = parts[0].duplicate(); malformed.encode_u32(8,0xffffffff)
	check(receiver.receive(11,0,true,malformed,0).has("error"), "Untrusted length bounded before allocation")
	print("PACKET_FRAMES_RESULT ", failures)
	quit(0 if failures.is_empty() else 1)
