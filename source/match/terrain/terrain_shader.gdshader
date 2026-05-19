shader_type spatial;
render_mode unshaded;

uniform sampler2D grassland_texture;
uniform sampler2D forest_texture;
uniform sampler2D rocky_texture;
uniform sampler2D fertile_texture;
uniform sampler2D ford_texture;
uniform sampler2D elevated_texture;
uniform float texture_scale = 0.05;

void fragment() {
	vec3 vc = round(COLOR.rgb);
	vec2 uv = UV * texture_scale * 256.0;
	vec4 final_color = vec4(0.0);
	if (vc.r > 0.5 && vc.g < 0.5 && vc.b < 0.5) {
		final_color = texture(grassland_texture, uv);
	} else if (vc.r < 0.5 && vc.g > 0.5 && vc.b < 0.5) {
		final_color = texture(forest_texture, uv);
	} else if (vc.r < 0.5 && vc.g < 0.5 && vc.b > 0.5) {
		final_color = texture(rocky_texture, uv);
	} else if (vc.r > 0.5 && vc.g > 0.5 && vc.b < 0.5) {
		final_color = texture(fertile_texture, uv);
	} else if (vc.r < 0.5 && vc.g > 0.5 && vc.b > 0.5) {
		final_color = texture(ford_texture, uv);
	} else if (vc.r > 0.5 && vc.g < 0.5 && vc.b > 0.5) {
		final_color = texture(elevated_texture, uv);
	} else {
		final_color = texture(grassland_texture, uv);
	}
	ALBEDO = final_color.rgb;
}
