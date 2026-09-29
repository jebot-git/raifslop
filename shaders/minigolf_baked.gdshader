shader_type spatial;
render_mode unshaded;
uniform vec4 base_color:source_color=vec4(1.0);
uniform sampler2D color_texture:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform bool has_color_texture=false;
uniform bool triplanar=false;
uniform vec3 texture_scale=vec3(1.0);
uniform vec3 texture_offset=vec3(0.0);
uniform sampler2D irradiance:filter_linear_mipmap,repeat_disable;
uniform sampler2D occlusion:filter_linear_mipmap,repeat_disable;
varying vec3 local_position;
varying vec3 local_normal;
void vertex(){local_position=VERTEX;local_normal=NORMAL;}
void fragment(){
 vec3 base=base_color.rgb;
 if(has_color_texture){
  vec3 texel;
  if(triplanar){
   vec3 p=local_position*texture_scale+texture_offset;
   vec3 w=pow(abs(local_normal),vec3(4.0));w/=max(w.x+w.y+w.z,.001);
   texel=texture(color_texture,p.zy).rgb*w.x+texture(color_texture,p.xz).rgb*w.y+texture(color_texture,p.xy).rgb*w.z;
  }else{texel=texture(color_texture,UV*texture_scale.xy+texture_offset.xy).rgb;}
  base*=texel;
 }
 ALBEDO=base*texture(irradiance,UV2).rgb*.86;
 // Occlusion is retained separately for inspection; irradiance already includes it.
 ROUGHNESS=1.0;
}
