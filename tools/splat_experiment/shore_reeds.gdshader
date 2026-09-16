shader_type spatial;
// Photographic shading stays consistent across intersecting faces and backfaces.
render_mode cull_disabled, unshaded;
uniform sampler2D foliage : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float exposure = .4;
uniform float sway = .035;
varying float instance_shade;
varying float water_plant;
varying float world_y;
void vertex(){
 instance_shade=max(.1,INSTANCE_CUSTOM.x);
 vec3 at=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 water_plant=INSTANCE_CUSTOM.g;
 world_y=at.y;
 VERTEX.x+=sin(TIME*.9+at.x*.7+at.z)*pow(1.0-UV.y,2.0)*sway;
}
void fragment(){
 vec4 leaf=texture(foliage,UV);
 ALBEDO=leaf.rgb*instance_shade*exposure;

 if(water_plant>.5 && world_y < -1.985) discard;
 ALPHA=leaf.a*mix(1.0,smoothstep(0.0,.12,1.0-UV.y),water_plant);ALPHA_SCISSOR_THRESHOLD=.42;

}
