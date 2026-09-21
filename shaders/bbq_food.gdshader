shader_type spatial;
render_mode cull_disabled;
uniform sampler2D food_texture : source_color, filter_linear_mipmap;
uniform vec4 food_color : source_color = vec4(1.0);
uniform bool use_vertex_color = false;
uniform bool use_texture = false;
uniform sampler2D detail_normal : hint_normal, filter_linear_mipmap;
uniform sampler2D detail_roughness : filter_linear_mipmap;
uniform bool use_normal_texture = false;
uniform bool use_roughness_texture = false;
uniform float normal_strength = 1.0;
uniform vec4 roughness_channel = vec4(0.0, 1.0, 0.0, 0.0);
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
    if (use_vertex_color) { base *= COLOR; }
    if (use_texture) { base *= texture(food_texture, UV); }
    float heat = mix(cook_bottom, cook_top, smoothstep(-0.15, 0.15, food_normal.y));
    float stripe = 1.0 - smoothstep(0.10, 0.24, abs(sin(food_position.x * 115.0 + food_position.z * 35.0)));
    vec3 toasted = mix(base.rgb, base.rgb * vec3(0.72, 0.43, 0.20), clamp(heat, 0.0, 1.0)*0.72);
    toasted *= 1.0 - stripe * smoothstep(0.25, 1.0, heat) * 0.66;
    ALBEDO = mix(toasted, vec3(0.042, 0.027, 0.017), smoothstep(1.1, 1.8, heat)*0.90);
    float roughness = food_roughness;
    if (use_roughness_texture) { roughness *= dot(texture(detail_roughness, UV), roughness_channel); }
    ROUGHNESS = mix(roughness, 0.88, clamp(heat*.5, 0.0, 1.0));
    if (use_normal_texture) {
        NORMAL_MAP = texture(detail_normal, UV).rgb;
        NORMAL_MAP_DEPTH = normal_strength;
    }
}
