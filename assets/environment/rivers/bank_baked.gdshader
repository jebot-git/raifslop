shader_type spatial;
render_mode ambient_light_disabled;
// sRGB colour/emission (emission has a fixed 4x range) and linear normal XY + roughness.
uniform sampler2D baked_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D baked_emission : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D baked_normal_rough : filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D gravel_detail : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_bake = false;
uniform float snow_cover = 0.0;
varying vec3 world;
varying float bake_weight;
void vertex() {
 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
 bake_weight = has_bake ? (1.0-smoothstep(43.0,47.0,abs(world.x)))*(1.0-smoothstep(15.0,19.0,world.z))*smoothstep(-49.0,-45.0,world.z) : 0.0;
}
void fragment() {
 vec2 uv = (world.xz + vec2(128.0, 78.0)) / vec2(256.0, 128.0);
 ALBEDO = texture(baked_albedo, uv).rgb;
 EMISSION = texture(baked_emission, uv).rgb * 4.0;
 vec3 packed = texture(baked_normal_rough, uv).rgb;
 vec2 n = packed.xy * 2.0 - 1.0;
 NORMAL_MAP = vec3(n, sqrt(max(0.0, 1.0-dot(n,n)))) * .5 + .5;
 float irregular = sin(world.x*1.7+sin(world.z*2.3))*.14+sin(world.x*.38+world.z*.8)*.2;
 float snow = snow_cover * smoothstep(.3,1.3,world.y+irregular*2.5);
 // The full-length atlas has 3.125 cm texels. Restore only the missing nearby
 // gravel frequencies, using the same photographed tile as the reference.
 float detail_weight=(1.0-smoothstep(5.0,12.0,length(VERTEX)))*(1.0-snow);
 if (detail_weight > .001) {
  vec2 detail_uv=world.xz*.36;
  float lod=log2(float(textureSize(gravel_detail,0).x)*.36*.03125);
  vec3 fine=texture(gravel_detail,detail_uv).rgb;
  vec3 coarse=textureLod(gravel_detail,detail_uv,lod).rgb;
  vec3 detail=mix(vec3(1.0),clamp((fine+.015)/(coarse+.015),vec3(.5),vec3(1.6)),detail_weight);
  ALBEDO*=detail;
  EMISSION*=detail;
 }
 NORMAL_MAP_DEPTH = mix(.55,.12,snow);
 ROUGHNESS = packed.z;
 SPECULAR = mix(.22,.42,1.0-smoothstep(-.32,-.04,world.y+irregular*.12));
}
void light() {
 DIFFUSE_LIGHT += ALBEDO*LIGHT_COLOR*ATTENUATION*max(dot(NORMAL,LIGHT),0.0)*(1.0-bake_weight)/PI;
 vec3 halfway = normalize(LIGHT+VIEW);
 SPECULAR_LIGHT += LIGHT_COLOR*ATTENUATION*pow(max(dot(NORMAL,halfway),0.0),24.0)*.025*(1.0-ROUGHNESS);
}
