shader_type canvas_item;
// Makes only the lit glass of a lantern flicker like a flame.
// The 3 light colors of the lantern sprite are matched; everything else
// (wood, metal, outline) is left alone.

uniform vec4 light_a : source_color = vec4(0.953, 0.639, 0.051, 1.0); // orange
uniform vec4 light_b : source_color = vec4(0.980, 0.757, 0.243, 1.0); // yellow
uniform vec4 light_c : source_color = vec4(0.992, 0.957, 0.808, 1.0); // cream core
// How strong the flicker is (0 = steady).
uniform float flicker : hint_range(0.0, 0.6) = 0.18;
uniform float flicker_speed = 9.0;
// Offsets the flicker so lanterns next to each other don't pulse in sync.
uniform float flicker_offset = 0.0;
// Overall brightness of the lit glass.
uniform float brightness : hint_range(0.5, 2.5) = 1.1;

const float TOL = 0.06;

varying vec4 modulate_color;

void vertex() {
	modulate_color = COLOR;
}

float flame(float t) {
	// A few sine waves at odd speeds = an irregular flame flicker.
	return sin(t) * 0.5 + sin(t * 2.31 + 1.7) * 0.3 + sin(t * 5.13 + 0.4) * 0.2;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 rgb = c.rgb;
	bool lit = distance(rgb, light_a.rgb) < TOL
		|| distance(rgb, light_b.rgb) < TOL
		|| distance(rgb, light_c.rgb) < TOL;
	if (lit) {
		float f = 1.0 + flicker * flame(TIME * flicker_speed + flicker_offset);
		rgb *= brightness * f;
	}
	COLOR = vec4(rgb, c.a) * modulate_color;
}
