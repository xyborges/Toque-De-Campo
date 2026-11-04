shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
uniform sampler2D optical_view : source_color, filter_linear, repeat_disable;
uniform bool live_view = false;
void fragment() {
	vec2 p = UV - vec2(0.5);
	float radius = length(p);
	if (radius > 0.5) { discard; }
	vec3 scene = live_view ? texture(optical_view, UV).rgb : vec3(0.035, 0.10, 0.105);
	float edge = smoothstep(0.36, 0.50, radius);
	scene *= 1.0 - edge * 0.92;
	// Etched reticle belongs to the physical lens, not the screen HUD.
	float line = min(abs(p.x), abs(p.y));
	float reticle = (1.0 - smoothstep(0.0015, 0.0035, line)) * step(0.018, radius);
	for (int i = 1; i <= 4; i++) {
		float y = float(i) * 0.055;
		reticle = max(reticle, (1.0 - smoothstep(0.0015, 0.003, abs(p.y-y))) * (1.0-step(0.018,p.x)) * step(-0.018,p.x));
	}
	ALBEDO = mix(scene, vec3(0.008, 0.012, 0.008), reticle);
}
