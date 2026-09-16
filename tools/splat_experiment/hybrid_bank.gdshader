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
uniform sampler2D panorama : source_color, filter_linear_mipmap, repeat_enable;
varying vec3 bank_world;
varying float apron_weight;
void vertex() {
 bank_world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 vec3 p=bank_world-vec3(0.0,-1.63,-0.65);
 vec2 outside=max(abs(p.xz-vec2(0.0,8.0))-vec2(4.5,2.0),vec2(0.0));
 apron_weight=smoothstep(.5,3.0,length(outside));
}
void fragment() {
 vec3 base=texture(albedo_tex,UV).rgb*base_color.rgb;
 base*=mix(vec3(1.0),vec3(.75,.58,.42),apron_weight);
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
 // Fade the distant mesh's hard rectangular edge into the finite panorama.
 vec3 p=bank_world-vec3(0.0,-1.63,-0.65);
 float edge=max(smoothstep(9.0,18.0,abs(p.x)),smoothstep(17.0,29.0,p.z));
 vec3 ray=normalize(bank_world-CAMERA_POSITION_WORLD);
 float b=dot(CAMERA_POSITION_WORLD,ray);
 float t=-b+sqrt(max(0.0,b*b+22500.0-dot(CAMERA_POSITION_WORLD,CAMERA_POSITION_WORLD)));
 vec3 d=normalize(CAMERA_POSITION_WORLD+ray*t);
 vec2 uv=vec2(fract(atan(d.x,-d.z)/TAU+.5),acos(clamp(d.y,-1.0,1.0))/PI);
 EMISSION=mix(EMISSION,texture(panorama,uv).rgb,edge);
 ALBEDO*=1.0-edge;
 AO=ao;
 AO_LIGHT_AFFECT=.1;
}
void light() {
 if(dynamic_shadows) DIFFUSE_LIGHT+=baked_sun*ATTENUATION;
}
