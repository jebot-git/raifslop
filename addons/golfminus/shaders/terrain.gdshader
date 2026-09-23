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
uniform float ambient_fill=.22;
uniform bool has_mapped_lies=false;
uniform sampler2D mapped_lies : filter_nearest,repeat_disable;
uniform vec2 lie_origin;
uniform vec4 lie_colors[8];
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
 if(has_mapped_lies){
  ivec2 cell=ivec2(floor(world.xz-lie_origin+vec2(.5)));
  ivec2 size=textureSize(mapped_lies,0);
  int lie=6;
  if(all(greaterThanEqual(cell,ivec2(0))) && all(lessThan(cell,size))){
   lie=clamp(int(round(texelFetch(mapped_lies,cell,0).r*255.0)),0,6);
  }
  surface_color=lie_colors[lie].rgb;
  if(lie==1 && mod(floor(world.z/9.0),2.0)==0.0){surface_color=lie_colors[7].rgb;}
  sand=lie==4?1.0:0.0;
  green=lie==3?1.0:0.0;
 }
 float cover_detail=texture(cover,uv*.073).g;
 vec3 turf=surface_color*mix(.88,1.15,clamp(grain*4.0,0.0,1.0));
 turf*=mix(.90,1.05,cover_detail);
 ALBEDO=mix(turf,mix(surface_color,stone,.38),sand);
 NORMAL_MAP=normalize(mix(texture(grass_normal,uv*.63).rgb*2.0-1.0,texture(gravel_normal,uv*.8).rgb*2.0-1.0,sand))*.5+.5;
 NORMAL_MAP_DEPTH=mix(.22,.06,green);
 ROUGHNESS=.92;SPECULAR=.18;
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
