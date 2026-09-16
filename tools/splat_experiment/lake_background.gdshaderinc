// Scene-specific removal of photographic foreground replaced by meshes/splats.
uniform bool clean_lake_background = false;
vec3 lake_background_color(vec3 d) {
 vec2 uv=vec2(fract(atan(d.x,-d.z)/TAU+.5),acos(clamp(d.y,-1.0,1.0))/PI);
 vec3 original=texture(panorama,uv).rgb;
 // Borrow neighboring open sky at the same angular scale. Broad feathering
 // avoids narrow vertical reconstruction strips around the old pole row.
 float sky_patch=smoothstep(.665,.69,uv.x)*(1.0-smoothstep(.747,.775,uv.x));
 sky_patch*=1.0-smoothstep(.515,.535,uv.y);
 original=mix(original,texture(panorama,uv-vec2(.12,0.0)).rgb,sky_patch);
 // Keep the distant shoreline. The nearer right jetty is now entirely splats.
 float jetty=smoothstep(.65,.675,uv.x)*(1.0-smoothstep(.755,.78,uv.x))*smoothstep(.502,.52,uv.y);
 float near_foreground=smoothstep(.555,.615,uv.y);
 vec2 clean_uv=vec2(.57+sin(uv.x*TAU)*.025,clamp(uv.y,.515,.55));
 return mix(original,texture(panorama,clean_uv).rgb,max(jetty,near_foreground));
}
