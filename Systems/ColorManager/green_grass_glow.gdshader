shader_type canvas_item;
// Subtle glow for GREEN grass on a TileMapLayer, with "sudden" moments:
//  - a faint halo along the grass,
//  - random grass tiles that briefly flash brighter (like fireflies),
//  - a soft wave of light that now and then rolls across the level.
// glow_strength is driven by color_glow.gd (0 until Green is unlocked).
// Soil and everything that isn't green grass is left alone.

uniform float glow_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 glow_color : source_color = vec4(0.45, 1.0, 0.45, 1.0);
// Always-on part (keep it low for a subtle look).
uniform float base_brightness : hint_range(0.0, 1.0) = 0.08;
uniform float halo_amount : hint_range(0.0, 1.0) = 0.18;
uniform float halo_radius : hint_range(0.0, 4.0) = 2.0;

// Sudden tile flashes.
uniform float flash_brightness : hint_range(0.0, 1.5) = 0.45;
// About how many seconds between flashes of the same tile.
uniform float flash_every = 7.0;
// How long one flash lasts (seconds).
uniform float flash_length = 0.6;

// Rolling wave of light.
uniform float wave_brightness : hint_range(0.0, 1.0) = 0.25;
uniform float wave_speed = 0.35;
uniform float wave_length = 220.0;
// Higher = thinner, rarer-looking wave band.
uniform float wave_sharpness = 10.0;

uniform vec2 tile_size = vec2(16.0, 16.0);

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// 1 for green grass pixels, 0 for soil (brown) and empty space.
float grass_mask(vec4 c) {
	float greenish = smoothstep(0.10, 0.28, c.g - c.b);
	float not_brown = step(c.r, c.g + 0.04);
	return c.a * greenish * not_brown;
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	if (glow_strength <= 0.001) {
		COLOR = base;
	} else {
		vec2 tex_size = vec2(textureSize(TEXTURE, 0));
		vec2 px = UV * tex_size;
		vec2 cell_min = floor(px / tile_size) * tile_size + 0.5;
		vec2 cell_max = cell_min + tile_size - 1.0;

		// Soft halo from nearby grass pixels (stays inside this tile).
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

		// Sudden flash: each world tile flashes once every ~flash_every
		// seconds, at its own random moment. Quick rise, slower fade.
		vec2 tile_id = floor(world_pos / tile_size);
		float rnd = hash(tile_id);
		float period = flash_every * (0.7 + 0.6 * hash(tile_id + 17.0));
		float t = mod(TIME + rnd * period, period);
		float flash = smoothstep(0.0, 0.08, t) * (1.0 - smoothstep(0.08, flash_length, t));

		// Rare rolling wave: a thin bright band drifting across the level.
		float w_raw = 0.5 + 0.5 * sin(TIME * wave_speed * 6.2832 - (world_pos.x + world_pos.y * 0.3) / wave_length * 6.2832);
		float wave = pow(w_raw, wave_sharpness);

		float g = glow_strength * (base_brightness + flash * flash_brightness + wave * wave_brightness);
		float mask = grass_mask(base);
		vec3 lit = base.rgb + glow_color.rgb * mask * g;

		float halo_strength = glow_strength * (halo_amount * (1.0 + flash * 2.0 + wave * 1.5));
		float halo_a = halo * halo_strength * (1.0 - base.a);
		float out_a = base.a + halo_a;
		vec3 out_rgb = (lit * base.a + glow_color.rgb * halo_a) / max(out_a, 0.0001);
		COLOR = vec4(out_rgb, clamp(out_a, 0.0, 1.0));
	}
}
