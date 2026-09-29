shader_type spatial;
uniform vec4 wood_color : source_color = vec4(0.29,0.22,0.15,1.0);
uniform sampler2D grain_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
uniform float ambient_fill = 0.0;
uniform bool has_lightmap=false;
uniform sampler2D irradiance:filter_linear_mipmap,repeat_disable;
uniform sampler2D occlusion:filter_linear_mipmap,repeat_disable;
void fragment() {
	float plank = world_position.z * 5.0;
	float seam = smoothstep(0.01,0.035,fract(plank)) * (1.0-smoothstep(0.965,0.99,fract(plank)));
	seam=mix(.96,seam,1.0-smoothstep(.05,.5,fwidth(plank)));
	float phase=world_position.x*34.0+sin(world_position.z*80.0)*.6;
	float grain=sin(phase)*.025*(1.0-smoothstep(.5,3.0,fwidth(phase)));
	float variation = fract(sin(floor(plank)*17.32)*4124.12);
	vec3 painted_grain = texture(grain_texture,world_position.xz * vec2(.35,.6)).rgb;
	ALBEDO = wood_color.rgb * painted_grain * (0.92+variation*0.16+grain) * mix(0.6,1.0,seam);
	EMISSION = ALBEDO * ambient_fill;
	if(has_lightmap){EMISSION=ALBEDO*texture(irradiance,UV2).rgb*.86;ALBEDO=vec3(0.0);SPECULAR=0.0;}
	ROUGHNESS = 0.84;
}
