shader_type spatial;
render_mode unshaded, depth_draw_never;
void fragment(){
 vec2 q=(UV-.5)*2.0;
 float edge=1.0-smoothstep(.2,1.0,length(q));
 ALBEDO=vec3(.025,.021,.015);
 ALPHA=edge*.24;
}
