shader_type spatial;
// Photographic shading stays consistent across intersecting faces and backfaces.
render_mode cull_disabled, unshaded;
uniform sampler2D foliage : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float exposure = .4;
uniform float sway = .035;
varying float instance_shade;
void vertex(){
 instance_shade=max(.1,INSTANCE_CUSTOM.x);
 vec3 at=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 VERTEX.x+=sin(TIME*.9+at.x*.7+at.z)*pow(1.0-UV.y,2.0)*sway;
}
void fragment(){
 vec4 leaf=texture(foliage,UV);
 ALBEDO=leaf.rgb*instance_shade*exposure;

 ALPHA=leaf.a;ALPHA_SCISSOR_THRESHOLD=.42;

}
