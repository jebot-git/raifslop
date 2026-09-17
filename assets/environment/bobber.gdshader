shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
void fragment(){
	ALBEDO=COLOR.rgb;
	ROUGHNESS=COLOR.a;
	METALLIC=UV.x;
	SPECULAR=.42;
	CLEARCOAT=.5*(1.0-UV.x);
	CLEARCOAT_ROUGHNESS=.23;
}
