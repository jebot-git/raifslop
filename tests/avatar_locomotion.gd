extends SceneTree
const Library = preload("res://scripts/avatar_library.gd")
const IK = preload("res://scripts/avatar_ik.gd")
const Motor = preload("res://scripts/locomotion.gd")
var failures := 0
var checks := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for path in Library.DEFAULTS:
		var info := Library.inspect(path)
		check(not info.has("error"), "Bundled VRM must validate: " + path)
		check(info.get("size", 0) <= 25_000_000, "Bundled VRM must respect 25 MB")
	var oversized := "user://oversized_validation.vrm"
	var file := FileAccess.open(oversized, FileAccess.WRITE)
	file.seek(25_000_000)
	file.store_8(0)
	file.close()
	check(Library.inspect(oversized).get("error", "").contains("25 MB"), "Oversized VRM rejected before decode")
	var lib := Library.new()
	check(lib.import_file(oversized).has("error") and lib.entries.is_empty(), "Oversized import must not enter the library")
	DirAccess.remove_absolute(oversized)
	var boundary := "user://boundary_validation.vrm"
	file = FileAccess.open(boundary, FileAccess.WRITE)
	file.seek(24_999_999)
	file.store_8(0)
	file.close()
	check(not Library.inspect(boundary).get("error", "").contains("25 MB"), "Exactly 25,000,000 bytes passes the size gate")
	DirAccess.remove_absolute(boundary)
	var invalid := "user://invalid_validation.vrm"
	file = FileAccess.open(invalid, FileAccess.WRITE)
	file.store_string("Not a VRM")
	file.close()
	check(Library.inspect(invalid).has("error"), "Malformed VRM rejected")
	DirAccess.remove_absolute(invalid)
	check(Motor.deadzone(Vector2(0.1, 0.1)) == Vector2.ZERO, "Controller drift deadzone")
	check(Motor.deadzone(Vector2(1, 1)).length() <= 1.001, "Diagonal speed is bounded")
	var elbow := IK.elbow_position(Vector3.ZERO, Vector3(0.4, 0, 0), Vector3(0, -1, 0), 0.3, 0.3)
	check(absf(elbow.length() - 0.3) < 0.001 and absf(elbow.distance_to(Vector3(0.4, 0, 0)) - 0.3) < 0.001, "IK preserves both limb lengths")
	check(IK.elbow_position(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, 0.3, 0.3).is_finite(), "Coincident IK target remains finite")
	var scene: PackedScene = load("res://scenes/main.tscn")
	var g = scene.instantiate()
	root.add_child(g)
	current_scene = g
	for i in range(12): await process_frame
	check(is_instance_valid(g.avatar), "Default VRM instantiated with IK")
	if not is_instance_valid(g.avatar):
		quit(1)
		return
	var original_path: String = g.avatars.selected_path
	var original_avatar = g.avatar
	await g._select_avatar("res://assets/models/rods/reed.glb")
	check(g.avatar == original_avatar and g.avatars.selected_path == original_path, "Invalid selection preserves active avatar")
	await g._select_avatar(Library.DEFAULTS[1])
	check(g.avatars.selected_path == Library.DEFAULTS[1] and g.avatar != original_avatar, "Second bundled avatar can be equipped")
	var config := ConfigFile.new()
	config.load("user://avatar.cfg")
	check(config.get_value("avatar", "path") == Library.DEFAULTS[1], "Avatar selection persists")
	var cache_path: String = Library.CACHE + FileAccess.get_sha256(Library.DEFAULTS[0]) + ".vrm"
	var existed := FileAccess.file_exists(cache_path)
	var imported: Dictionary = g.avatars.import_file(Library.DEFAULTS[0])
	check(not imported.has("error") and FileAccess.file_exists(cache_path), "Custom import is copied into persistent library")
	await g._select_avatar(imported.get("path", Library.DEFAULTS[0]))
	check(g.avatars.selected_path == cache_path, "Runtime VRM plugin loads a user library file")
	g._update_avatar(0.016)
	var sk: Skeleton3D = g.avatar.skeleton
	g.avatar.solver._process_modification_with_delta(0.016)
	var hand: Vector3 = sk.to_global(sk.get_bone_global_pose(sk.find_bone("RightHand")).origin)
	check(hand.distance_to(g.rod.global_position) < 0.16, "Right-hand IK reaches the rod grip")
	check(g.head.cull_mask & 3 == 3 and g.head.cull_mask & 4 == 0, "First-person camera includes world/body and excludes head-only layer")
	for i in range(10): await physics_frame
	var start: Vector3 = g.head.global_position
	g.motor.turn(deg_to_rad(30))
	check(g.head.global_position.distance_to(start) < 0.001, "Snap turn pivots around head without orbiting")
	g.motor.turn(deg_to_rad(-30))
	key(KEY_W, true)
	for i in range(190): await physics_frame
	key(KEY_W, false)
	check(g.motor.global_position.z > -2.2 and g.motor.global_position.z < -1.5, "Cove edge collision stops walking into lake")
	key(KEY_S, true)
	for i in range(410): await physics_frame
	key(KEY_S, false)
	check(g.motor.global_position.z > 5.0 and absf(g.motor.global_position.y) < 0.2, "Player walks across solid gravel shore")
	g._toggle_avatar_menu()
	var paused: Vector3 = g.motor.global_position
	key(KEY_D, true)
	for i in range(30): await physics_frame
	key(KEY_D, false)
	check(g.motor.global_position.distance_to(paused) < 0.001, "Avatar menu pauses locomotion")
	g._toggle_avatar_menu()
	await g._select_avatar(original_path)
	if not existed: DirAccess.remove_absolute(cache_path)
	print("Avatar and locomotion tests: %d checks, %d failures" % [checks, failures])
	g.queue_free()
	await process_frame
	await create_timer(.3).timeout
	quit(1 if failures else 0)
