shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, fog_disabled, shadows_disabled;
uniform sampler2D panorama : source_color, filter_linear_mipmap, repeat_enable;
#include "res://lake_background.gdshaderinc"
varying vec3 direction;
void vertex() { direction = VERTEX; }
void fragment() {
    vec3 d = normalize(direction);
    vec2 uv = vec2(fract(atan(d.x, -d.z) / TAU + 0.5), acos(clamp(d.y, -1.0, 1.0)) / PI);
    ALBEDO = clean_lake_background ? lake_background_color(d) : texture(panorama, uv).rgb;
}
