shader_type spatial;
render_mode unshaded, cull_disabled;
#include "res://shaders/panorama_sampling.gdshaderinc"
uniform mat3 sky_inverse = mat3(1.0);
uniform float sky_energy = 0.8;
uniform vec3 deep_color : source_color = vec3(0.025, 0.15, 0.17);
uniform float water_roughness : hint_range(0.05, 1.0) = 0.22;
uniform float ripple_strength : hint_range(0.0, 1.5) = 1.0;
uniform float blend_start = 14.0;
uniform float blend_end = 45.0;
uniform bool protect_panorama_foreground = false;
// Authored in panorama UVs: only clear open water may receive animated reflections.
// Outside this feathered region preserve the actual jetty, markers and shoreline.
uniform vec4 panorama_water_region = vec4(0.0, 1.0, 0.0, 1.0);
varying vec3 world_position;
vec3 environment_color(vec3 direction) {
	return panorama_sample(sky_inverse * direction, false) * sky_energy;
}
void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(dot(world.xz, vec2(.45, .22)) + TIME*.55) * .008 * ripple_strength;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 p = world_position.xz;
	// Analytic wave slopes in metres, independent of mesh UV size.
	vec2 slope = vec2(.45,.22) * cos(dot(p,vec2(.45,.22))+TIME*.55) * .008;
	slope += vec2(2.3,.8) * cos(dot(p,vec2(2.3,.8))-TIME*1.1) * .011;
	slope += vec2(-1.4,3.7) * cos(dot(p,vec2(-1.4,3.7))+TIME*.83) * .006;
	slope += vec2(7.1,-4.2) * cos(dot(p,vec2(7.1,-4.2))-TIME*1.4) * .0018;
	vec3 normal = normalize(vec3(-slope.x*ripple_strength, 1.0, -slope.y*ripple_strength));
	vec3 incident = -normalize(mat3(INV_VIEW_MATRIX)*VIEW);
	vec3 reflected = reflect(incident, normal);
	vec3 reflection = environment_color(reflected);
	// A small angular footprint softens hard HDR detail without screen-space reflections.
	float blur = water_roughness * .018;
	reflection = (reflection*2.0 + environment_color(normalize(reflected+vec3(blur,0.0,blur)))
		+ environment_color(normalize(reflected-vec3(blur,0.0,blur)))) * .25;
	float fresnel = .0204 + .9796 * pow(1.0-clamp(dot(-incident,normal),0.0,1.0),5.0);
	vec3 near_water = mix(deep_color*.32, reflection, fresnel);
	float distance_to_view = length(world_position.xz-CAMERA_POSITION_WORLD.xz);
	float distant = smoothstep(blend_start,blend_end,distance_to_view);
	vec3 photograph = panorama_sample(sky_inverse * incident, true) * sky_energy;
	if (protect_panorama_foreground) {
		vec2 uv = panorama_uv(sky_inverse * incident);
		vec4 r = panorama_water_region;
		float open_water = smoothstep(r.x,r.x+.015,uv.x)*(1.0-smoothstep(r.y-.015,r.y,uv.x));
		open_water *= smoothstep(r.z,r.z+.004,uv.y)*(1.0-smoothstep(r.w-.008,r.w,uv.y));
		distant = max(distant,1.0-open_water);
		// Keep photographic exposure and wave scale at this close harbour.
		// A restrained moving reflection avoids a bright patch at the mask edge.
		near_water = mix(photograph,near_water,.12);
	}
	// At the mesh boundary, use the very same photographed water visible behind it.
	ALBEDO = mix(near_water, photograph, distant);
}
