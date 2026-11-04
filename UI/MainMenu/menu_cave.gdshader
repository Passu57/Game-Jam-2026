shader_type canvas_item;
// One drifting, colorless cave layer for the main menu.
// The world has lost its color, so everything back here is grey.

// How fast the layer drifts sideways (texture widths per second).
uniform float speed = 0.004;
// Rect aspect / texture aspect, so the cave isn't stretched.
uniform float uv_scale_x = 0.889;
// Cold grey tint and brightness of this layer.
uniform vec4 tint : source_color = vec4(0.62, 0.66, 0.78, 1.0);
uniform float brightness = 1.0;
// Slow up/down sway (fraction of the height) and a per-layer offset.
uniform float bob = 0.004;
uniform float phase = 0.0;

void fragment() {
	vec2 uv = vec2(UV.x * uv_scale_x + TIME * speed + phase,
		UV.y + sin(TIME * 0.25 + phase * 6.0) * bob);
	uv.x = fract(uv.x);
	uv.y = clamp(uv.y, 0.0, 1.0);
	vec4 c = texture(TEXTURE, uv);
	float g = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(vec3(g) * tint.rgb * brightness, c.a);
}
