extends ShaderMaterial
## One production 8K sky path, shared colour processing with the water shader.
var panorama: Texture2D:
	set(value):
		panorama=value
		set_shader_parameter("panorama",value)
func _init() -> void:
	shader=preload("res://shaders/panorama_detail.gdshader")
	set_shader_parameter("detail_strength",.5)
	set_shader_parameter("vibrance",1.025)
	set_shader_parameter("shadow_lift",.015)
