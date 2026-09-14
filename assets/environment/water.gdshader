shader_type spatial;
render_mode cull_disabled;
uniform vec3 deep_color : source_color = vec3(0.025, 0.15, 0.17);
uniform float water_roughness : hint_range(0.05, 1.0) = 0.22;
uniform float ripple_strength : hint_range(0.0, 1.5) = 1.0;
void vertex() {
	VERTEX.y += (sin(VERTEX.x * 1.9 + TIME * 0.7) * 0.018 + cos(VERTEX.z * 2.1 + TIME * 0.5) * 0.014) * ripple_strength;
}
void fragment() {
	// Unequal travelling directions avoid a repeating checkerboard at shore edges.
	float a = dot(UV, vec2(310.0, 178.0)) + TIME * .7;
	float b = dot(UV, vec2(-143.0, 267.0)) - TIME * .43;
	float c = dot(UV, vec2(523.0, 91.0)) + sin(b) * .5 + TIME;
	float ripple = (sin(a) * .5 + sin(b) * .3 + sin(c) * .2) * ripple_strength;
	ALBEDO = deep_color + ripple * 0.006;
	METALLIC = 0.45;
	SPECULAR = 0.35;
	ROUGHNESS = water_roughness;
	NORMAL_MAP = vec3(0.5 + ripple * 0.035, 0.5 + cos(b) * 0.015 * ripple_strength, 1.0);
}
