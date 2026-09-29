extends Node3D
## Editor/MCP preview, independent of XR startup and saved player data.
@export var water:="lakeside"
func _ready()->void:
	var xr:=XRServer.find_interface("OpenXR")
	if xr and xr.is_initialized():xr.uninitialize()
	var world=preload("res://scripts/minigolf/world.gd").new();add_child(world);world.setup(water)
	preload("res://scripts/minigolf/preview_environment.gd").setup(self,water)
	var camera:=Camera3D.new();add_child(camera);camera.position=Vector3(-8,10,34);camera.look_at(Vector3(-14,2,18));camera.fov=65;camera.make_current()
