shader_type spatial;
render_mode unshaded, depth_draw_never, shadows_disabled;
#include "res://shaders/panorama_sampling.gdshaderinc"
uniform mat3 sky_inverse = mat3(1.0);
uniform float sky_energy = 1.0;
uniform vec4 ground_bounds = vec4(0.0,3.0,5.0,6.0);
varying vec3 world_position;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	// Keep the entire walkable quay solid. Blend only the surrounding apron
	// into the photographed mainland, before the distant unbaked terrain starts.
	vec2 outside_quay = max(abs(world_position.xz-ground_bounds.xy)-ground_bounds.zw,vec2(0.0));
	ALPHA = smoothstep(.5,6.0,length(outside_quay));
	vec3 incident = -normalize(mat3(INV_VIEW_MATRIX)*VIEW);
	ALBEDO = panorama_sample(sky_inverse*incident,true)*sky_energy;
}
