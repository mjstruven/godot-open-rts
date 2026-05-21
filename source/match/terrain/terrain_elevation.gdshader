shader_type spatial;

uniform sampler2D color_texture : filter_nearest;
uniform sampler2D height_texture : filter_linear;
uniform float height_scale = 1.0;
uniform vec2 map_size = vec2(128.0, 128.0);

void vertex() {
	// World XZ → [0,1] UV matching get_visual_height_at(): world 0 → texel 0, world map_size → texel max.
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 sample_uv = clamp(world_pos.xz / map_size, 0.0, 1.0);
	float h = texture(height_texture, sample_uv).r;
	VERTEX.y += h * height_scale;

	float eps = 1.0 / 256.0;
	float hL = texture(height_texture, clamp(sample_uv - vec2(eps, 0.0), 0.0, 1.0)).r;
	float hR = texture(height_texture, clamp(sample_uv + vec2(eps, 0.0), 0.0, 1.0)).r;
	float hD = texture(height_texture, clamp(sample_uv - vec2(0.0, eps), 0.0, 1.0)).r;
	float hU = texture(height_texture, clamp(sample_uv + vec2(0.0, eps), 0.0, 1.0)).r;

	float step = 1.0;

	vec3 tangent = vec3(2.0 * step, (hR - hL) * height_scale, 0.0);
	vec3 bitangent = vec3(0.0, (hU - hD) * height_scale, 2.0 * step);

	NORMAL = normalize(cross(bitangent, tangent));
}

void fragment() {
	ALBEDO = texture(color_texture, UV).rgb;
}
