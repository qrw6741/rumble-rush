shader_type canvas_item;
// Soft edge darkening + a touch of warmth in the centre: a smoother, more "finished" picture.
uniform float strength = 0.32;
void fragment() {
	vec2 uv = SCREEN_UV - 0.5;
	float d = dot(uv * vec2(1.0, 1.2), uv * vec2(1.0, 1.2));
	float v = smoothstep(0.12, 0.55, d) * strength;
	COLOR = vec4(0.06, 0.03, 0.14, v);
}
