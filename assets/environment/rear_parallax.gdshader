shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
#include "res://shaders/panorama_sampling.gdshaderinc"
uniform mat3 sky_inverse = mat3(1.0);
uniform float sky_energy = 1.0;
uniform vec3 projection_origin;
uniform bool left_shore_extension = false;
uniform bool rear_harbour_basin = false;
varying vec3 world_position;
void vertex() {
 world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
}
void fragment() {
 ALBEDO = panorama_sample(sky_inverse * normalize(world_position-projection_origin),true)*sky_energy;
 // Feather only the outside perimeter; adjacent depth bands share vertices and
 // photographic rays, avoiding stacked alpha cards and their duplicated edges.
 ALPHA = smoothstep(0.0,.07,UV.x)*smoothstep(0.0,.07,1.0-UV.x)
       * smoothstep(0.0,.12,UV.y)*smoothstep(0.0,.15,1.0-UV.y);
 if(rear_harbour_basin) ALPHA*=smoothstep(-.75,-.25,world_position.y);
 if(left_shore_extension){
  // The extended sand/water own the lower shore; only the raised seawall
  // needs side parallax. Do not double-project beach pixels over the surf.
  float side=smoothstep(0.0,4.0,projection_origin.z-world_position.z);
  ALPHA*=mix(1.0,smoothstep(-.05,.45,world_position.y),side);
 }
}
