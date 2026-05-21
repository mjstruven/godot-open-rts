shader_type spatial;

uniform sampler2D color_texture : filter_nearest;
uniform sampler2D height_texture : filter_linear;
uniform float height_scale = 1.0;
uniform vec2 map_size = vec2(128.0, 128.0);

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// GPU texture UV.y=0 is the bottom of the image (OpenGL convention), opposite to CPU Image row 0 (top).
	// Flip UV.y so the shader reads the same texel as get_visual_height_at() for the same world_z.
	vec2 sample_uv = clamp(world_pos.xz / map_size, 0.0, 1.0);
	sample_uv.y = 1.0 - sample_uv.y;
	float h = texture(height_texture, sample_uv).r;
	VERTEX.y += h * height_scale;

	float eps = 1.0 / 256.0;
	float hL = texture(height_texture, clamp(sample_uv - vec2(eps, 0.0), 0.0, 1.0)).r;
	float hR = texture(height_texture, clamp(sample_uv + vec2(eps, 0.0), 0.0, 1.0)).r;
	float hD = texture(height_texture, clamp(sample_uv - vec2(0.0, eps), 0.0, 1.0)).r;
	float hU = texture(height_texture, clamp(sample_uv + vec2(0.0, eps), 0.0, 1.0)).r;

	float step = 1.0;

	vec3 tangent = vec3(2.0 * step, (hR - hL) * height_scale, 0.0);
	// After Y-flip, hD is the +Z world neighbor and hU is the -Z neighbor; swap sign to keep lighting correct.
	vec3 bitangent = vec3(0.0, (hD - hU) * height_scale, 2.0 * step);

	NORMAL = normalize(cross(bitangent, tangent));
}

void fragment() {
	ALBEDO = texture(color_texture, UV).rgb;
}
