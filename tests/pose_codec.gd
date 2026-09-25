extends SceneTree
const Codec = preload("res://scripts/network/pose_codec.gd")
const Fixture = preload("res://tests/network_fixture.gd")
var failures: Array = []
func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label); push_error(label)
func _initialize() -> void:
	var largest := 0
	for location in Codec.location_table():
		for count in [0,4,10]:
			var input := Fixture.player(count, true)
			input.location = location
			if location.begins_with("golf_"): input.golf_club = 7
			input.serial = 2147483647
			input.head.origin = Vector3(2047.99,-2047.99,.00001)
			input.length = 111.123456789; input.reel_angle = TAU; input.user_height = .6
			var bytes := Codec.encode(input); largest = maxi(largest,bytes.size())
			var output := Codec.decode(bytes)
			check(Codec.State.valid(output), "Validated round trip " + location)
			if output.is_empty(): continue
			check(output.serial == input.serial and output.location == location, "Sequence and world preserved")
			check(output.length == input.length and output.reel_angle == input.reel_angle and output.user_height == input.user_height, "Reward/validation scalars exact")
			for key in Codec.State.TRANSFORMS:
				check(output[key].origin == input[key].origin, "World position exact")
				var qa: Quaternion = input[key].basis.get_rotation_quaternion()
				var qb: Quaternion = output[key].basis.get_rotation_quaternion()
				check(absf(qa.dot(qb)) > .999999, "Rotation error below 0.17 degrees")
			for key in Codec.State.VECTORS: check(output[key] == input[key], "World vector exact")
			check(output.body.size() == input.body.size() and input.body.keys().all(func(key): return output.body.has(key)), "Optional body presence preserved")
			for i in 5: check(absf(output.visemes[i]-input.visemes[i]) <= 1.0/510+.000001, "Weight quantization bounded")
	var full := Codec.encode(Fixture.player(10,true))
	for size in full.size(): check(Codec.decode(full.slice(0,size)).is_empty(), "Truncated packet rejected %d" % size)
	var invalid := full.duplicate(); invalid.append(0)
	check(Codec.decode(invalid).is_empty(), "Trailing data rejected")
	invalid = full.duplicate(); invalid[0] = 99
	check(Codec.decode(invalid).is_empty(), "Unknown version rejected")
	invalid = full.duplicate(); invalid.encode_u16(5,65535)
	check(Codec.decode(invalid).is_empty(), "Unknown location rejected")
	invalid = full.duplicate(); invalid.encode_float(44,NAN)
	check(Codec.decode(invalid).is_empty(), "Nonfinite transform rejected")
	invalid = full.duplicate(); invalid.encode_u16(228,65535)
	check(Codec.decode(invalid).is_empty(), "Unknown body bits rejected")
	check(Codec.decode(Codec.encode(Fixture.player())).body.is_empty(), "Full snapshot explicitly removes stale body trackers")
	check(Codec.decode(Codec.encode(Fixture.player())).face.is_empty(), "Full snapshot explicitly removes stale face tracking")
	check(Codec.newer(0,2147483647) and not Codec.newer(2147483647,0) and not Codec.newer(10,10), "Sequence wrap and replay rejection")
	check(largest <= Codec.MAX_BYTES, "Hard pose byte budget")
	print("POSE_CODEC_RESULT max_bytes=",largest," failures=",failures)
	quit(0 if failures.is_empty() else 1)
