shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
void fragment() {
 vec2 p=(UV-.5)*2.0;
 float body=exp(-dot(p*vec2(1.3,1.0),p*vec2(1.3,1.0))*3.5);
 ALBEDO=vec3(.025,.033,.032);
 ALPHA=body*.4*(1.0-smoothstep(.65,1.0,length(p)));
}
