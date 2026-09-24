shader_type spatial;
render_mode ambient_light_disabled;
uniform sampler2D cover : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D gravel : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D grass : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D grass_normal : hint_normal,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D gravel_normal : hint_normal,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D grass_roughness : hint_default_white,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D irradiance : filter_linear_mipmap,repeat_disable;
uniform sampler2D bank_ao : hint_default_white,filter_linear_mipmap,repeat_disable;
uniform bool has_bake=false;
uniform float ambient_fill=.18;
uniform float snow_cover=0.0;
varying vec3 world;
varying float bake_weight;
void vertex(){
 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 bake_weight=has_bake ? (1.0-smoothstep(43.0,47.0,abs(world.x)))*(1.0-smoothstep(15.0,19.0,world.z))*smoothstep(-49.0,-45.0,world.z) : 0.0;
}
void fragment(){
 vec2 uv=world.xz*.45;
 // Broad photographic variation breaks the tiling without more geometry.
 vec3 growth=texture(grass,uv*.63).rgb;
 growth=mix(growth,texture(grass,vec2(-uv.y,uv.x)*.37+vec2(.31,.67)).rgb,.38);
 growth=mix(vec3(dot(growth,vec3(.2126,.7152,.0722))),growth,.76)*vec3(.84,1.0,.89);
 growth*=mix(vec3(.65,.72,.55),vec3(.94,.96,.84),texture(cover,uv*.073).g);
 vec3 stones=texture(gravel,uv*.8).rgb;
 float irregular=sin(world.x*1.7+sin(world.z*2.3))*.14+sin(world.x*.38+world.z*.8)*.2;
 float blend=smoothstep(-.1,.7,world.y+irregular);
 float wet=1.0-smoothstep(-.32,-.04,world.y+irregular*.12);
 ALBEDO=mix(stones*.68,growth*.8,blend)*mix(1.0,.53,wet);
 float snow=snow_cover*smoothstep(.3,1.3,world.y+irregular*2.5);
 ALBEDO=mix(ALBEDO,vec3(.71,.78,.82)*mix(.92,1.0,texture(gravel,uv*1.7).r),snow);
 NORMAL_MAP=normalize(mix(texture(gravel_normal,uv*.8).rgb*2.0-1.0,texture(grass_normal,uv*.63).rgb*2.0-1.0,blend))*.5+.5;
 NORMAL_MAP_DEPTH=mix(.55,.12,snow);
 ROUGHNESS=mix(mix(.9,max(.72,texture(grass_roughness,uv*.63).g),blend),.36,wet);
 SPECULAR=mix(.22,.42,wet);
 AO=mix(.82,1.0,smoothstep(.02,.18,dot(stones,vec3(.333))));
 AO_LIGHT_AFFECT=.25;
 vec2 bake_uv=vec2((world.x+48.0)/96.0,1.0-(world.z+50.0)/70.0);
 float contact=mix(1.0,texture(bank_ao,bake_uv).r,bake_weight*.6);
 // Irradiance already contains measured sun and canopy shadows: never light twice.
 vec3 baked=texture(irradiance,bake_uv).rgb*.86;
 float microshade=clamp(1.0+(NORMAL_MAP.x-.5)*.2+(NORMAL_MAP.y-.5)*.16,.87,1.13);
 EMISSION=ALBEDO*mix(vec3(ambient_fill),baked*microshade,bake_weight)*contact;
}
void light(){
 DIFFUSE_LIGHT+=ALBEDO*LIGHT_COLOR*ATTENUATION*max(dot(NORMAL,LIGHT),0.0)*(1.0-bake_weight)/PI;
 vec3 halfway=normalize(LIGHT+VIEW);
 SPECULAR_LIGHT+=LIGHT_COLOR*ATTENUATION*pow(max(dot(NORMAL,halfway),0.0),24.0)*.025*(1.0-ROUGHNESS);
}
