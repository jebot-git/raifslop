shader_type spatial;
render_mode unshaded, depth_draw_never, shadows_disabled;
#include "res://shaders/panorama_sampling.gdshaderinc"
uniform bool authored_bridge = false;
uniform mat3 sky_inverse = mat3(1.0);
uniform float sky_energy = 1.0;
uniform vec4 ground_bounds = vec4(0.0,3.0,5.0,6.0);
uniform vec3 projection_origin = vec3(0.0,1.65,.65);
uniform vec2 transition_width = vec2(6.0);
varying vec3 world_position;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	// Keep the entire walkable quay solid. Blend only the surrounding apron
	// into the photographed mainland, before the distant unbaked terrain starts.
	vec2 outside_quay = max(abs(world_position.xz-ground_bounds.xy)-ground_bounds.zw,vec2(0.0));
	ALPHA = max(smoothstep(.5,transition_width.x,outside_quay.x),smoothstep(.5,transition_width.y,outside_quay.y));
	if (authored_bridge) {
		bool landing = abs(world_position.x)<2.72 && world_position.z>=4.49 && world_position.z<=6.12;
		bool bridge = world_position.x>=-2.16 && world_position.x<=.16 && world_position.z>=6.08 && world_position.z<=12.24;
		if (landing || bridge) ALPHA=0.0;
	}
	// A fixed photographic viewpoint binds the texture to the actual ground.
	// Per-eye VIEW rays instead make that ground appear infinitely far away in VR.
	vec3 incident = normalize(world_position-projection_origin);
	ALBEDO = panorama_sample(sky_inverse*incident,true)*sky_energy;
}
