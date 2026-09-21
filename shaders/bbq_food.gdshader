shader_type spatial;
render_mode cull_disabled;
uniform sampler2D food_texture : source_color, filter_linear_mipmap;
uniform vec4 food_color : source_color = vec4(1.0);
uniform bool use_texture = false;
uniform float cook_top = 0.0;
uniform float cook_bottom = 0.0;
uniform float food_roughness = 0.55;
uniform mat4 world_to_food;
varying vec3 food_position;
varying vec3 food_normal;
void vertex() {
    food_position = (world_to_food * MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    food_normal = mat3(world_to_food) * MODEL_NORMAL_MATRIX * NORMAL;
}
void fragment() {
    vec4 base = food_color;
    if (use_texture) { base *= texture(food_texture, UV); }
    float heat = mix(cook_bottom, cook_top, smoothstep(-0.15, 0.15, food_normal.y));
    float stripe = 1.0 - smoothstep(0.10, 0.24, abs(sin(food_position.x * 115.0 + food_position.z * 35.0)));
    vec3 toasted = mix(base.rgb, base.rgb * vec3(0.72, 0.43, 0.20), clamp(heat, 0.0, 1.0)*0.72);
    toasted *= 1.0 - stripe * smoothstep(0.25, 1.0, heat) * 0.66;
    ALBEDO = mix(toasted, vec3(0.042, 0.027, 0.017), smoothstep(1.1, 1.8, heat)*0.90);
    ROUGHNESS = mix(food_roughness, 0.88, clamp(heat*.5, 0.0, 1.0));
}
