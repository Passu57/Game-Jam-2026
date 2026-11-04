shader_type canvas_item;
// Pixel-art waterfall: falling streaks in each column, wobbly edges and a
// frothy front while it starts to flow. Sizes are in pixels.

uniform vec2 rect_size = vec2(16.0, 100.0);
// How many pixels from the top are already flowing (the falling front).
uniform float reveal = 9999.0;
// Falling speed of the streaks (pixels per second).
uniform float speed = 70.0;
uniform vec4 water_color : source_color = vec4(0.30, 0.48, 0.98, 0.78);
uniform vec4 dark_color : source_color = vec4(0.12, 0.22, 0.66, 0.85);
uniform vec4 foam_color : source_color = vec4(0.82, 0.90, 1.0, 0.95);

float hash(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

void fragment() {
	vec2 px = floor(UV * rect_size);
	float w = rect_size.x;
	float t = floor(TIME * speed);  // whole-pixel steps keep it crisp

	// Not flowing this far down yet.
	if (px.y > reveal) {
		COLOR = vec4(0.0);
	} else {
		// Edges wobble in and out by a pixel.
		float wob_l = step(0.0, sin(px.y * 0.35 - TIME * 7.0));
		float wob_r = step(0.0, sin(px.y * 0.31 + 1.7 - TIME * 6.3));
		if (px.x < wob_l || px.x > w - 1.0 - wob_r) {
			COLOR = vec4(0.0);
		} else {
			float h = hash(px.x + 3.0);
			float col_speed = 0.75 + 0.5 * h;
			float len = 10.0 + 10.0 * hash(px.x + 17.0);
			float v = fract((px.y - t * col_speed) / len + h);

			vec4 c = water_color;
			if (v < 0.18) {
				c = foam_color;  // bright streak
			} else if (v < 0.32) {
				c = mix(water_color, foam_color, 0.4);
			} else if (v > 0.78) {
				c = dark_color;  // darker gap
			}
			// Light rim on the outer columns.
			if (px.x <= wob_l || px.x >= w - 1.0 - wob_r) {
				c = mix(c, foam_color, 0.55);
			}
			// Froth right where it pours out of the rock.
			if (px.y < 2.0) {
				c = mix(c, foam_color, 0.6);
			}
			// Frothy falling front while it starts.
			if (reveal < rect_size.y && px.y > reveal - 3.0) {
				c = foam_color;
			}
			COLOR = c;
		}
	}
}
