shader_type canvas_item;
// Pixel-art water: wavy surface, bright foam line, deep-to-shallow gradient
// and wobbly light ripples (caustics) that fade out with depth.
// Sizes are in pixels.

uniform vec2 rect_size = vec2(100.0, 50.0);
// Empty space kept above the surface so the waves have room.
uniform float wave_pad = 4.0;
uniform float wave_height = 1.5;
uniform float wave_speed = 1.5;
uniform vec4 shallow_color : source_color = vec4(0.30, 0.48, 0.98, 0.72);
uniform vec4 deep_color : source_color = vec4(0.08, 0.14, 0.50, 0.88);
uniform vec4 foam_color : source_color = vec4(0.80, 0.88, 1.0, 0.95);
// How strong the light ripples are.
uniform float ripple_strength : hint_range(0.0, 1.0) = 0.22;
// 0..1, used to fade the water in while it starts filling.
uniform float fade = 1.0;

void fragment() {
	vec2 px = floor(UV * rect_size);  // whole pixels, so it matches the pixel art
	float t = TIME * wave_speed;
	float wave = sin(px.x * 0.15 + t) * 0.6 + sin(px.x * 0.37 - t * 1.3) * 0.4;
	float surface = wave_pad + floor(wave * wave_height + 0.5);

	if (px.y < surface) {
		COLOR = vec4(0.0);
	} else {
		float d = px.y - surface;  // pixels below the surface
		float depth = clamp(d / max(rect_size.y - wave_pad, 1.0), 0.0, 1.0);
		vec4 c = mix(shallow_color, deep_color, depth);

		// Wobbly light ripples, like sunlight through water. Strongest near the top.
		vec2 p = px * vec2(0.09, 0.14);
		float warp = sin(p.y * 1.7 + t * 0.8) + sin(p.x * 1.3 - t * 0.6);
		float r = sin(p.x + warp + t * 0.5) * sin(p.y * 1.4 - warp * 0.7 - t * 0.4);
		float near_top = 1.0 - smoothstep(0.0, 0.7, depth);
		if (r > 0.78 && d > 2.0) {
			c.rgb = mix(c.rgb, foam_color.rgb, ripple_strength * near_top);
		}

		// Bright line on top, softer line just under it.
		if (d < 1.0) {
			c = foam_color;
		} else if (d < 2.0) {
			c.rgb = mix(c.rgb, foam_color.rgb, 0.35);
		}

		c.a *= fade;
		COLOR = c;
	}
}
