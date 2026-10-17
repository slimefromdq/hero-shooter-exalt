shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.5);
uniform float surface_roughness = 0.7;
uniform float surface_metallic = 0.0;
uniform float masonry_strength = 0.15;
uniform float wet_paving = 0.0;
uniform sampler2DArray static_irradiance : filter_linear, repeat_disable;
varying vec3 city_position;
varying vec3 city_normal;

void vertex() {
	city_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	city_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	// Subtle weathering is tied to city space, so repeated kit pieces never tile visibly.
	float weather = sin(city_position.x * 4.71 + city_position.z * 2.13)
		* sin(city_position.y * 5.17 + city_position.z * 1.89);
	vec2 stone_uv = abs(city_normal.x) > 0.5 ? city_position.zy : city_position.xy;
	if (abs(city_normal.y) > 0.5) { stone_uv = city_position.xz * 0.55; }
	float row = floor(stone_uv.y / 0.62);
	vec2 brick = vec2(stone_uv.x + mod(row, 2.0) * 0.65, stone_uv.y) / vec2(1.3, 0.62);
	vec2 joint = fract(brick);
	vec2 aa = max(fwidth(brick), vec2(0.002));
	vec2 seam = vec2(1.0) - smoothstep(vec2(0.012), vec2(0.012) + aa, joint);
	float variation = fract(sin(dot(floor(brick), vec2(127.1, 311.7))) * 43758.5453);
	float near_detail = 1.0 - smoothstep(30.0, 75.0, distance(CAMERA_POSITION_WORLD, city_position));
	float masonry = (max(seam.x, seam.y) * 0.8 + variation * 0.2) * masonry_strength * near_detail;
	ALBEDO = base_color.rgb * (0.97 + weather * 0.03 - masonry);
	float puddle = smoothstep(0.1, 0.8, sin(city_position.x * 0.4 + sin(city_position.z * 0.3)) * sin(city_position.z * 0.57));
	ROUGHNESS = clamp(surface_roughness + weather * 0.035 - puddle * wet_paving, 0.10, 1.0);
	METALLIC = surface_metallic;
	vec2 uv = (city_position.xz + vec2(72.0, 66.0)) / vec2(144.0, 132.0);
	float level = city_position.y < -2.0 ? 0.0 : (city_position.y > 3.8 ? 2.0 : 1.0);
	float floor_y = level < 0.5 ? -5.0 : (level > 1.5 ? 6.5 : 0.0);
	vec3 baked = texture(static_irradiance, vec3(uv, level)).rgb;
	// Baked indirect lamp pools supplement the real sun and four main local lamps.
	EMISSION = base_color.rgb * baked * exp(-abs(city_position.y - floor_y) * 0.24) * 1.05;
}
