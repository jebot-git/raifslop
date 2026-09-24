shader_type spatial;
render_mode cull_disabled;
uniform vec3 deep_color : source_color = vec3(.10,.24,.25);
varying vec3 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 p=world.xz;
 float distance_to_view=length(p-CAMERA_POSITION_WORLD.xz);
 float detail=1.0-smoothstep(15.0,100.0,distance_to_view);
 vec2 slope=vec2(.7,.3)*cos(dot(p,vec2(.7,.3))+TIME*.55)*.025;
 slope+=vec2(-.4,1.1)*cos(dot(p,vec2(-.4,1.1))-TIME*.73)*.018;
 slope+=vec2(2.3,-1.7)*cos(dot(p,vec2(2.3,-1.7))+TIME)*.006*detail;
 slope*=1.0-smoothstep(40.0,180.0,distance_to_view);
 vec3 normal=normalize(vec3(-slope.x,1.0,-slope.y));
 NORMAL=normalize((VIEW_MATRIX*vec4(normal,0.0)).xyz);
 float fresnel=pow(1.0-clamp(dot(NORMAL,VIEW),0.0,1.0),5.0);
 ALBEDO=mix(deep_color,vec3(.32,.45,.48),fresnel*.4);
 ROUGHNESS=.24;METALLIC=.12;SPECULAR=.65;
}
