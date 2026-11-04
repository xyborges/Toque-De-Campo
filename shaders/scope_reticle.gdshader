shader_type canvas_item;
render_mode unshaded;

uniform float aspect = 1.6;
uniform float pixel_size = 0.00125;
// A first focal plane reticle: centre-to-centre marker spacing is one mrad.
// CPU derives the projected spacing from the active camera's vertical FOV.
uniform float mrad_spacing = 0.004;

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
	COLOR = vec4(vec3(0.015, 0.02, 0.015), max(edge, inner * (1.0 - edge)));
}
