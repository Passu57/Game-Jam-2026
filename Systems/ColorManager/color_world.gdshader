shader_type canvas_item;
// Draws the screen in black & white, except for the color groups
// that have been unlocked. band_strength: 0 = gray, 1 = full color.
// Bands: 0 Red, 1 Yellow, 2 Green, 3 Cyan, 4 Blue, 5 Magenta

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float band_strength[6];

float get_hue(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10));
}

void fragment() {
	vec3 c = texture(screen_texture, SCREEN_UV).rgb;
	float gray = dot(c, vec3(0.299, 0.587, 0.114));
	float h = get_hue(c);

	// Each band covers a slice of the color wheel and blends into its neighbours.
	float amount = 0.0;
	for (int i = 0; i < 6; i++) {
		float center = float(i) / 6.0;
		float dist = abs(h - center);
		dist = min(dist, 1.0 - dist);
		float weight = clamp(1.0 - dist * 6.0, 0.0, 1.0);
		amount += weight * band_strength[i];
	}
	amount = clamp(amount, 0.0, 1.0);

	COLOR = vec4(mix(vec3(gray), c, amount), 1.0);
}
