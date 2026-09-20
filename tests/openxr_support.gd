extends SceneTree
## May also run against a Windows PCK with --main-pack and an absolute script path.
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		push_error(label)

func _initialize() -> void:
	check(ProjectSettings.get_setting("xr/openxr/enabled", false), "OpenXR enabled before renderer initialization")
	check(ProjectSettings.get_setting("rendering/rendering_device/driver.windows") == "vulkan", "Windows selects Vulkan")
	check(ProjectSettings.get_setting("rendering/renderer/rendering_method") == "mobile", "Mobile stereo renderer")
	var path: String = ProjectSettings.get_setting("xr/openxr/default_action_map")
	var args := OS.get_cmdline_user_args()
	if "--action-map" in args:
		path = args[args.find("--action-map") + 1]
	var map := load(path) as OpenXRActionMap
	check(map != null, "Saved action map loads")
	if map == null:
		quit(1)
		return
	var actions: Array[OpenXRAction] = []
	for action_set in map.action_sets:
		actions.append_array(action_set.actions)
	for profile in map.interaction_profiles:
		for binding in profile.bindings:
			check(binding.action in actions, "Binding uses a registered action: " + binding.binding_path)
	# Each explicit controller profile must work on its own. A partial Index
	# profile must not depend on a runtime combining it with generic/Touch inputs.
	for profile_path in ["/interaction_profiles/oculus/touch_controller", "/interaction_profiles/valve/index_controller"]:
		var profile := map.find_interaction_profile(profile_path)
		check(profile != null, "Controller profile exists: " + profile_path)
		if profile == null: continue
		for hand in ["left", "right"]:
			var inputs := {}
			for binding in profile.bindings:
				if binding.binding_path.begins_with("/user/hand/" + hand + "/"):
					inputs[binding.action.resource_name] = binding.binding_path
			for action in ["default_pose", "aim_pose", "grip_pose", "trigger", "trigger_click", "grip", "primary", "primary_click", "ax_button", "by_button", "haptic"]:
				check(inputs.has(action), "%s %s binds %s" % [profile_path, hand, action])
			check(str(inputs.get("grip_pose", "")).ends_with("/input/grip/pose"), "Controller grip uses the grip pose")
			check(str(inputs.get("aim_pose", "")).ends_with("/input/aim/pose"), "Controller ray uses the aim pose")
			check(str(inputs.get("haptic", "")).ends_with("/output/haptic"), "Controller has haptic output")
	print("OPENXR_SUPPORT_RESULT ", JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
