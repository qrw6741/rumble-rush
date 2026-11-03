shader_type spatial;
// Toon shading driven by vertex colours, so a whole merged body part is one draw call.
// COLOR.rgb = albedo, UV2.x = glow strength.
render_mode diffuse_toon, specular_disabled;

uniform float rim_strength = 0.18;

void fragment() {
	ALBEDO = COLOR.rgb;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = COLOR.rgb * UV2.x + COLOR.rgb * rim * rim_strength;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float band = smoothstep(-0.05, 0.08, ndl);
	float shade = mix(0.35, 1.0, band);
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * ATTENUATION * shade;
}
