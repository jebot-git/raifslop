shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec2 heading = vec2(0.0, -1.0);
uniform float clock = 0.0;
uniform float strength = 0.0;
uniform bool directional = false;
uniform bool burst = false;
void fragment() {
 vec2 p=(UV-.5)*8.0;
 float r=length(p);
 float ring=pow(max(0.0,cos(r*15.0-clock*9.0)),12.0);
 float foam=ring*exp(-r*1.9)*smoothstep(.08,.24,r);
 if(directional) {
  float along=dot(p,heading);
  float side=abs(dot(p,vec2(-heading.y,heading.x)));
  // A bow at the moving nose, opening into two diverging wake arms behind it.
  float wake=exp(-pow((side+along*.48)*14.0,2.0));
  foam+=wake*smoothstep(.0,.25,-along)*(1.0-smoothstep(.2,3.0,-along))*.8;
 }
 if(burst) foam=exp(-pow((r-clock*1.7)*14.0,2.0))*max(0.0,1.0-clock/1.8);
 ALBEDO=vec3(.72,.89,.86);
 ALPHA=clamp(foam*strength,0.0,.8)*(1.0-smoothstep(3.0,4.0,r));
}
