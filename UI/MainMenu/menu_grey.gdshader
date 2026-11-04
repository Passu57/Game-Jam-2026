shader_type canvas_item;
// Turns a sprite grey (with a cold tint), like the colorless world.
uniform vec4 tint : source_color = vec4(0.86, 0.89, 0.96, 1.0);
uniform float brightness = 1.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float g = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(vec3(g) * tint.rgb * brightness, c.a);
}
