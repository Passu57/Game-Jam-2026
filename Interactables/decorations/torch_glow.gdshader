shader_type canvas_item;
render_mode blend_add, unshaded;
// Pixel-art glow: a few stepped rings of light instead of a smooth blur.
// Drawn on a square sprite; the TorchColor script sets everything.

uniform vec4 glow_color : source_color = vec4(1.0, 0.8, 0.3, 1.0);
uniform float strength : hint_range(0.0, 2.0) = 0.6;
// Size of the glow in game pixels (diameter). Used to snap to the pixel grid.
uniform float pixel_size = 48.0;
// Number of brightness steps (rings).
uniform int steps : hint_range(1, 8) = 4;
uniform float flicker : hint_range(0.0, 0.5) = 0.08;
uniform float flicker_speed = 9.0;
uniform float flicker_offset = 0.0;

void fragment() {
	// Snap to whole game pixels so the glow stays crisp.
	vec2 p = (floor(UV * pixel_size) + 0.5) / pixel_size;
	float d = distance(p, vec2(0.5)) * 2.0; // 0 center, 1 edge
	float fall = clamp(1.0 - d, 0.0, 1.0);
	fall = pow(fall, 1.4);
	float s = float(steps);
	fall = ceil(fall * s) / s; // stepped rings
	if (d >= 1.0) {
		fall = 0.0;
	}
	float t = TIME * flicker_speed + flicker_offset;
	float f = 1.0 + flicker * 2.0 * (sin(t) * 0.6 + sin(t * 2.37 + 1.3) * 0.4);
	// blend_add multiplies by alpha itself, so don't pre-multiply the color.
	COLOR = vec4(glow_color.rgb, fall * strength * 0.5 * f);
}
