shader_type spatial;
render_mode ambient_light_disabled;
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
uniform vec4 rough_channel = vec4(1.0,0.0,0.0,0.0);
void fragment() {
 vec3 base=texture(albedo_tex,UV).rgb*base_color.rgb;
 float ao=mix(1.0,texture(occlusion_tex,UV2).r,.25);
 ALBEDO=base;
 ROUGHNESS=has_roughness ? max(roughness_floor,dot(texture(rough_tex,UV),rough_channel)) : roughness_floor;
 METALLIC=metal;
 SPECULAR=.28;
 NORMAL_MAP=texture(normal_tex,UV).rgb;
 NORMAL_MAP_DEPTH=normal_depth;
 // Full HDR irradiance contains sky fill and static sun occlusion.
 vec3 total=texture(irradiance_tex,UV2).rgb;
 EMISSION=base*total*ao*bake_energy;
 AO=ao;
 AO_LIGHT_AFFECT=.1;
}
void light() {
 // Foreground illumination is already baked, including direct sun.
}
