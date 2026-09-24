shader_type spatial;
// Appearance only. Vertex positions, loft and contact normals stay in club_head.gd.
uniform bool style_enabled=false;
// Linear RGB, matching the Blender-authored tackle palette.
uniform vec3 style_blank=vec3(.028,.055,.018);
uniform vec3 style_trim=vec3(.18,.25,.10);
uniform int club_kind=0; // driver / iron / putter
uniform float head_depth=.096;
uniform sampler2D carbon : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D brushed_rough : filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 local_point;
varying vec3 local_normal;
void vertex(){local_point=VERTEX;local_normal=NORMAL;}
float stripe(float coordinate,float half_width){
 float aa=max(fwidth(coordinate),.000025);
 return 1.0-smoothstep(half_width-aa,half_width+aa,abs(coordinate));
}
void fragment(){
 float face=COLOR.r;
 float crown=smoothstep(.1,.65,local_normal.y)*(1.0-face);
 vec3 steel=vec3(.58,.65,.69);
 vec3 carbon_color=texture(carbon,UV*2.0).rgb;
 vec3 body=club_kind==0 ? carbon_color*.6 : club_kind==2 ? vec3(.025,.075,.063) : steel;
 if(style_enabled && club_kind!=1){body=club_kind==0 ? style_blank*(.72+carbon_color.r*1.8) : style_blank;}
 float rough=texture(brushed_rough,UV*vec2(2.0,1.0)).r;
 ALBEDO=mix(body,steel,face);
 METALLIC=club_kind==0 ? mix(.55,.94,face) : club_kind==2 ? mix(.4,.9,face) : .94;
 ROUGHNESS=mix(club_kind==0 ? .24 : .32,.25+rough*.16,face);
 // Anti-aliased score lines, a fine mill finish and a painted alignment mark.
 float spacing=club_kind==2 ? .0018 : .0033;
 float line_distance=(fract(local_point.y/spacing+.5)-.5)*spacing;
 float groove=stripe(line_distance,.00016)*stripe(local_point.x,.043)*stripe(local_point.y,club_kind==2 ? .009 : .019)*face;
 ALBEDO=mix(ALBEDO,vec3(.055,.075,.078),groove*.78);
 ROUGHNESS=mix(ROUGHNESS,.48,groove);
 float alignment=stripe(local_point.x,.0010)*crown;
 vec3 accent=club_kind==2 ? vec3(.82,.82,.67) : vec3(.55,.35,.12);
 ALBEDO=mix(ALBEDO,accent,alignment);
 METALLIC=mix(METALLIC,.2,alignment);
 // A recessed-looking rear badge is painted onto the unchanged metal shell.
 float back=smoothstep(.3,.8,local_normal.z)*(1.0-face);
 float badge=stripe(local_point.x,.027)*stripe(local_point.y,.010)*back;
 if(club_kind==1){ALBEDO=mix(ALBEDO,(style_enabled ? style_blank : vec3(.028,.075,.058)),badge);ROUGHNESS=mix(ROUGHNESS,.42,badge);}
 float signature=stripe(local_point.y,.001)*stripe(local_point.x,.010)*back;
 ALBEDO=mix(ALBEDO,(style_enabled ? style_trim : vec3(.62,.43,.18)),signature);
 SPECULAR=.5;
}
