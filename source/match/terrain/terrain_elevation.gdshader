shader_type spatial;
render_mode unshaded;

uniform sampler2D color_texture : filter_nearest;
uniform sampler2D height_texture : filter_linear;
uniform float height_scale = 1.0;

void vertex() {
	float h = texture(height_texture, UV).r;
	VERTEX.y += h * height_scale;
}

void fragment() {
	ALBEDO = texture(color_texture, UV).rgb;
}
