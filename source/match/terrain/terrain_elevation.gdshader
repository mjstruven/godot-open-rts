shader_type spatial;

uniform sampler2D color_texture : filter_nearest;
uniform sampler2D height_texture : filter_linear;
uniform float height_scale = 1.0;

void vertex() {
	vec2 uv = UV;
	float h = texture(height_texture, uv).r;
	VERTEX.y += h * height_scale;

	float eps = 1.0 / 256.0;
	float hL = texture(height_texture, uv - vec2(eps, 0.0)).r;
	float hR = texture(height_texture, uv + vec2(eps, 0.0)).r;
	float hD = texture(height_texture, uv - vec2(0.0, eps)).r;
	float hU = texture(height_texture, uv + vec2(0.0, eps)).r;

	float step = 1.0;

	vec3 tangent = vec3(2.0 * step, (hR - hL) * height_scale, 0.0);
	vec3 bitangent = vec3(0.0, (hU - hD) * height_scale, 2.0 * step);

	NORMAL = normalize(cross(bitangent, tangent));
}

void fragment() {
	ALBEDO = texture(color_texture, UV).rgb;
}
