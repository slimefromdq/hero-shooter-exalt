shader_type spatial;
render_mode blend_mix, cull_disabled;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
	float streak = sin(world_position.x*13.0 + world_position.z*7.0 + sin(world_position.y*0.6+TIME*3.0));
	float foam = smoothstep(0.3,1.0,sin(world_position.y*3.0+TIME*9.0+streak));
	ALBEDO = mix(vec3(0.22,0.55,0.62),vec3(0.76,0.91,0.89),foam);
	ROUGHNESS = 0.3;
	ALPHA = 0.72;
}
