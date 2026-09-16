shader_type spatial;
render_mode ambient_light_disabled;
uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D irradiance_tex : filter_linear_mipmap, repeat_disable;
uniform sampler2D sky_tex : filter_linear_mipmap, repeat_disable;
uniform sampler2D occlusion_tex : hint_default_white, filter_linear_mipmap, repeat_disable;
uniform vec4 base_color : source_color = vec4(1.0);
uniform float roughness_floor = .7;
uniform float normal_depth = .28;
uniform float metal = 0.0;
uniform bool has_roughness = false;
uniform bool dynamic_shadows = false;
varying vec3 baked_sun;
uniform vec4 rough_channel = vec4(1.0,0.0,0.0,0.0);
uniform vec4 ground_bounds=vec4(0.0,1.5,2.8,3.3);
uniform float ground_rounding=0.0;
varying vec3 ground_position;
void vertex(){ground_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz-vec3(0.0,-1.63,-.65);}
void fragment() {
 vec2 outside=abs(ground_position.xz-ground_bounds.xy)-ground_bounds.zw;
 vec2 rounded=outside+vec2(ground_rounding);
 float edge=length(max(rounded,vec2(0.0)))+min(max(rounded.x,rounded.y),0.0)-ground_rounding;
 if(edge>0.0) discard;
 vec3 base=texture(albedo_tex,UV).rgb*base_color.rgb;
 float ao=mix(1.0,texture(occlusion_tex,UV2).r,.25);
 ALBEDO=base;
 ROUGHNESS=has_roughness ? max(roughness_floor,dot(texture(rough_tex,UV),rough_channel)) : roughness_floor;
 METALLIC=metal;
 SPECULAR=.28;
 NORMAL_MAP=texture(normal_tex,UV).rgb;
 NORMAL_MAP_DEPTH=normal_depth;
 // Static shadows remain baked in both modes. Dynamic mode adds actor occlusion.
 vec3 total=texture(irradiance_tex,UV2).rgb;
 vec3 sky_fill=texture(sky_tex,UV2).rgb;
 baked_sun=max(total-sky_fill,vec3(0.0))*ao;
 EMISSION=base*(dynamic_shadows ? sky_fill : total)*ao;
 AO=ao;
 AO_LIGHT_AFFECT=.1;
}
void light() {
 if(dynamic_shadows) DIFFUSE_LIGHT+=baked_sun*ATTENUATION;
}
