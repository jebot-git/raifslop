shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D timber : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool rope = false;
void fragment(){
 float phase=UV.y*(rope ? 37.7 : 180.0)+sin(UV.x*18.0)*1.4+(rope ? UV.x*650.0 : 0.0);
 if(!rope && UV.x>2.0){phase=length(UV-vec2(2.5,.5))*85.0;}
 float resolved=1.0-smoothstep(.35,2.0,fwidth(phase));
 float fibre=sin(phase)*resolved;
 vec3 base=texture(timber,vec2(.025+UV.y*.065,UV.x*1.3)).rgb;
 ALBEDO=(rope ? vec3(.33,.26,.16) : mix(base,vec3(.18,.14,.095),.25))*(1.0+fibre*.10);
 NORMAL_MAP=normalize(vec3(fibre*.10,cos(phase)*resolved*.14,1.0))*.5+.5;
 ROUGHNESS=clamp(.83+fibre*.06,.65,.95);
 SPECULAR=.22;
 AO=COLOR.r;
 AO_LIGHT_AFFECT=.55;
}

void light(){
 // The location suns use relative measured HDR radiance. Bound the added
 // props' diffuse response so they sit beside the baked scenery consistently.
 float peak=max(LIGHT_COLOR.r,max(LIGHT_COLOR.g,LIGHT_COLOR.b));
 vec3 radiance=LIGHT_COLOR/max(1.0,peak/2.5);
 DIFFUSE_LIGHT+=radiance*max(dot(NORMAL,LIGHT),0.0)*ATTENUATION/3.14159265;
}
