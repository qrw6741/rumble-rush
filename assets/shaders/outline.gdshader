shader_type spatial;
// Inverted-hull outline: draws back faces pushed out along normals.
render_mode unshaded, cull_front, depth_draw_opaque;

uniform vec4 color : source_color = vec4(0.1, 0.063, 0.157, 1.0);
uniform float width = 0.022;

void vertex() {
	VERTEX += NORMAL * width;
}

void fragment() {
	ALBEDO = color.rgb;
}
