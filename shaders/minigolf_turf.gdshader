shader_type spatial;
render_mode diffuse_burley;
uniform vec4 turf_color : source_color = vec4(0.19,0.39,0.25,1.0);
uniform float ambient_fill = 0.0;
uniform bool has_lightmap=false;
uniform sampler2D irradiance:filter_linear_mipmap,repeat_disable;
uniform sampler2D occlusion:filter_linear_mipmap,repeat_disable;
void fragment() {
	vec2 fibers = UV * 350.0;
	float grain = fract(sin(dot(floor(fibers), vec2(12.9898,78.233))) * 43758.5453);
	vec2 footprint=fwidth(fibers);
	grain=mix(.5,grain,1.0-smoothstep(.5,1.5,max(footprint.x,footprint.y)));
	float stripe = mix(0.96, 1.04, step(0.5, fract(UV.y * 0.5)));
	ALBEDO = turf_color.rgb * stripe * mix(0.96, 1.04, grain);
	EMISSION = ALBEDO * ambient_fill;
	if(has_lightmap){EMISSION=ALBEDO*texture(irradiance,UV2).rgb*.86;ALBEDO=vec3(0.0);SPECULAR=0.0;}
	ROUGHNESS = 0.94;
}
