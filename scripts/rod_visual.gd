extends Node3D
## Shared authored spinning tackle. Anchors stay fixed for casting and controller gestures.
const MODELS = ["willow", "reed", "heron", "kingfisher"]
var tier := -1
var model: Node3D
var crank := Node3D.new()
func _init() -> void:
	name = "RodVisual"
	crank.name = "ReelCrank"
	crank.position = Vector3(-.085,-.075,.04)
	add_child(crank)
	crank.add_child(load("res://assets/models/rods/handle.glb").instantiate())
func equip(index: int) -> void:
	index = clampi(index,0,MODELS.size()-1)
	if tier == index: return
	if is_instance_valid(model):
		remove_child(model)
		model.queue_free()
	model = load("res://assets/models/rods/" + MODELS[index] + ".glb").instantiate()
	add_child(model)
	tier = index
