shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;

// Laboratory-only candidate. Reuses the existing grass geometry and batches.
// Wind is off for the first isolated material measurement.
uniform float wind_strength = 0.0;
varying vec3 grass_colour;

void vertex() {
	float blade_height = clamp((VERTEX.y + 0.06) / 0.7, 0.0, 1.0);
	vec3 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float breeze = sin(TIME * 1.25 + world_position.x * 0.08 + world_position.z * 0.065);
	VERTEX.x += breeze * wind_strength * blade_height * blade_height;
	NORMAL = vec3(0.0, 1.0, 0.0);
	vec3 original = COLOR.rgb;
	grass_colour = original * mix(0.84, 1.22, blade_height);
}

void fragment() {
	ALBEDO = grass_colour;
	ROUGHNESS = 1.0;
}
