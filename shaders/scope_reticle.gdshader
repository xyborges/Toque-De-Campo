shader_type canvas_item;
render_mode unshaded;

uniform float aspect = 1.6;
uniform float pixel_size = 0.00125;
// A first focal plane reticle: centre-to-centre marker spacing is one mrad.
// CPU derives the projected spacing from the active camera's vertical FOV.
uniform float mrad_spacing = 0.004;
// 0=standard scope, 1=integral PGO-7, 2=FIM-92 aperture/seeker.
uniform int launcher_mode = 0;

void fragment() {
	vec2 p = (UV - vec2(0.5)) * vec2(aspect, 1.0);
	float radius = length(p);
	float edge = smoothstep(0.397, 0.403, radius);
	float hair_width = pixel_size * 0.30;
	float crosshair = 1.0 - smoothstep(hair_width, hair_width + pixel_size * 0.55, min(abs(p.x), abs(p.y)));
	vec2 nearest = floor(p / mrad_spacing + vec2(0.5));
	vec2 horizontal = vec2(nearest.x * mrad_spacing, 0.0);
	vec2 vertical = vec2(0.0, nearest.y * mrad_spacing);
	float major_x = 1.0 - step(0.1, abs(mod(abs(nearest.x), 5.0)));
	float major_y = 1.0 - step(0.1, abs(mod(abs(nearest.y), 5.0)));
	float dot_size = clamp(mrad_spacing * 0.24, pixel_size * 0.95, pixel_size * 1.8);
	float dot_x = (1.0 - smoothstep(dot_size * (1.0 + major_x * 0.4), dot_size * (1.0 + major_x * 0.4) + pixel_size * 0.5, length(p - horizontal))) * step(0.5, abs(nearest.x)) * step(abs(nearest.x), 40.0);
	float dot_y = (1.0 - smoothstep(dot_size * (1.0 + major_y * 0.4), dot_size * (1.0 + major_y * 0.4) + pixel_size * 0.5, length(p - vertical))) * step(0.5, abs(nearest.y)) * step(abs(nearest.y), 40.0);
	float inner = max(crosshair * 0.85, max(dot_x, dot_y));
	if (launcher_mode == 1) {
		// PGO-7 inspired engraved stadia: fixed side scale and falling aim chevrons.
		float horizontal = (1.0 - smoothstep(pixel_size * 0.5, pixel_size * 1.4, abs(p.y))) * (1.0 - step(0.15, abs(p.x)));
		float vertical = (1.0 - smoothstep(pixel_size * 0.45, pixel_size * 1.2, abs(p.x))) * step(0.0, p.y) * (1.0 - step(0.105, p.y));
		float stadia = 0.0;
		for (int i = 1; i <= 5; i++) {
			float y = float(i) * mrad_spacing * 3.0;
			float arms = mix(0.012, 0.003, float(i) / 5.0);
			float tick = (1.0 - smoothstep(pixel_size * 0.6, pixel_size * 1.4, abs(p.y - y))) * (1.0 - step(arms, abs(p.x)));
			stadia = max(stadia, tick);
		}
		float range_curve = 1.0 - smoothstep(pixel_size * 0.7, pixel_size * 1.4, abs(p.x + 0.11 - 0.24 * p.y));
		range_curve *= step(-0.09, p.y) * (1.0 - step(0.09, p.y));
		inner = max(max(horizontal, vertical), max(stadia, range_curve)) * 0.88;
	} else if (launcher_mode == 2) {
		// Seeker aperture with a clean central tracking ring and lead brackets.
		float ring = 1.0 - smoothstep(pixel_size * 0.75, pixel_size * 1.8, abs(radius - 0.055));
		float second_ring = 1.0 - smoothstep(pixel_size * 0.75, pixel_size * 1.8, abs(radius - 0.097));
		float centre = 1.0 - smoothstep(pixel_size * 0.8, pixel_size * 1.6, radius);
		float bracket = (1.0 - smoothstep(pixel_size * 0.6, pixel_size * 1.4, abs(abs(p.x) - 0.12))) * (1.0 - step(0.022, abs(p.y)));
		inner = max(max(ring * 0.95, second_ring * 0.32), max(centre, bracket));
	}
	COLOR = vec4(vec3(0.015, 0.02, 0.015), max(edge, inner * (1.0 - edge)));
}
