extends RefCounted
## Independently decodable protocol-18 snapshots. No object/Variant deserialization.
const State = preload("res://scripts/network/state.gd")
const Locations = preload("res://addons/golfminus/scripts/golf/host_locations.gd")
const FORMAT := 1
const MAX_BYTES := 512
const BODY = ["hips", "chest", "left_foot", "right_foot", "left_knee", "right_knee", "left_elbow", "right_elbow", "left_hand", "right_hand"]
const FLAGS = ["caught", "in_hand", "xr", "left_valid", "right_valid", "bobber_visible", "bait_visible", "golf_stowed"]
static var locations: Array = []

static func location_table() -> Array:
	if locations.is_empty():
		locations = State.Fish.LOCATION_SPECIES.keys()
		for course in Locations.Courses.ALL:
			locations.append(Locations.clubhouse(course))
			for hole in 18: locations.append(Locations.location(course, hole))
		locations.sort()
	return locations

static func newer(serial: int, previous: int) -> bool:
	var distance := (serial - previous) & 0x7fffffff
	return distance > 0 and distance < 0x40000000

static func vector(stream: StreamPeerBuffer, value: Vector3) -> void:
	stream.put_float(value.x); stream.put_float(value.y); stream.put_float(value.z)

static func read_vector(stream: StreamPeerBuffer) -> Vector3:
	return Vector3(stream.get_float(), stream.get_float(), stream.get_float())

static func transform(stream: StreamPeerBuffer, value: Transform3D) -> void:
	vector(stream, value.origin)
	var q := value.basis.orthonormalized().get_rotation_quaternion()
	for component in [q.x, q.y, q.z, q.w]: stream.put_16(roundi(component * 32767.0))

static func read_transform(stream: StreamPeerBuffer) -> Transform3D:
	var origin := read_vector(stream)
	var q := Quaternion(stream.get_16()/32767.0, stream.get_16()/32767.0, stream.get_16()/32767.0, stream.get_16()/32767.0)
	# A zero/non-unit wire quaternion must not become a valid identity silently.
	if absf(q.length_squared() - 1.0) > .001: return Transform3D(Basis.IDENTITY, Vector3.INF)
	return Transform3D(Basis(q.normalized()), origin)

static func weights(stream: StreamPeerBuffer, values: PackedFloat32Array) -> void:
	for value in values: stream.put_u8(roundi(value * 255.0))

static func read_weights(stream: StreamPeerBuffer) -> PackedFloat32Array:
	var values := PackedFloat32Array()
	for i in 5: values.append(stream.get_u8()/255.0)
	return values

static func encode(data: Dictionary) -> PackedByteArray:
	if not State.valid(data): return PackedByteArray()
	# Capture deliberately omits per-knuckle rotations; never silently drop input.
	for key in data.body:
		if key not in BODY and key not in ["left_curls", "right_curls"]: return PackedByteArray()
	var s := StreamPeerBuffer.new()
	s.put_u8(FORMAT); s.put_u32(data.serial); s.put_u16(location_table().find(data.location))
	var flags := 0
	for i in FLAGS.size():
		if data[FLAGS[i]]: flags |= 1 << i
	s.put_u8(flags)
	for key in ["state", "rig", "bait", "species", "rod_tier"]: s.put_u8(data[key])
	s.put_u8(data.golf_club + 1)
	# Preserve authoritative reward inputs and exact validation boundaries.
	for key in ["user_height", "length", "reel_angle"]: s.put_double(data[key])
	s.put_u8(roundi(data.curl * 255)); weights(s, data.visemes)
	for key in State.TRANSFORMS: transform(s, data[key])
	for key in State.VECTORS: vector(s, data[key])
	var mask := 0
	for i in BODY.size():
		if data.body.has(BODY[i]): mask |= 1 << i
	if data.body.has("left_curls"): mask |= 1 << 10
	if data.body.has("right_curls"): mask |= 1 << 11
	s.put_u16(mask)
	for i in BODY.size():
		if mask & (1 << i): transform(s, data.body[BODY[i]])
	for key in ["left_curls", "right_curls"]:
		if data.body.has(key): weights(s, data.body[key])
	var face_mask := 0
	if not data.face.is_empty():
		face_mask = 1
		if data.face.has("mouth"): face_mask |= 2
		if data.face.has("expressions"): face_mask |= 4
	s.put_u8(face_mask)
	if face_mask:
		var face: Dictionary = State.Poses.validate_face(data.face)
		for value in [face.look.x, face.look.y, face.blink.x, face.blink.y]: s.put_float(value)
		s.put_u8(int(face.gaze) | (int(face.lids) << 1))
		for key in ["mouth", "expressions"]:
			if face.has(key): weights(s, face[key])
	assert(s.data_array.size() <= MAX_BYTES)
	return s.data_array

static func decode(bytes: PackedByteArray) -> Dictionary:
	# Fixed prefix through body mask: 230 bytes; then body, face-mask and face.
	if bytes.size() < 231 or bytes.size() > MAX_BYTES or bytes[0] != FORMAT: return {}
	var s := StreamPeerBuffer.new(); s.data_array = bytes
	s.get_u8()
	var data := {"serial":s.get_u32(), "body":{}, "face":{}}
	var location := s.get_u16()
	if location >= location_table().size(): return {}
	data.location = locations[location]
	var flags := s.get_u8()
	for i in FLAGS.size(): data[FLAGS[i]] = bool(flags & (1 << i))
	for key in ["state", "rig", "bait", "species", "rod_tier"]: data[key] = s.get_u8()
	data.golf_club = s.get_u8() - 1
	for key in ["user_height", "length", "reel_angle"]: data[key] = s.get_double()
	data.curl = s.get_u8()/255.0; data.visemes = read_weights(s)
	for key in State.TRANSFORMS: data[key] = read_transform(s)
	for key in State.VECTORS: data[key] = read_vector(s)
	var mask := s.get_u16()
	if mask & ~0xfff: return {}
	var body_bytes := 0
	for i in BODY.size():
		if mask & (1 << i): body_bytes += 20
	for i in [10,11]:
		if mask & (1 << i): body_bytes += 5
	if s.get_available_bytes() < body_bytes + 1: return {}
	for i in BODY.size():
		if mask & (1 << i): data.body[BODY[i]] = read_transform(s)
	for i in 2:
		if mask & (1 << (10+i)): data.body[["left_curls", "right_curls"][i]] = read_weights(s)
	var face_mask := s.get_u8()
	if face_mask not in [0,1,3,5,7]: return {}
	var face_bytes := 17 + (5 if face_mask & 2 else 0) + (5 if face_mask & 4 else 0) if face_mask else 0
	if s.get_available_bytes() != face_bytes: return {}
	if face_mask:
		data.face.look = Vector2(s.get_float(), s.get_float())
		data.face.blink = Vector2(s.get_float(), s.get_float())
		var validity := s.get_u8()
		if validity > 3: return {}
		data.face.gaze = bool(validity & 1); data.face.lids = bool(validity & 2)
		if face_mask & 2: data.face.mouth = read_weights(s)
		if face_mask & 4: data.face.expressions = read_weights(s)
	return data if State.valid(data) else {}
