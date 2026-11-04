shader_type canvas_item;
// Chunky, stepped pixel vignette that darkens the screen edges.
uniform float strength : hint_range(0.0, 1.0) = 0.8;
// Size of one "pixel" of the vignette.
uniform float pixel = 8.0;
uniform vec4 shade : source_color = vec4(0.03, 0.02, 0.05, 1.0);

void fragment() {
	vec2 screen = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 p = floor(FRAGCOORD.xy / pixel) * pixel / screen;
	vec2 d = p - 0.5;
	d.x *= 1.25;
	float v = smoothstep(0.38, 0.9, length(d));
	v = floor(v * 5.0) / 5.0;  // hard steps instead of a smooth fade
	COLOR = vec4(shade.rgb, v * strength);
}
