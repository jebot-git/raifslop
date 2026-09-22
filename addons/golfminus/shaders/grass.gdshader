shader_type spatial;
render_mode cull_disabled, unshaded;
varying float tip;
void vertex(){tip=UV.y;VERTEX.x+=sin(TIME*1.3+float(INSTANCE_ID)*.71)*UV.y*UV.y*.09;}
void fragment(){ALBEDO=mix(vec3(.18,.22,.095),vec3(.28,.30,.14),tip);ROUGHNESS=1.0;}
