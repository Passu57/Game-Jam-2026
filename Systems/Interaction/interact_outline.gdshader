shader_type canvas_item;
// Pixel outline around a sprite, used to show "you can interact with this".
// intensity: 0 = no outline, 1 = full outline (faded in/out by script).
// frame_min / frame_max: UV box of the current sprite-sheet frame, so the
// outline never picks up pixels from neighbouring frames.

uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float outline_width : hint_range(0.0, 4.0) = 1.0;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float pulse_speed = 4.0;
uniform float pulse_amount : hint_range(0.0, 1.0) = 0.35;
uniform vec2 frame_min = vec2(0.0, 0.0);
uniform vec2 frame_max = vec2(1.0, 1.0);

float alpha_at(sampler2D tex, vec2 uv) {
	if (uv.x < frame_min.x || uv.y < frame_min.y || uv.x > frame_max.x || uv.y > frame_max.y) {
		return 0.0;
	}
	return texture(tex, uv).a;
}

void fragment() {
	// COLOR already contains the sprite's texture color (and modulate).
	vec4 col = COLOR;

	if (intensity > 0.0) {
		vec2 px = TEXTURE_PIXEL_SIZE * outline_width;
		float a = 0.0;
		a = max(a, alpha_at(TEXTURE, UV + vec2(px.x, 0.0)));
		a = max(a, alpha_at(TEXTURE, UV - vec2(px.x, 0.0)));
		a = max(a, alpha_at(TEXTURE, UV + vec2(0.0, px.y)));
		a = max(a, alpha_at(TEXTURE, UV - vec2(0.0, px.y)));
		a = max(a, alpha_at(TEXTURE, UV + px));
		a = max(a, alpha_at(TEXTURE, UV - px));
		a = max(a, alpha_at(TEXTURE, UV + vec2(px.x, -px.y)));
		a = max(a, alpha_at(TEXTURE, UV + vec2(-px.x, px.y)));

		float edge = clamp(a - col.a, 0.0, 1.0);
		float pulse = 1.0 - pulse_amount * 0.5 * (1.0 + sin(TIME * pulse_speed));
		vec4 outline = outline_color;
		outline.a *= edge * intensity * pulse;

		col = mix(outline, col, col.a);
	}
	COLOR = col;
}
