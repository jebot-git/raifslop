shader_type spatial;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D occlusion_tex : hint_default_white, filter_linear_mipmap;
varying vec3 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 float wet=1.0-smoothstep(-.3,.08,world.y);
 vec3 stone=texture(albedo_tex,UV).rgb;
 ALBEDO=stone*mix(.85,.38,wet);
 NORMAL_MAP=texture(normal_tex,UV*3.0).rgb;
 NORMAL_MAP_DEPTH=.24;
 ROUGHNESS=mix(.87,.32,wet);
 SPECULAR=mix(.25,.45,wet);
 AO=texture(occlusion_tex,UV).r;
 AO_LIGHT_AFFECT=.35;
}
