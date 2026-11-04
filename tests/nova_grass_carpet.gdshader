shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;

uniform float wind_strength = 0.045;
varying vec3 blade_colour;

void vertex() {
	float tip = clamp(VERTEX.y / 0.65, 0.0, 1.0);
	vec3 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float distance_xz = length(world_position.xz - CAMERA_POSITION_WORLD.xz);
	float distance_fade = 1.0 - smoothstep(23.0, 38.0, distance_xz);
	float breeze = sin(TIME * 1.15 + world_position.x * 0.085 + world_position.z * 0.067);
	VERTEX.x += breeze * wind_strength * tip * tip * distance_fade;
	VERTEX.y *= distance_fade;
	NORMAL = vec3(0.0, 1.0, 0.0);
	blade_colour = COLOR.rgb;
}

void fragment() {
	ALBEDO = blade_colour;
	ROUGHNESS = 1.0;
}
