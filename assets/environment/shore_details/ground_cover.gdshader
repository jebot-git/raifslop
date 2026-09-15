shader_type spatial;
render_mode cull_disabled, depth_draw_never;
uniform sampler2D cover : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float strength=.65;
varying vec3 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 edge=abs(UV-.5)*2.0;
 float irregular=sin(world.x*8.0+sin(world.z*5.0))*.07;
 float opacity=1.0-smoothstep(.45,.98,max(edge.x,edge.y)+irregular);
 ALBEDO=texture(cover,world.xz*.55).rgb;
 ALPHA=opacity*strength;ROUGHNESS=.98;SPECULAR=.1;
}
