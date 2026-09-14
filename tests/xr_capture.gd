extends CompositorEffect
## Test-only GPU readback of native stereo buffers, before tonemapping.
var requested := ""
var completed := ""
var views := 0
var results: Array[Image] = []
var lock := Mutex.new()

func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	access_resolved_color = true

func request_capture(label: String) -> void:
	lock.lock()
	requested = label
	lock.unlock()

func _render_callback(_type: int, data: RenderData) -> void:
	lock.lock()
	var label := requested
	requested = ""
	lock.unlock()
	if label.is_empty(): return
	var buffers: RenderSceneBuffersRD = data.get_render_scene_buffers()
	var rd := RenderingServer.get_rendering_device()
	var texture := buffers.get_color_texture()
	var format := rd.texture_get_format(texture)
	var shader_source := RDShaderSource.new()
	shader_source.source_compute = """#version 450
layout(local_size_x=8, local_size_y=8, local_size_z=1) in;
layout(set=0,binding=0) uniform sampler2DArray source_image;
layout(set=0,binding=1,std430) restrict writeonly buffer Pixels { vec4 pixels[]; } output_data;
void main() {
 ivec3 size = textureSize(source_image, 0);
 ivec3 p = ivec3(gl_GlobalInvocationID);
 if (any(greaterThanEqual(p, size))) return;
 output_data.pixels[(p.z*size.y+p.y)*size.x+p.x] = texelFetch(source_image,p,0);
}
"""
	var shader := rd.shader_create_from_spirv(rd.shader_compile_spirv_from_source(shader_source))
	var pipeline := rd.compute_pipeline_create(shader)
	var sampler := rd.sampler_create(RDSamplerState.new())
	var storage := rd.storage_buffer_create(format.width * format.height * buffers.get_view_count() * 16)
	var input := RDUniform.new()
	input.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	input.binding = 0
	input.add_id(sampler)
	input.add_id(texture)
	var output := RDUniform.new()
	output.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	output.binding = 1
	output.add_id(storage)
	var uniforms := rd.uniform_set_create([input, output], shader, 0)
	var commands := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(commands, pipeline)
	rd.compute_list_bind_uniform_set(commands, uniforms, 0)
	rd.compute_list_dispatch(commands, ceili(format.width / 8.0), ceili(format.height / 8.0), buffers.get_view_count())
	rd.compute_list_end()
	var bytes := rd.buffer_get_data(storage)
	var frames: Array[Image] = []
	var stride := format.width * format.height * 16
	for eye in range(buffers.get_view_count()):
		frames.append(Image.create_from_data(format.width, format.height, false, Image.FORMAT_RGBAF, bytes.slice(eye * stride, (eye + 1) * stride)))
	for rid in [uniforms, pipeline, shader, sampler, storage]: rd.free_rid(rid)
	lock.lock()
	views = buffers.get_view_count()
	results = frames
	completed = label
	lock.unlock()
