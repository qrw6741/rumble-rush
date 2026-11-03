shader_type canvas_item;
// Hit flash + fade for the rendered 3D brawler sprite.
uniform float flash = 0.0;
uniform float alpha = 1.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	c.rgb = mix(c.rgb, vec3(1.0), flash);
	c.a *= alpha;
	COLOR = c;
}
