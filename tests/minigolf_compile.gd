extends SceneTree
func _initialize()->void:
	var failures:=0
	for path in ["res://scripts/main.gd","res://scripts/minigolf/activity.gd","res://scripts/network/state.gd","res://scripts/network/session.gd"]:
		var script:Script=load(path)
		if script==null or not script.can_instantiate():failures+=1
	print("MINIGOLF COMPILE failures: ",failures);quit(failures)
