shader_type canvas_item;
// Recolours a sprite for a skin: brightness -> colour ramp, keeps the ink lines.
uniform vec3 c0 = vec3(0.0);
uniform vec3 c1 = vec3(0.3);
uniform vec3 c2 = vec3(0.6);
uniform vec3 c3 = vec3(0.85);
uniform vec3 c4 = vec3(1.0);

vec3 ramp_at(float x) {
	if (x < 0.3) return mix(c0, c1, x / 0.3);
	if (x < 0.6) return mix(c1, c2, (x - 0.3) / 0.3);
	if (x < 0.85) return mix(c2, c3, (x - 0.6) / 0.25);
	return mix(c3, c4, (x - 0.85) / 0.15);
}
// x = lift, y = keep, z = hue mode (0/1), w = hue shift
uniform vec4 params = vec4(1.0, 0.2, 0.0, 0.45);

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}
vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	vec3 src = t.rgb;
	float lum = dot(src, vec3(0.299, 0.587, 0.114));
	lum = pow(clamp((lum - 0.04) / 0.9, 0.0, 1.0), 0.85 * params.x);
	vec3 h = rgb2hsv(src);
	h.x = fract(h.x + params.w);
	h.y = clamp(h.y * 1.4, 0.0, 1.0);
	h.z = clamp(h.z * 1.1, 0.0, 1.0);
	vec3 hue_col = hsv2rgb(h);
	vec3 ramp_col = ramp_at(lum);
	ramp_col = mix(ramp_col, src * (dot(ramp_col, vec3(0.333)) / max(dot(src, vec3(0.333)), 0.01)), params.y);
	vec3 col = mix(ramp_col, hue_col, params.z);
	float ink = 1.0 - smoothstep(0.04, 0.12, lum);
	col = mix(col, src * 0.6 + col * 0.4, ink);
	COLOR = vec4(col, COLOR.a);
}
