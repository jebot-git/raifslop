shader_type spatial;
varying vec3 ground_pos;
void vertex() { ground_pos = VERTEX; }
void fragment() {
	float grain = fract(sin(dot(floor(ground_pos.xz * 45.0), vec2(12.9898,78.233))) * 43758.5453);
	float patch = sin(ground_pos.x * 0.7) * cos(ground_pos.z * 0.9) * 0.5 + 0.5;
	ALBEDO = mix(vec3(0.19, 0.23, 0.10), vec3(0.36, 0.34, 0.19), patch) + grain * 0.05;
	ROUGHNESS = 0.95;
}
