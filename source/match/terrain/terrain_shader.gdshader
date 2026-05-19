shader_type spatial;

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

	// Detect exact terrain type by rounded vertex color pattern.
	// round() snaps GPU-interpolated values back to 0 or 1,
	// giving hard but clean terrain boundaries.
	// GRASSLAND:  R=1 G=0 B=0
	// FOREST:     R=0 G=1 B=0
	// ROCKY:      R=0 G=0 B=1
	// FERTILE:    R=1 G=1 B=0
	// FORD:       R=0 G=1 B=1
	// ELEVATED:   R=1 G=0 B=1

	if (vc.r > 0.5 && vc.g < 0.5 && vc.b < 0.5) {
		// GRASSLAND — red only
		final_color = texture(grassland_texture, uv);
	}
	else if (vc.r < 0.5 && vc.g > 0.5 && vc.b < 0.5) {
		// FOREST — green only
		final_color = texture(forest_texture, uv);
	}
	else if (vc.r < 0.5 && vc.g < 0.5 && vc.b > 0.5) {
		// ROCKY — blue only
		final_color = texture(rocky_texture, uv);
	}
	else if (vc.r > 0.5 && vc.g > 0.5 && vc.b < 0.5) {
		// FERTILE — red+green
		final_color = texture(fertile_texture, uv);
	}
	else if (vc.r < 0.5 && vc.g > 0.5 && vc.b > 0.5) {
		// FORD — green+blue
		final_color = texture(ford_texture, uv);
	}
	else if (vc.r > 0.5 && vc.g < 0.5 && vc.b > 0.5) {
		// ELEVATED — red+blue
		final_color = texture(elevated_texture, uv);
	}
	else {
		// Fallback — all-zero (black) or all-one (white) vertex color
		final_color = texture(grassland_texture, uv);
	}

	ALBEDO = final_color.rgb;
}
