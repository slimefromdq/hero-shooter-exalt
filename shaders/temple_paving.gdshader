shader_type spatial;
render_mode diffuse_burley;
varying vec3 world_position;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 grid = fract(world_position.xz / 4.0);
	float edge = min(min(grid.x, 1.0-grid.x), min(grid.y, 1.0-grid.y));
	float grout = smoothstep(0.008, 0.017, edge);
	vec2 tile = floor(world_position.xz / 4.0);
	float variation = fract(sin(dot(tile, vec2(127.1, 311.7))) * 43758.5453);
	vec3 stone = mix(vec3(0.43,0.48,0.44), vec3(0.63,0.62,0.51), variation * 0.6 + 0.25);
	ALBEDO = mix(stone * 0.58, stone, grout);
	ROUGHNESS = 0.92;
}
