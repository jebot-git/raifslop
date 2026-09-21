shader_type spatial;
// Write depth even when the shallow-fish window enables transparency.
// Shore panorama passes behind the surface must not paint over the water.
render_mode unshaded, cull_disabled, depth_draw_always;
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
uniform sampler2D ripple_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D river_bed : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D bank_cover : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool boulder_pockets = false;
uniform float ripple_strength : hint_range(0.0, 1.5) = 1.0;
uniform float blend_start = 14.0;
uniform float blend_end = 45.0;
uniform bool protect_panorama_foreground = false;
uniform bool replace_near_jetty = false;
uniform bool coastal_foreground = false;
uniform bool beach_sides = false;
uniform bool align_beach_projection = false;
uniform vec3 shore_projection_origin = vec3(0.0,1.65,.65);
uniform bool coastal_shallows = false;
uniform bool sheltered_cove = false;
// Authored in panorama UVs: only clear open water may receive animated reflections.
// Outside this feathered region preserve the actual jetty, markers and shoreline.
uniform vec4 panorama_water_region = vec4(0.0, 1.0, 0.0, 1.0);
varying vec3 world_position;
vec3 environment_color(vec3 direction) {
	return panorama_sample(sky_inverse * direction, false) * sky_energy;
}
float rock_wake(vec2 point, vec2 rock) {
	vec2 q=point-rock;
	float downstream=smoothstep(.5,1.8,q.x)*(1.0-smoothstep(3.0,8.0,q.x));
	float edge=abs(abs(q.y)-(.65+q.x*.13));
	float ribbon=1.0-smoothstep(.05,.23,edge);
	float broken=smoothstep(.2,.75,sin(q.x*5.0-TIME*3.0+q.y*8.0));
	return downstream*ribbon*broken;
}
void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(dot(world.xz, vec2(.45, .22)) + TIME*.55) * .008 * ripple_strength;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 p = world_position.xz-vec2(TIME*river_flow,0.0);
	// Analytic wave slopes in metres, independent of mesh UV size.
	vec2 slope = vec2(.45,.22) * cos(dot(p,vec2(.45,.22))+TIME*.55) * .008;
	slope += vec2(2.3,.8) * cos(dot(p,vec2(2.3,.8))-TIME*1.1) * .011;
	slope += vec2(-1.4,3.7) * cos(dot(p,vec2(-1.4,3.7))+TIME*.83) * .006;
	slope += vec2(7.1,-4.2) * cos(dot(p,vec2(7.1,-4.2))-TIME*1.4) * .0018;
	// Mipmapped capillary detail fades before it becomes subpixel in the headset.
	float distance_to_view = length(world_position.xz-CAMERA_POSITION_WORLD.xz);
	float detail_fade=1.0-smoothstep(5.0,28.0,distance_to_view);
	vec2 micro=texture(ripple_normal,p*.38+vec2(TIME*.017,TIME*.011)).rg*2.0-1.0;
	micro+=texture(ripple_normal,p*.63+vec2(-TIME*.013,TIME*.019)).rg*2.0-1.0;
	slope+=micro*.032*detail_fade;
	vec3 normal = normalize(vec3(-slope.x*ripple_strength, 1.0, -slope.y*ripple_strength));
	vec3 incident = -normalize(mat3(INV_VIEW_MATRIX)*VIEW);
	vec3 reflected = reflect(incident, normal);
	vec3 reflection = environment_color(reflected);
	// A small angular footprint softens hard HDR detail without screen-space reflections.
	float blur = max(water_roughness * .018,min(length(fwidth(reflected))*.75,.04));
	reflection = (reflection*2.0 + environment_color(normalize(reflected+vec3(blur,0.0,blur)))
		+ environment_color(normalize(reflected-vec3(blur,0.0,blur)))) * .25;
	if(river_flow>0.0){
		// Local bank proxy: do not reflect the source panorama's nonexistent lake shore.
		float bank_z=reflected.z<0.0 ? -20.0 : -2.8;
		float ray_distance=(bank_z-world_position.z)/(abs(reflected.z)>.001 ? reflected.z : .001);
		vec3 hit=world_position+reflected*max(ray_distance,0.0);
		float bank_height=reflected.z<0.0 ? 2.2 : .6;
		float bank_mask=(1.0-smoothstep(bank_height-.5,bank_height+.5,hit.y))*step(0.0,ray_distance);
		vec3 bank=texture(bank_cover,vec2(hit.x*.11,hit.y*.2)).rgb*sky_energy*.32;
		reflection=mix(reflection,bank,bank_mask*.85);
	}
	float fresnel = .0204 + .9796 * pow(1.0-clamp(dot(-incident,normal),0.0,1.0),5.0);
	vec3 near_water = mix(deep_color*.32, reflection, fresnel);
	if(river_flow>0.0){
		float edge=sin(world_position.x*.07)*.65+sin(world_position.x*.19)*.2;
		float margin=min(-3.6+edge-world_position.z,world_position.z-(-19.0+edge));
		float shallows=1.0-smoothstep(.05,2.3,margin);
		vec3 bed=texture(river_bed,(world_position.xz+normal.xz*.18)*.36).rgb;
		float caustic=pow(max(0.0,sin(p.x*3.0+sin(p.y*2.2))*sin(p.y*4.4+sin(p.x*1.6))),6.0);
		vec3 transmission=mix(deep_color*.32,bed*vec3(.3,.39,.29)*(1.0+caustic*.28),shallows);
		near_water=mix(transmission,reflection,fresnel);
		float foam=0.0;
		if(boulder_pockets){
			foam=rock_wake(world_position.xz,vec2(-7.0,-10.0));
			foam+=rock_wake(world_position.xz,vec2(5.0,-13.0));
			foam+=rock_wake(world_position.xz,vec2(15.0,-8.0));
		}
		float flecks=smoothstep(.82,.97,sin(p.x*2.3+sin(p.y*3.0))*sin(p.y*14.0));
		foam+=flecks*(1.0-smoothstep(.08,.45,abs(margin-.18)))*.28;
		near_water=mix(near_water,vec3(.32,.37,.31)*sky_energy,clamp(foam*.38,0.0,.55));
	}
	float distant = smoothstep(blend_start,blend_end,distance_to_view);
	// The cove's playable mouth is real water, including the feeding sectors.
	// Anchor coverage to world geometry, not each eye's photographic ray.
	float cove = sheltered_cove ? (1.0-smoothstep(22.0,34.0,distance_to_view))
		*(1.0-smoothstep(9.0,17.0,abs(world_position.x)))
		*(1.0-smoothstep(-5.0,-2.0,world_position.z)) : 0.0;
	if (beach_sides) {
		// Keep the central animated water; join photographed surf sooner along the sides.
		float side_blend=smoothstep(3.5,9.0,abs(world_position.x));
		if(align_beach_projection && world_position.x<0.0){
			// Match the sand apron instead of exposing the photographed beach
			// several metres before the authored ground reaches its blend.
			side_blend=smoothstep(10.5,22.0,-world_position.x);
		}
		distant=max(distant,side_blend*smoothstep(4.0,14.0,distance_to_view));
	}
	vec3 photograph = panorama_sample(sky_inverse * incident, true) * sky_energy;
	if(align_beach_projection){
		float shore_weight=smoothstep(4.0,12.0,-world_position.x)*(1.0-smoothstep(40.0,65.0,distance_to_view));
		vec3 shore_ray=normalize(world_position-shore_projection_origin);
		photograph=mix(photograph,panorama_sample(sky_inverse*shore_ray,true)*sky_energy,shore_weight);
	}
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
			// The maintenance bridge crosses a rear basin, not a concrete apron.
			// World-space coverage is stable between eyes and stops at the quay wall.
			float rear_basin=smoothstep(3.5,5.0,world_position.z)*(1.0-smoothstep(12.0,18.0,world_position.z));
			rear_basin*=1.0-smoothstep(9.0,20.0,abs(world_position.x));
			near_jetty=max(near_jetty,rear_basin);
			// Hide the old photographic floor/rail immediately below the 3D head,
			// while retaining the right walkway once it leaves that footprint.
			near_jetty=max(near_jetty,(1.0-smoothstep(3.8,5.8,distance_to_view))*smoothstep(.60,.65,uv.y));
		}
		// A real surface at the terrace foot conceals the photographed high rocks
		// under it, which otherwise make the 3D terrace appear suspended in air.
		float coast = coastal_foreground ? (1.0-smoothstep(10.0,24.0,distance_to_view))
			*(1.0-smoothstep(-1.0,4.0,world_position.z)) : 0.0;
		float replacement = max(max(near_jetty,coast),cove);
		open_water=max(open_water,replacement);
		distant = max(distant,1.0-open_water);
		// Keep photographic exposure and wave scale at this close harbour.
		// A restrained moving reflection avoids a bright patch at the mask edge.
		near_water = mix(photograph,near_water,mix(.12,1.0,replacement));
	}
	distant *= 1.0-cove;
	// At the mesh boundary, use the very same photographed water visible behind it.
	ALBEDO = mix(near_water, photograph, distant);
	float fish_window=1.0-smoothstep(hooked_radius*.4,hooked_radius,length(world_position.xz-hooked_position.xz));
	// Only reveal shallow geometry at the fish, not a circular hole through the lake bed.
	bool has_depth=false;
	vec3 under_world=world_position-vec3(0.0,1000.0,0.0);
	if(hooked_visibility>0.0 || coastal_shallows){
	float scene_depth=texture(hooked_depth,SCREEN_UV).r;
	#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 under_ndc=vec3(SCREEN_UV,scene_depth)*2.0-1.0;
	#else
	vec3 under_ndc=vec3(SCREEN_UV*2.0-1.0,scene_depth);
	#endif
	vec4 under_view=INV_PROJECTION_MATRIX*vec4(under_ndc,1.0);
	has_depth = scene_depth>0.000001 && abs(under_view.w)>0.000001;
	if (has_depth) under_world=(INV_VIEW_MATRIX*vec4(under_view.xyz/under_view.w,1.0)).xyz;
	fish_window*=1.0-smoothstep(hooked_radius*.4,hooked_radius*.6,length(under_world-hooked_position));
	}
	ALPHA=1.0-hooked_visibility*fish_window*.78*(1.0-fresnel);
	if (coastal_shallows && has_depth && under_world.y<world_position.y && distance_to_view<24.0) {
		// Reveal the actual submerged sand at the contact edge. Depth comes from
		// the authored slope, so the transition follows the irregular shoreline.
		float depth=max(0.0,world_position.y-under_world.y);
		float shallow_span=mix(.38,1.05,align_beach_projection ? smoothstep(6.0,16.0,-world_position.x) : 0.0);
		float sand_edge=smoothstep(.015,shallow_span,depth);
		ALPHA*=mix(sand_edge,1.0,smoothstep(18.0,24.0,distance_to_view));
		// Low, broken wash follows the real submerged slope, in world space.
		// Broad derivative-filtered edges avoid sparkling subpixel foam in VR.
		float wash_depth=.13+.065*sin(TIME*.65+world_position.x*.35);
		// Depth jumps at opaque edges must not widen shoreline foam across
		// distant terrain triangles or mask boundaries.
		float width=clamp(fwidth(depth)*1.5,.035,.08);
		float wash=1.0-smoothstep(width,width+.065,abs(depth-wash_depth));
		float breakup=smoothstep(-.45,.7,sin(world_position.x*7.0+micro.x*2.0)+sin(world_position.z*9.0-TIME*.35));
		wash*=breakup*(1.0-smoothstep(8.0,19.0,distance_to_view))*(1.0-distant)*.30;
		ALBEDO=mix(ALBEDO,vec3(.48,.52,.49)*sky_energy,wash);
		ALPHA=max(ALPHA,wash*.7);
	}
}
