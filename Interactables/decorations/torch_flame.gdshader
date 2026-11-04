shader_type canvas_item;
// Recolors the torch flame. Only the 4 flame colors of the original green
// sprite are swapped; the handle stays untouched. Pick colors with the
// TorchColor script ("Flame Color" in the Inspector).

// Original flame colors in the sprite sheet (outline -> core).
const vec3 SRC_DARK = vec3(34.0, 51.0, 22.0) / 255.0;
const vec3 SRC_MID = vec3(61.0, 161.0, 0.0) / 255.0;
const vec3 SRC_LIGHT = vec3(165.0, 214.0, 54.0) / 255.0;
const vec3 SRC_CORE = vec3(135.0, 246.0, 235.0) / 255.0;

uniform vec4 flame_dark : source_color = vec4(0.133, 0.2, 0.086, 1.0);
uniform vec4 flame_mid : source_color = vec4(0.239, 0.631, 0.0, 1.0);
uniform vec4 flame_light : source_color = vec4(0.647, 0.839, 0.212, 1.0);
uniform vec4 flame_core : source_color = vec4(0.529, 0.965, 0.922, 1.0);
// > 1 makes the flame glow brighter.
uniform float brightness : hint_range(0.5, 3.0) = 1.0;
// Subtle brightness flicker on the flame (0 = off).
uniform float flicker : hint_range(0.0, 0.5) = 0.08;
uniform float flicker_speed = 9.0;
// Offsets the flicker so torches next to each other don't pulse in sync.
uniform float flicker_offset = 0.0;

const float TOL = 0.06;

varying vec4 modulate_color;

void vertex() {
	modulate_color = COLOR;
}

bool is_col(vec3 c, vec3 src) {
	return distance(c, src) < TOL;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 target = c.rgb;
	bool flame = true;
	if (is_col(c.rgb, SRC_DARK)) {
		target = flame_dark.rgb;
	} else if (is_col(c.rgb, SRC_MID)) {
		target = flame_mid.rgb;
	} else if (is_col(c.rgb, SRC_LIGHT)) {
		target = flame_light.rgb;
	} else if (is_col(c.rgb, SRC_CORE)) {
		target = flame_core.rgb;
	} else {
		flame = false;
	}
	if (flame) {
		float t = TIME * flicker_speed + flicker_offset;
		float f = 1.0 + flicker * (sin(t) * 0.6 + sin(t * 2.37 + 1.3) * 0.4);
		target *= brightness * f;
	}
	COLOR = vec4(target, c.a) * modulate_color;
}
