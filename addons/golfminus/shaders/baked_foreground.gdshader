shader_type spatial;
render_mode ambient_light_disabled;
#include "res://addons/golfminus/shaders/panorama_sampling.gdshaderinc"
// Hoek's sand/photo blend must write opaque depth before shallow water.
uniform bool ground_projection = false;
uniform mat3 sky_inverse = mat3(1.0);
uniform float sky_energy = 1.0;
uniform vec4 ground_bounds = vec4(0.0,3.0,5.0,6.0);
uniform vec3 projection_origin = vec3(0.0,1.65,.65);
uniform vec2 transition_width = vec2(6.0);
varying vec3 world_position;
void vertex() { world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D irradiance_tex : filter_linear_mipmap, repeat_disable;
uniform sampler2D sky_tex : filter_linear_mipmap, repeat_disable;
uniform sampler2D occlusion_tex : hint_default_white, filter_linear_mipmap, repeat_disable;
uniform vec4 base_color : source_color = vec4(1.0);
// A modest exposure reduction; keep the source HDR range and colour intact.
uniform float bake_energy = .86;
uniform float roughness_floor = .7;
uniform float normal_depth = .28;
uniform float metal = 0.0;
uniform bool has_roughness = false;
uniform vec3 sun_direction = vec3(0.0,1.0,0.0);
uniform vec4 rough_channel = vec4(1.0,0.0,0.0,0.0);
void fragment() {
 vec3 base=texture(albedo_tex,UV).rgb*base_color.rgb;
 float ao=mix(1.0,texture(occlusion_tex,UV2).r,.35);
 ALBEDO=base;
 ROUGHNESS=has_roughness ? max(roughness_floor,dot(texture(rough_tex,UV),rough_channel)) : roughness_floor;
 METALLIC=metal;
 SPECULAR=.28;
 NORMAL_MAP=texture(normal_tex,UV).rgb;
 NORMAL_MAP_DEPTH=normal_depth;
 // Full HDR irradiance contains sky fill and static sun occlusion.
 vec3 total=texture(irradiance_tex,UV2).rgb;
 vec3 sky=texture(sky_tex,UV2).rgb;
 // Retain baked occlusion while letting normal-map grain shape the baked sun.
 // This is bounded because UV2 has no directional irradiance basis.
 vec3 sun_view=normalize(mat3(VIEW_MATRIX)*sun_direction);
 vec3 detail=normalize(mix(vec3(0.0,0.0,1.0),NORMAL_MAP*2.0-1.0,normal_depth));
 vec3 detail_normal=normalize(TANGENT*detail.x+BINORMAL*detail.y+NORMAL*detail.z);
 float response=clamp((max(dot(detail_normal,sun_view),0.0)+.2)/(max(dot(NORMAL,sun_view),0.0)+.2),.75,1.25);
 EMISSION=base*(min(sky,total)+max(total-sky,vec3(0.0))*response)*ao*bake_energy;
 if (ground_projection) {
  vec2 outside_ground=max(abs(world_position.xz-ground_bounds.xy)-ground_bounds.zw,vec2(0.0));
  float photo_weight=max(smoothstep(.5,transition_width.x,outside_ground.x),smoothstep(.5,transition_width.y,outside_ground.y));
  vec3 incident=normalize(world_position-projection_origin);
  float far_blend=smoothstep(45.0,85.0,length(world_position.xz-projection_origin.xz));
  incident=normalize(mix(incident,-normalize(mat3(INV_VIEW_MATRIX)*VIEW),far_blend));
  EMISSION=mix(EMISSION,panorama_sample(sky_inverse*incident,true)*sky_energy,photo_weight);
  ROUGHNESS=mix(ROUGHNESS,1.0,photo_weight);
 }
 AO=ao;
 AO_LIGHT_AFFECT=.1;
}
void light() {
 // Diffuse is baked; only the view-dependent restrained sheen remains dynamic.
 vec3 halfway=normalize(LIGHT+VIEW);
 float highlight=pow(max(dot(NORMAL,halfway),0.0),mix(48.0,8.0,ROUGHNESS));
 SPECULAR_LIGHT+=LIGHT_COLOR*ATTENUATION*highlight*(1.0-ROUGHNESS)*.025;
}
