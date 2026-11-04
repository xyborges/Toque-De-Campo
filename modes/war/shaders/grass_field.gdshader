shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;

uniform float wind_strength = 0.022;
uniform float near_end = 21.0;
uniform float far_end = 29.0;
uniform float storm = 0.0;
uniform float dry = 0.0;
uniform bool distant = false;
uniform bool prepared_field = false;
uniform float detail_fade_start = 52.0;
uniform float detail_end = 60.0;
uniform float distant_fade_start = 200.0;
uniform float distant_end = 220.0;
uniform vec3 observer_position = vec3(0.0);
varying vec3 blade_colour;
varying vec3 blade_normal_world;

void vertex() {
	float tip = UV.y;
	vec3 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float distance_xz = length(world_position.xz - CAMERA_POSITION_WORLD.xz);
	float fade = 1.0 - smoothstep(near_end, far_end, distance_xz);
	if (prepared_field) {
		distance_xz = length(world_position.xz - observer_position.xz);
		fade = distant ? smoothstep(detail_fade_start - 2.0, detail_end - 2.0, distance_xz) * (1.0 - smoothstep(distant_fade_start, distant_end, distance_xz)) : 1.0-smoothstep(detail_fade_start, detail_end, distance_xz);
	}
	float breeze = sin(TIME * 1.2 + world_position.x * 0.11 + world_position.z * 0.08);
	VERTEX.x += breeze * wind_strength * (1.0 + storm * 0.65) * tip * tip * fade;
	VERTEX.y *= fade;
	// Shared upward normals prevent the near blades facing away from light
	// while their distant representation remains lit. Keep normal lighting.
	NORMAL = vec3(0.0, 1.0, 0.0);
	blade_normal_world = normalize(MODEL_NORMAL_MATRIX * vec3(0.0,1.0,0.0));
	blade_colour = COLOR.rgb;
}

void fragment() {
	// Two-sided rasterization can flip back-face normals after vertex work.
	// Set the final lighting normal explicitly so both sides receive the
	// same terrain-oriented diffuse light, without making grass emissive.
	NORMAL = normalize((VIEW_MATRIX * vec4(blade_normal_world,0.0)).xyz);
	ALBEDO = mix(blade_colour, blade_colour * vec3(1.38, 1.08, 0.65), dry) * (1.0 - storm * 0.09);
	ROUGHNESS = mix(1.0, 0.78, storm);
}
