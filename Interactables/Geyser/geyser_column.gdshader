shader_type canvas_item;
// A pixel-art jet of water shooting upward: wobbly edges, streaks rushing up,
// bright foam at the top. Sizes are in pixels.

uniform vec2 rect_size = vec2(14.0, 100.0);
uniform vec4 core_color : source_color = vec4(0.55, 0.72, 1.0, 0.85);
uniform vec4 edge_color : source_color = vec4(0.20, 0.38, 0.95, 0.75);
uniform vec4 foam_color : source_color = vec4(0.90, 0.95, 1.0, 0.95);
// How fast the streaks rush upward (pixels per second).
uniform float flow_speed = 140.0;
// 0..1 overall visibility (used for fading in/out).
uniform float strength = 1.0;

void fragment() {
	vec2 px = floor(UV * rect_size);
	float half_w = rect_size.x * 0.5;
	float from_center = abs(px.x + 0.5 - half_w) / half_w;  // 0 middle, 1 edge

	// Edges wobble so the jet looks alive.
	float edge = 0.78 + 0.22 * sin(px.y * 0.35 + TIME * 14.0) * sin(px.y * 0.13 - TIME * 5.0);
	if (from_center > edge) {
		COLOR = vec4(0.0);
	} else {
		vec4 c = mix(core_color, edge_color, from_center / max(edge, 0.01));
		// Streaks rushing upward.
		float s = fract((px.y + TIME * flow_speed) / 10.0 + sin(px.x * 1.9) * 0.35);
		if (s < 0.22) {
			c.rgb = mix(c.rgb, foam_color.rgb, 0.45);
		}
		// Foamy top.
		if (px.y < 5.0) {
			c = mix(foam_color, c, px.y / 5.0);
		}
		c.a *= strength;
		COLOR = c;
	}
}
