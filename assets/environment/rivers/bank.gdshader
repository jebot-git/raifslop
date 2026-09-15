shader_type spatial;
uniform sampler2D cover : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D gravel : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
varying vec3 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 uv=world.xz*.45;
 vec3 growth=texture(cover,uv).rgb;
 vec3 stones=texture(gravel,uv*.8).rgb;
 float irregular=sin(world.x*1.7+sin(world.z*2.3))*.14+sin(world.x*.38+world.z*.8)*.2;
 float blend=smoothstep(-.1,.7,world.y+irregular);
 ALBEDO=mix(stones*.78,growth,blend);
 ROUGHNESS=.95;SPECULAR=.15;
}
