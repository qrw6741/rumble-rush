shader_type spatial;
// Soft matte cartoon shading driven by vertex colours (one draw call per merged body part).
// Soft wrapped light, cool shadow tint, warm highlight, a glossy specular blob and
// a bright rim, for a polished "vinyl toy" look. COLOR.rgb = albedo, UV2.x = glow.
render_mode specular_disabled;

uniform float rim_strength = 0.18;
uniform vec3 shadow_tint = vec3(0.62, 0.62, 0.95);

void fragment() {
	ALBEDO = COLOR.rgb;
	float fres = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = smoothstep(0.55, 0.95, fres);
	// matte finish: only a faint, same-colour edge light (no white sheen)
	EMISSION = COLOR.rgb * UV2.x + COLOR.rgb * rim * rim_strength * 0.35;
	ROUGHNESS = 1.0;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	// wrapped, softly banded diffuse
	float wrap = clamp((ndl + 0.35) / 1.35, 0.0, 1.0);
	float soft = smoothstep(0.0, 1.0, wrap);
	vec3 lit = mix(shadow_tint * 0.55, vec3(1.08, 1.03, 0.95), soft);
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * ATTENUATION * lit;
}
