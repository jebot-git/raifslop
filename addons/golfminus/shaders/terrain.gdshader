shader_type spatial;
// Adapted from Real AI Fishing rivers/bank.gdshader: tiled PBR + independent irradiance.
render_mode ambient_light_disabled;
uniform sampler2D cover : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D grass : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D grass_normal : hint_normal,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D gravel : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D gravel_normal : hint_normal,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D irradiance : filter_linear_mipmap,repeat_disable;
uniform sampler2D sky_light : filter_linear_mipmap,repeat_disable;
uniform sampler2D bank_ao : hint_default_white,filter_linear_mipmap,repeat_disable;
uniform bool has_bake=false;
uniform bool has_course_detail=false;
uniform sampler2D rough_grass : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D rough_normal : hint_normal,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D rough_roughness : filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D turf_variation : filter_linear_mipmap_anisotropic,repeat_enable;
uniform float ambient_fill=.22;
uniform bool has_mapped_lies=false;
uniform sampler2D mapped_lies : filter_nearest,repeat_disable;
uniform vec2 lie_origin;
uniform vec4 lie_colors[8];
// Metres across a cell boundary. Zero is useful for physics-map diagnostics.
uniform float terrain_blend_width : hint_range(0.0,1.0) = 1.0;
int mapped_lie(ivec2 cell){
 ivec2 size=textureSize(mapped_lies,0);
 if(any(lessThan(cell,ivec2(0))) || any(greaterThanEqual(cell,size))){return 6;}
 return clamp(int(round(texelFetch(mapped_lies,cell,0).r*255.0)),0,6);
}
vec4 lie_weights(int lie){
 return vec4(lie==4?1.0:0.0,lie==3?1.0:0.0,(lie==0 || lie==6)?1.0:0.0,lie==1?1.0:0.0);
}
varying vec3 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;}
void fragment(){
 vec2 uv=world.xz*.45;
 vec3 growth=texture(grass,uv*.63).rgb;
 growth=mix(growth,texture(grass,vec2(-uv.y,uv.x)*.37+vec2(.31,.67)).rgb,.38);
 float grain=dot(growth,vec3(.2126,.7152,.0722));
 vec3 stone=texture(gravel,uv*.8).rgb;
 vec3 surface_color=COLOR.rgb;
 float sand=1.0-step(.1,COLOR.a);
 float green=1.0-smoothstep(.15,.30,COLOR.a);
 float rough=step(.8,COLOR.a);
 if(has_mapped_lies){
  vec2 map_position=world.xz-lie_origin;
  vec4 weights=vec4(0.0);
  surface_color=vec3(0.0);
  if(terrain_blend_width>0.0){
   // Decode categories before interpolation; lie IDs are not continuous values.
   ivec2 base=ivec2(floor(map_position));
   vec2 blend=smoothstep(vec2(.5-terrain_blend_width*.5),vec2(.5+terrain_blend_width*.5),fract(map_position));
   for(int z=0;z<2;z++){
    for(int x=0;x<2;x++){
     int lie=mapped_lie(base+ivec2(x,z));
     float weight=(x==0?1.0-blend.x:blend.x)*(z==0?1.0-blend.y:blend.y);
     surface_color+=lie_colors[lie].rgb*weight;
     weights+=lie_weights(lie)*weight;
    }
   }
  }else{
   int lie=mapped_lie(ivec2(floor(map_position+vec2(.5))));
   surface_color=lie_colors[lie].rgb;
   weights=lie_weights(lie);
  }
  // Mower bands fade with the fairway's contribution at its soft edge.
  float stripe_coord=dot(world.xz,vec2(.6,.8))/9.0;
  float stripe_aa=max(fwidth(stripe_coord)*2.0,.035);
  float stripe=smoothstep(-stripe_aa,stripe_aa,sin(stripe_coord*3.14159265));
  surface_color+=(lie_colors[7].rgb-lie_colors[1].rgb)*stripe*weights.w;
  float cut=.5+.5*sin(dot(world.xz,vec2(-.8,.6))*1.4);
  surface_color*=mix(1.0,mix(.97,1.03,cut),weights.y);
  sand=weights.x;
  green=weights.y;
  rough=weights.z;
 }
 float cover_detail=texture(cover,uv*.073).g;
 vec3 turf=surface_color*mix(.88,1.15,clamp(grain*4.0,0.0,1.0));
 turf*=mix(.90,1.05,cover_detail);
 ALBEDO=mix(turf,mix(surface_color,stone,.38),sand);
 NORMAL_MAP=normalize(mix(texture(grass_normal,uv*.63).rgb*2.0-1.0,texture(gravel_normal,uv*.8).rgb*2.0-1.0,sand))*.5+.5;
 // Fine turf near the ball, quieter normals at headset distances.
 float near_detail=1.0-smoothstep(8.0,45.0,length(world.xz-CAMERA_POSITION_WORLD.xz));
 NORMAL_MAP_DEPTH=mix(.10,mix(.30,.055,green),near_detail);
 ROUGHNESS=mix(mix(.94,.82,green),.98,sand);SPECULAR=.18;
 if(has_course_detail){
  // Hand-painted, seamless Krita variation complements scanned 2.51 m rough.
  float variation=texture(turf_variation,world.xz*.12).r;
  ALBEDO*=mix(.96,1.04,variation);
  vec3 dry_grass=texture(rough_grass,world.xz/2.51).rgb;
  ALBEDO=mix(ALBEDO,mix(ALBEDO,dry_grass,.48),rough);
  NORMAL_MAP=mix(NORMAL_MAP,texture(rough_normal,world.xz/2.51).rgb,rough);
  ROUGHNESS=mix(ROUGHNESS,clamp(texture(rough_roughness,world.xz/2.51).r,.82,1.0),rough);
 }
 float ao=has_bake?mix(1.0,texture(bank_ao,UV2).r,.35):1.0;
 vec3 total=texture(irradiance,UV2).rgb;
 vec3 sky=texture(sky_light,UV2).rgb;
 float microshade=clamp(1.0+(NORMAL_MAP.x-.5)*.16+(NORMAL_MAP.y-.5)*.12,.9,1.1);
 EMISSION=ALBEDO*(has_bake ? (min(sky,total)+max(total-sky,vec3(0.0))*microshade)*.86 : vec3(ambient_fill))*ao;
 AO=ao;AO_LIGHT_AFFECT=.1;
}
void light(){
 if(!has_bake){DIFFUSE_LIGHT+=ALBEDO*LIGHT_COLOR*ATTENUATION*max(dot(NORMAL,LIGHT),0.0)/PI;}
 vec3 halfway=normalize(LIGHT+VIEW);
 SPECULAR_LIGHT+=LIGHT_COLOR*ATTENUATION*pow(max(dot(NORMAL,halfway),0.0),24.0)*.025*(1.0-ROUGHNESS);
}
