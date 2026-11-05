extends RefCounted

const PIXACAO := preload("res://modes/war/library/favela_pixacao.tscn")
const LITTER := preload("res://modes/war/library/favela_lixo_calcada.tscn")
const INK := "favela_paint_ink"

const WALL_SHADER := """
shader_type spatial;
render_mode specular_disabled;

uniform sampler2D plaster_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D brick_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D plaster_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D brick_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D cracks_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D grime_tex : filter_linear_mipmap, repeat_enable;
uniform float brick_bias = 0.0;
varying vec3 world_pos;
varying vec3 world_normal;
varying float base_height;
varying float variation;
varying float upkeep;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	base_height = (MODEL_MATRIX * vec4(0.0, -0.5, 0.0, 1.0)).y;
	variation = fract(dot(MODEL_MATRIX[3].xz, vec2(0.0731, 0.0537)));
	upkeep = step(0.69, fract(dot(floor(MODEL_MATRIX[3].xz / 61.0), vec2(0.362, 0.583))));
}

void fragment() {
	vec3 n = abs(normalize(world_normal));
	vec2 surface = n.y > 0.5 ? world_pos.xz :
		(n.x > n.z ? world_pos.zy : world_pos.xy);
	float height = world_pos.y - base_height;
	vec3 paint = texture(plaster_tex, surface * 0.57).rgb * COLOR.rgb;
	vec3 brick = texture(brick_tex, surface * 0.91).rgb * vec3(0.82, 0.70, 0.63);
	vec3 result = mix(paint, brick, brick_bias * 0.72);
	float masonry = brick_bias;
	if (length(VERTEX) < 150.0 && n.y < 0.6) {
		float broad = texture(grime_tex, surface * vec2(0.025, 0.043) + vec2(variation * 2.8, 0.0)).r;
		float fine = texture(grime_tex, surface * 0.31 + vec2(0.39, 0.13)).r;
		float streak = texture(grime_tex, surface * vec2(0.33, 0.032)).r;
		float level = broad * 0.88 + fine * 0.12;
		float threshold = 0.56 + variation * 0.18 + upkeep * 0.14 - brick_bias * 0.22;
		float exposed = smoothstep(threshold - 0.008, threshold + 0.009, level);
		float worn_edge = smoothstep(threshold - 0.033, threshold - 0.009, level);
		float damp = (1.0 - smoothstep(0.45, 1.8, height)) * (0.30 + streak * 0.38);
		float paint_band = (1.0 - smoothstep(1.08, 1.18, height)) * step(0.53, variation);
		paint = mix(paint, paint * vec3(0.68, 0.78, 0.82), paint_band * 0.70);
		paint *= 0.80 + fine * 0.29 - damp * (0.47 - upkeep * 0.21);
		paint *= 1.0 - smoothstep(0.57, 0.85, streak) * 0.35;

		vec2 course = surface / vec2(0.29, 0.095);
		course.x += mod(floor(course.y), 2.0) * 0.5;
		vec2 edge = abs(fract(course) - vec2(0.5));
		float mortar = max(smoothstep(0.440, 0.487, edge.x),
			smoothstep(0.410, 0.490, edge.y));
		vec3 fired = mix(vec3(0.245, 0.119, 0.078), vec3(0.41, 0.242, 0.163), fine);
		brick = mix(fired * (0.62 + brick * 0.60),
			vec3(0.235, 0.219, 0.182) * (0.84 + fine * 0.24), mortar);
		vec3 undercoat = mix(paint, vec3(0.43, 0.397, 0.34), worn_edge * 0.86);
		masonry = max(exposed, brick_bias * 0.96);
		vec3 detailed = mix(undercoat, brick, masonry);
		float crack = texture(cracks_tex, surface * vec2(0.107, 0.119) + vec2(variation, 0.0)).a;
		detailed *= 1.0 - crack * (0.72 - upkeep * 0.54) * (1.0 - masonry);
		result = mix(detailed, result, smoothstep(100.0, 150.0, length(VERTEX)));
	}
	NORMAL_MAP = mix(texture(plaster_normal, surface * 0.57).rgb,
		texture(brick_normal, surface * 0.91).rgb, masonry);
	NORMAL_MAP_DEPTH = 0.43;
	ALBEDO = result;
	ROUGHNESS = 0.99;
}
"""

const TERRAIN_SHADER := """
shader_type spatial;
render_mode specular_disabled;

uniform sampler2D street_mask : filter_linear_mipmap, repeat_disable;
uniform sampler2D ground_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D concrete_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D asphalt_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D wear_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float half_map = 750.0;
varying float hillside_gradient;

void vertex() {
	hillside_gradient = clamp(1.0 - abs(NORMAL.y), 0.0, 1.0);
}

void fragment() {
	vec2 world_xz = UV / 0.23;
	vec2 edge = 0.10 * vec2(sin(world_xz.y * 0.68 + world_xz.x * 0.11),
		cos(world_xz.x * 0.57 + world_xz.y * 0.17));
	vec3 surface = texture(street_mask, (world_xz + edge + vec2(half_map)) / (2.0 * half_map)).rgb;
	float coverage = clamp(surface.r + surface.g, 0.0, 1.0);
	vec3 ground = texture(ground_tex, UV * 0.72).rgb * COLOR.rgb;
	// Thin downhill runoff streaks and fragmented bare sediment break up
	// smooth slopes without changing any terrain collision or road surface.
	float channel = 1.0 - smoothstep(0.03, 0.20, abs(sin(
		world_xz.x * .19 + sin(world_xz.y * .037) * .77)));
	float cut = smoothstep(.12, .40, hillside_gradient);
	float sediment = sin(world_xz.x * .067 + world_xz.y * .032)
		* cos(world_xz.y * .071 - world_xz.x * .018);
	float erosion = cut * (channel * .20 + .07 * smoothstep(.10, .75, sediment));
	ground *= 1.0 - erosion * (1.0 - coverage);
	if (coverage > 0.005) {
		vec2 paving_uv = world_xz * 0.55;
		float worn = sin(world_xz.x * 0.65 + world_xz.y * 0.37)
			* cos(world_xz.y * 0.51 - world_xz.x * 0.18);
		vec3 tint = mix(vec3(0.714, 0.690, 0.651), vec3(0.929, 0.922, 0.886),
			smoothstep(-0.30, 0.65, worn));
		vec3 road = texture(asphalt_tex, paving_uv).rgb * vec3(0.53, 0.53, 0.51) * tint;
		vec3 lane = texture(concrete_tex, paving_uv).rgb * vec3(0.46, 0.45, 0.43) * tint;
		float material_mix = surface.r / max(coverage, 0.005);
		vec3 pavement = mix(lane, road, material_mix);
		float near_factor = 1.0 - smoothstep(30.0, 85.0, length(VERTEX));
		if (near_factor > 0.0) {
			vec4 wear = texture(wear_tex, paving_uv * 0.179);
			pavement = mix(pavement, wear.rgb, wear.a * near_factor * mix(0.79, 1.0, material_mix));
		}
		pavement = mix(pavement, vec3(0.55, 0.51, 0.38), surface.b * 0.7);
		ground = mix(ground, pavement, coverage);
	}
	ALBEDO = ground;
	ROUGHNESS = 1.0;
}
"""

# Textured outlines, tar repairs, old utility cuts and branched cracks.
# Authored in a small reusable tile and mipmapped before upload.
const PAVING_WEAR := """
<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">
  <path fill="#42464a" fill-opacity=".56" stroke="#76736a" stroke-opacity=".38" stroke-width="2.2"
    d="M32 66 L70 57 102 65 144 59 153 71 150 110 157 131 132 146 81 143 74 136 43 135 36 114 29 95Z
       M303 290 L329 282 361 289 379 280 422 299 433 349 416 371 374 378 320 363 310 339Z"/>
  <path fill="#75766f" fill-opacity=".34"
    d="M219 358 L231 337 260 332 278 348 279 384 264 399 232 403 216 383Z
       M354 63 L378 44 421 43 439 59 436 91 407 109 360 100Z"/>
  <path fill="none" stroke="#28292a" stroke-opacity=".76" stroke-width="2.4" stroke-linejoin="round"
    d="M76 38l7 12 -4 9 8 11 -1 15 12 9 3 15 18 4 9 15 19 8 3 12 21 7 11 16
       M114 115l-6 16 -15 7 -2 15 -18 16 -6 16 -13 9 3 14 -14 12
       M288 241l-4 17 13 12 11 1 8 12 2 20 14 10 3 22 15 11 4 21 19 11 4 15 24 11 7 18
       M338 340l-12 11 -17 4 -13 15 -10 -2 -12 12 -18 4 -15 18 -17 -1
       M404 57l-6 12 4 14 -18 8 -4 17 -11 4 3 18 -19 15 -7 15 -18 3 -2 12 -17 15
       M368 112l-15 -5 -11 8 -18 -3 -9 -9 -15 6 -12 -9 -21 2"/>
  <path fill="none" stroke="#252625" stroke-opacity=".56" stroke-width="1.35"
    d="M92 79l-12 5 -11 12 -14 -2 -9 12 -15 -2
       M127 127l11 -9 9 1 10 -8 19 3 11 -13
       M321 307l-16 8 -13 -3 -11 13 -17 0 -9 10
       M376 376l9 -14 15 -4 10 4 14 -9 7 -17
       M382 94l10 7 14 1 9 12 15 3 8 13 15 3
       M236 369l17 -11 11 1 14 -11 18 2"/>
  <path fill="none" stroke="#232527" stroke-opacity=".34" stroke-width="1.1" stroke-dasharray="2 5"
    d="M24 118l58 31 43 9 35 18 24 3 M294 363l33 13 45 10 59 -11 24 -18 M343 58l20 -15 73 -2"/>
</svg>
"""

const WALL_CRACKS := """
<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">
 <path fill="none" stroke="#121212" stroke-opacity=".82" stroke-width="1.35" stroke-linejoin="round"
 d="M77 0l-4 35 8 18 -2 26 12 21 -6 25 14 14 -2 21 10 28 -4 31 9 15 -5 18 9 25 -3 26 6 22
 M94 147l-18 9 -3 14 -18 9 -11 21 -19 12 -2 22
 M107 228l16 13 8 22 17 9 8 23
 M344 194l-6 23 9 15 -5 20 10 25 -4 17 9 32 -4 21 9 26 -3 38 8 21 -6 35 9 20
 M358 333l19 -9 7 -15 19 -5 6 -18
 M366 421l-17 -7 -8 -21 -19 -2 -4 -13"/>
 <path fill="none" stroke="#111111" stroke-opacity=".48" stroke-width=".75"
 d="M77 68l-15 8 -7 18 -9 3 M85 123l24 -12 7 -16 14 -3
 M348 253l17 -5 8 -17 14 -8 M364 375l-13 7 -8 -5 -10 9 -16 -3"/>
</svg>
"""

static var wall_paint: ShaderMaterial
static var wall_brick: ShaderMaterial
static var tag_meshes: Array[Mesh]=[]

static func _material(code: String) -> ShaderMaterial:
	var shader:=Shader.new()
	shader.code=code
	var material:=ShaderMaterial.new()
	material.shader=shader
	return material

static func paint_walls(parent: Node3D) -> void:
	if wall_paint==null:
		var noise:=FastNoiseLite.new()
		noise.seed=614106
		noise.frequency=.035
		noise.fractal_octaves=4
		var grit:=noise.get_seamless_image(192,192)
		grit.generate_mipmaps()
		wall_paint=_material(WALL_SHADER)
		wall_paint.set_shader_parameter("grime_tex",ImageTexture.create_from_image(grit))
		wall_paint.set_shader_parameter("plaster_tex",EnvironmentKit.material("plaster").albedo_texture)
		wall_paint.set_shader_parameter("brick_tex",EnvironmentKit.material("brick").albedo_texture)
		wall_paint.set_shader_parameter("plaster_normal",EnvironmentKit.material("plaster").normal_texture)
		wall_paint.set_shader_parameter("brick_normal",EnvironmentKit.material("brick").normal_texture)
		var cracks:=Image.new()
		cracks.load_svg_from_string(WALL_CRACKS)
		cracks.generate_mipmaps()
		wall_paint.set_shader_parameter("cracks_tex",ImageTexture.create_from_image(cracks))
		wall_brick=wall_paint.duplicate() as ShaderMaterial
		wall_brick.set_shader_parameter("brick_bias",1.0)
	var plaster_material: Material=EnvironmentKit.materials.get("InstancedTint_plaster")
	var brick_material: Material=EnvironmentKit.materials.get("InstancedTint_brick")
	for child in parent.get_children():
		if child is MultiMeshInstance3D:
			if child.material_override==plaster_material:child.material_override=wall_paint
			elif child.material_override==brick_material:child.material_override=wall_brick

static func terrain_material(mask: Image, half_map: float) -> ShaderMaterial:
	var wear := Image.new()
	wear.load_svg_from_string(PAVING_WEAR)
	wear.generate_mipmaps()
	var result := _material(TERRAIN_SHADER)
	result.set_shader_parameter("half_map", half_map)
	result.set_shader_parameter("street_mask", ImageTexture.create_from_image(mask))
	result.set_shader_parameter("wear_tex", ImageTexture.create_from_image(wear))
	result.set_shader_parameter("ground_tex", EnvironmentKit.material("sand").albedo_texture)
	result.set_shader_parameter("concrete_tex", EnvironmentKit.material("concrete").albedo_texture)
	result.set_shader_parameter("asphalt_tex", EnvironmentKit.material("asphalt").albedo_texture)
	return result

static func tag(kit: EnvironmentKit,position: Vector3,yaw: float,index: int) -> void:
	if not kit.visuals:return
	if tag_meshes.is_empty():
		var template:=PIXACAO.instantiate()
		for variant: MeshInstance3D in template.get_children():
			tag_meshes.append(variant.mesh)
			EnvironmentKit.materials[INK]=variant.material_override
		template.free()
	var size:=.74+float(index%11)*.055
	var basis:=Basis(Vector3.UP,yaw).scaled(Vector3.ONE*size)
	kit._instance(tag_meshes[index%tag_meshes.size()],INK,Transform3D(basis,position),
		false,null,56.0,{"shadows":false,"optional":true,"sector":28.0})
