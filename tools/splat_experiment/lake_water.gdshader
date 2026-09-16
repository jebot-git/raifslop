shader_type spatial;
// Opaque lake surface: this experiment has no underwater fish window.
// Blend the boundary color to the same finite panorama sphere used behind it.
render_mode unshaded, cull_disabled, depth_draw_opaque;
#include "res://shaders/panorama_sampling.gdshaderinc"
uniform sampler2D hooked_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec3 hooked_position = vec3(0.0);
uniform float hooked_radius = .5;
uniform float hooked_visibility = 0.0;
uniform mat3 sky_inverse = mat3(1.0);
uniform float sky_energy = 0.8;
uniform vec3 deep_color : source_color = vec3(0.025, 0.15, 0.17);
uniform float water_roughness : hint_range(0.05, 1.0) = 0.22;
uniform float river_flow = 0.0;
uniform float ripple_strength : hint_range(0.0, 1.5) = 1.0;
uniform float blend_start = 14.0;
uniform float blend_end = 45.0;
uniform bool protect_panorama_foreground = false;
uniform bool replace_near_jetty = false;
uniform bool coastal_foreground = false;
uniform bool beach_sides = false;
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
 // The infinite test plane cut through dry land and overpainted splat banks.
 // Bound this lake in world coordinates; the terrain apron covers the join.
 if (world_position.z > 6.3 || world_position.x > 7.0) discard;
 float shoreline_weight=(1.0-smoothstep(4.8,6.3,world_position.z))*(1.0-smoothstep(5.3,7.0,world_position.x));
	vec2 p = world_position.xz-vec2(TIME*river_flow,0.0);
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
	near_water+=vec3(.045,.06,.05)*pow(max(0.0,sin(p.x*4.0+p.y*.7+sin(p.y*2.0))*sin(p.y*7.0+sin(p.x*.9))),8.0)*min(river_flow,.7);
	float distant = smoothstep(blend_start,blend_end,distance_to_view);
	if (beach_sides) {
		// Keep the central animated water; join photographed surf sooner along the sides.
		distant=max(distant,smoothstep(3.5,9.0,abs(world_position.x))*smoothstep(4.0,14.0,distance_to_view));
	}
	float ray_b = dot(CAMERA_POSITION_WORLD,incident);
 float ray_t = -ray_b+sqrt(max(0.0,ray_b*ray_b+150.0*150.0-dot(CAMERA_POSITION_WORLD,CAMERA_POSITION_WORLD)));
 vec3 sphere_direction = normalize(CAMERA_POSITION_WORLD+incident*ray_t);
 vec3 photograph = panorama_sample(sky_inverse * sphere_direction, true) * sky_energy;
	if (protect_panorama_foreground) {
		vec2 uv = panorama_uv(sky_inverse * incident);
		vec4 r = panorama_water_region;
		float open_water = smoothstep(r.x,r.x+.015,uv.x)*(1.0-smoothstep(r.y-.015,r.y,uv.x));
		open_water *= smoothstep(r.z,r.z+.004,uv.y)*(1.0-smoothstep(r.w-.008,r.w,uv.y));
		// The near photographed rails have a real 3D replacement. Cover those
		// low-angle foreground pixels, preserving the distant marina and markers.
		float near_jetty = replace_near_jetty ? smoothstep(.54,.565,uv.y) : 0.0;
		// The photographed walkway runs to the right of the reconstructed head.
		// Keep it dry; only the front-facing obsolete rails need replacement.
		near_jetty *= 1.0-smoothstep(.32,.65,incident.x);
		if (replace_near_jetty) {
			// Hide the old photographic floor/rail immediately below the 3D head,
			// while retaining the right walkway once it leaves that footprint.
			near_jetty=max(near_jetty,(1.0-smoothstep(3.8,5.8,distance_to_view))*smoothstep(.60,.65,uv.y));
		}
		// A real surface at the terrace foot conceals the photographed high rocks
		// under it, which otherwise make the 3D terrace appear suspended in air.
		float coast = coastal_foreground ? (1.0-smoothstep(10.0,24.0,distance_to_view))
			*(1.0-smoothstep(-1.0,4.0,world_position.z)) : 0.0;
		float replacement = max(near_jetty,coast);
		open_water=max(open_water,replacement);
		distant = max(distant,1.0-open_water);
		// Keep photographic exposure and wave scale at this close harbour.
		// A restrained moving reflection avoids a bright patch at the mask edge.
		near_water = mix(photograph,near_water,mix(.12,1.0,replacement));
	}
	// At the mesh boundary, use the very same photographed water visible behind it.
	ALBEDO = mix(near_water, photograph, distant);
	ALBEDO=mix(photograph,ALBEDO,shoreline_weight);
}
