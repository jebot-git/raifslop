uniform sampler2D panorama : source_color, filter_linear_mipmap, repeat_enable;
uniform float detail_strength : hint_range(0.0, 0.8) = 0.5;
uniform float vibrance : hint_range(1.0, 1.1) = 1.025;
uniform float shadow_lift : hint_range(0.0, 0.04) = 0.015;
vec2 panorama_uv(vec3 direction) {
	vec3 d = normalize(direction);
	return vec2(fract(atan(d.x, -d.z) / TAU + 1.0), acos(clamp(d.y, -1.0, 1.0)) / PI);
}
vec3 panorama_texel(vec2 uv) {
	float half_texel = .5 / float(textureSize(panorama, 0).y);
	// Adjacent pixels straddling longitude 0/1 are neighbours on the sphere.
	// Implicit gradients see a whole-texture jump and select a very coarse mip,
	// making a dark/dashed meridian in both the sky and its water reflection.
	vec2 dx = dFdx(uv);
	vec2 dy = dFdy(uv);
	dx.x -= round(dx.x);
	dy.x -= round(dy.x);
	return textureGrad(panorama, vec2(fract(uv.x), clamp(uv.y, half_texel, 1.0-half_texel)), dx, dy).rgb;
}
float panorama_luma(vec3 color) { return dot(color,vec3(.2126,.7152,.0722)); }
vec3 panorama_grade(vec3 color) {
	float luma = panorama_luma(color);
	// Gentle dark-detail lift, preserving HDR highlights and the original white balance.
	color *= clamp(pow(max(luma,.001),-shadow_lift),.97,1.08);
	return max(mix(vec3(panorama_luma(color)),color,vibrance),vec3(0.0));
}
vec3 panorama_sample(vec3 direction, bool sharpen) {
	vec2 uv = panorama_uv(direction);
	vec3 center = panorama_texel(uv);
	if (sharpen && detail_strength > 0.0) {
		vec2 texel = 1.0 / vec2(textureSize(panorama,0));
		vec3 surround = (panorama_texel(uv+vec2(texel.x,0.0))+panorama_texel(uv-vec2(texel.x,0.0))
			+panorama_texel(uv+vec2(0.0,texel.y))+panorama_texel(uv-vec2(0.0,texel.y))) * .25;
		float luma = panorama_luma(center);
		float detail = (luma-panorama_luma(surround))*detail_strength*smoothstep(.008,.045,luma);
		// Bound overshoot to six percent; do not sharpen chroma or amplify dark noise.
		center *= 1.0 + clamp(detail/max(luma,.001),-.06,.06);
	}
	return panorama_grade(center);
}
