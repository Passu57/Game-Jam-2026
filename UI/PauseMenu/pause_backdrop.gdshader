shader_type canvas_item;
// Pause backdrop: the world behind the menu softly blurs, loses most of its
// color (the spark's light "goes out" while paused), darkens toward the edges
// and keeps a faint warm glow in the middle where the menu sits.
// progress: 0 = normal game view, 1 = fully paused look.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float blur_lod = 2.4;
uniform float desaturate : hint_range(0.0, 1.0) = 0.8;
uniform float darken : hint_range(0.0, 1.0) = 0.5;
uniform vec4 shade : source_color = vec4(0.04, 0.04, 0.06, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.72, 0.3, 1.0);
uniform float glow_strength = 0.07;
uniform float time_offset = 0.0;

void fragment() {
	float p = progress;
	float lod = blur_lod * p;
	vec2 px = SCREEN_PIXEL_SIZE * (1.0 + lod * 2.0);

	// 5-tap soft blur on top of the mip level.
	vec3 c = textureLod(screen_tex, SCREEN_UV, lod).rgb * 0.4;
	c += textureLod(screen_tex, SCREEN_UV + vec2(px.x, 0.0), lod).rgb * 0.15;
	c += textureLod(screen_tex, SCREEN_UV - vec2(px.x, 0.0), lod).rgb * 0.15;
	c += textureLod(screen_tex, SCREEN_UV + vec2(0.0, px.y), lod).rgb * 0.15;
	c += textureLod(screen_tex, SCREEN_UV - vec2(0.0, px.y), lod).rgb * 0.15;

	float g = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(g), desaturate * p);
	c = mix(c, shade.rgb, darken * p);

	vec2 d = (UV - 0.5) * vec2(1.7, 1.0);
	float dist = length(d);
	float vig = smoothstep(0.35, 0.95, dist);
	c *= 1.0 - vig * 0.75 * p;

	// Warm light from the spark, breathing slowly.
	float breathe = 0.85 + 0.15 * sin(TIME * 1.7 + time_offset);
	float glow = 1.0 - smoothstep(0.0, 0.5, dist);
	c += glow_color.rgb * glow * glow_strength * breathe * p;

	COLOR = vec4(c, 1.0);
}
