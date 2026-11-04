shader_type canvas_item;
// Makes blue grass pixels glow softly. Put this on a TileMapLayer's material.
// glow_strength is driven by color_glow.gd: 0 until Blue is unlocked, then 1.
// The soil (dark, not blue) is left exactly as it is.

uniform float glow_strength : hint_range(0.0, 1.0) = 0.0;
// Glow color. Keep it blue so the color system shows it once Blue is unlocked.
uniform vec4 glow_color : source_color = vec4(0.45, 0.56, 1.0, 1.0);
// How much the grass itself brightens.
uniform float brightness : hint_range(0.0, 1.0) = 0.25;
// How visible the soft halo around the grass is.
uniform float halo_amount : hint_range(0.0, 1.0) = 0.45;
// Halo size in pixels.
uniform float halo_radius : hint_range(0.0, 4.0) = 2.0;
// Slow shimmer that travels across the level.
uniform float pulse_speed = 1.6;
uniform float pulse_amount : hint_range(0.0, 1.0) = 0.35;
uniform float wave_length = 120.0;
// Size of one tile in the tileset image.
uniform vec2 tile_size = vec2(16.0, 16.0);

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

// 1 for blue grass pixels, 0 for soil and empty space.
float grass_mask(vec4 c) {
	return c.a * smoothstep(0.12, 0.30, c.b - c.r);
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	if (glow_strength <= 0.001) {
		COLOR = base;
	} else {
		vec2 tex_size = vec2(textureSize(TEXTURE, 0));
		vec2 px = UV * tex_size;
		// Stay inside this tile so neighbouring tiles in the atlas don't leak in.
		vec2 cell_min = floor(px / tile_size) * tile_size + 0.5;
		vec2 cell_max = cell_min + tile_size - 1.0;

		float halo = 0.0;
		float total = 0.0;
		for (int ix = -2; ix <= 2; ix++) {
			for (int iy = -2; iy <= 2; iy++) {
				vec2 o = vec2(float(ix), float(iy)) * (halo_radius * 0.5);
				float w = 1.0 / (1.0 + dot(o, o));
				vec2 p = clamp(px + o, cell_min, cell_max);
				halo += grass_mask(texture(TEXTURE, p / tex_size)) * w;
				total += w;
			}
		}
		halo /= total;

		float wave = 0.5 + 0.5 * sin(TIME * pulse_speed + world_pos.x / wave_length * 6.2832);
		float pulse = (1.0 - pulse_amount) + pulse_amount * wave;
		float g = glow_strength * pulse;

		vec3 lit = base.rgb + glow_color.rgb * grass_mask(base) * brightness * g;
		// Halo shows on the empty pixels around the grass.
		float halo_a = halo * halo_amount * g * (1.0 - base.a);
		float out_a = base.a + halo_a;
		vec3 out_rgb = (lit * base.a + glow_color.rgb * halo_a) / max(out_a, 0.0001);
		COLOR = vec4(out_rgb, clamp(out_a, 0.0, 1.0));
	}
}
