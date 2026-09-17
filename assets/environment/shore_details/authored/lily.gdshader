shader_type spatial;
render_mode cull_disabled;
varying float shade;
void vertex(){
 shade=INSTANCE_CUSTOM.x;
 vec3 at=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 VERTEX.y+=sin(TIME*.7+at.x*.8+at.z)*.003;
}
void fragment(){
 vec2 q=UV*2.0-1.0;
 float radial=length(q);
 float phase=atan(q.y,q.x)*9.0+radial*2.0;
 float vein=pow(max(0.0,cos(phase)),18.0)*(1.0-smoothstep(.25,1.4,fwidth(phase)));
 ALBEDO=mix(vec3(.035,.085,.018),vec3(.12,.19,.045),shade)*mix(.65,1.0,smoothstep(.05,.7,radial));
 ALBEDO+=vec3(.018,.026,.005)*vein;
 ROUGHNESS=.43;SPECULAR=.3;
}
void light(){
 float peak=max(LIGHT_COLOR.r,max(LIGHT_COLOR.g,LIGHT_COLOR.b));
 DIFFUSE_LIGHT+=LIGHT_COLOR/max(1.0,peak/2.5)*max(dot(NORMAL,LIGHT),0.0)*ATTENUATION/3.14159265;
}
