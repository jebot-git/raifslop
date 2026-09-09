shader_type spatial;
render_mode cull_disabled;
uniform vec3 deep_color : source_color = vec3(0.025, 0.15, 0.17);
void vertex() {
	VERTEX.y += sin(VERTEX.x * 1.9 + TIME * 0.7) * 0.018 + cos(VERTEX.z * 2.1 + TIME * 0.5) * 0.014;
}
void fragment() {
	float ripple = sin(UV.x * 560.0 + TIME) * cos(UV.y * 480.0 - TIME * 0.6);
	ALBEDO = deep_color + ripple * 0.018;
	METALLIC = 0.65;
	ROUGHNESS = 0.22;
	NORMAL_MAP = vec3(0.5 + ripple * 0.08, 0.5 + cos(UV.y * 500.0 + TIME) * 0.06, 1.0);
}
