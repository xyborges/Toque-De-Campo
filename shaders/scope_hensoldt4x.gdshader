shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
uniform sampler2D optical_view : source_color, filter_linear, repeat_disable;
uniform bool live_view = false;
void fragment() {
	vec2 p = UV - vec2(0.5);
	float radius = length(p);
	if (radius > 0.5) discard;
	vec3 scene = live_view ? texture(optical_view, UV).rgb : vec3(0.035,0.075,0.07);
	scene *= 1.0 - smoothstep(0.38,0.5,radius)*0.94;
	// Hensoldt-style thick three-post aiming pattern, centered fine point.
	float horizontal = (1.0-smoothstep(0.004,0.007,abs(p.y))) * step(0.07,abs(p.x)) * (1.0-smoothstep(0.36,0.45,abs(p.x)));
	float lower = (1.0-smoothstep(0.013,0.023,abs(p.x))) * step(0.07,p.y) * (1.0-smoothstep(0.27,0.38,p.y));
	float fine = (1.0-smoothstep(0.001,0.0027,abs(p.x))) * step(0.019,abs(p.y)) * (1.0-step(0.055,abs(p.y)));
	float reticle = max(max(horizontal,lower),fine);
	ALBEDO=mix(scene,vec3(0.01,0.012,0.01),reticle);
}
