shader_type spatial;
// Cartoon "toy" shading: two-tone light ramp, soft rim light and optional glow.
render_mode diffuse_toon, specular_disabled;

uniform vec4 albedo : source_color = vec4(1.0);
uniform vec4 emission : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_strength = 0.0;
uniform float rim_strength = 0.18;

void fragment() {
	ALBEDO = albedo.rgb;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = emission.rgb * emission_strength + albedo.rgb * rim * rim_strength;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float band = smoothstep(-0.05, 0.08, ndl);
	float shade = mix(0.35, 1.0, band);
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * ATTENUATION * shade;
}
