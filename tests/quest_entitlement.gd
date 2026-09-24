extends SceneTree
const Gate = preload("res://scripts/quest_entitlement.gd")
class Request extends RefCounted:
	signal completed(message: Object)
	func get_id() -> int: return 1
class Initialization extends RefCounted:
	var result := 0
	func get_result() -> int: return result
class Message extends RefCounted:
	var error := false
	var result := 0
	func is_error() -> bool: return error
	func get_platform_initialize() -> Object:
		var value := Initialization.new()
		value.result = result
		return value
class SDK extends RefCounted:
	var initialization := Request.new()
	var entitlement := Request.new()
	var checks := 0
	var missing_request := false
	func initialize_platform_async(_app_id: String) -> Object: return null if missing_request else initialization
	func entitlement_get_is_viewer_entitled_async() -> Object:
		checks += 1
		return entitlement
var checks := 0
func expect(condition: bool) -> void:
	checks += 1
	if not condition:
		push_error("ENTITLEMENT_TEST_FAILED %d" % checks)
		quit(1)
func _initialize() -> void:
	for scenario in ["success", "denied", "init_error", "init_result", "timeout", "late", "missing_sdk", "missing_id", "null_request", "null_message"]:
		var sdk := SDK.new()
		sdk.missing_request = scenario == "null_request"
		var gate := Gate.new()
		root.add_child(gate)
		var results: Array = []
		gate.completed.connect(func(allowed: bool, reason: String): results.append([allowed, reason]))
		gate.start("" if scenario == "missing_id" else "123456", null if scenario == "missing_sdk" else sdk)
		if scenario in ["missing_id", "missing_sdk", "null_request"]:
			expect(results.size() == 1 and results[0][0] == false)
		else:
			var message := Message.new()
			message.error = scenario == "init_error"
			message.result = -1 if scenario == "init_result" else 0
			sdk.initialization.completed.emit(null if scenario == "null_message" else message)
			if scenario in ["init_error", "init_result", "null_message"]:
				expect(sdk.checks == 0 and results.size() == 1 and results[0][0] == false)
			else:
				expect(sdk.checks == 1 and results.is_empty())
				if scenario in ["timeout", "late"]:
					gate.deadline = 0
					if scenario == "timeout": gate._process(0)
				var answer := Message.new()
				answer.error = scenario == "denied"
				sdk.entitlement.completed.emit(answer)
				expect(results.size() == 1 and results[0][0] == (scenario == "success"))
				gate._process(0)
				expect(results.size() == 1)
		gate.free()
	print("ENTITLEMENT_TEST_PASS checks=", checks)
	quit(0)
