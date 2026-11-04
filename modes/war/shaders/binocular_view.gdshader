shader_type canvas_item;
render_mode unshaded;

uniform float aspect = 1.777778;

void fragment() {
	vec2 p = (UV - vec2(0.5)) * vec2(aspect, 1.0);
	float lens = min(length(p - vec2(-0.16, 0.0)), length(p - vec2(0.16, 0.0)));
	// Optical edge only: binoculars do not inherit a weapon's crosshair.
	float border = smoothstep(0.29, 0.365, lens);
	COLOR = vec4(vec3(0.008, 0.012, 0.009), border);
}
