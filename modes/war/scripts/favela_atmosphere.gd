extends RefCounted
class_name WarFavelaAtmosphere

## Static-cloud sky and distant hillside condensation for GL Compatibility.
## No TIME/POSITION in the sky shader: its radiance cubemap remains cacheable.
const MIST_SCENE := preload("res://modes/war/library/favela_nevoa_encosta.tscn")
const SKY_SHADER := """
shader_type sky;
uniform vec3 sky_zenith : source_color = vec3(0.25, 0.48, 0.76);
uniform vec3 sky_horizon : source_color = vec3(0.69, 0.77, 0.82);
uniform vec3 cloud_light : source_color = vec3(0.96, 0.96, 0.93);
uniform vec3 cloud_shadow : source_color = vec3(0.73, 0.79, 0.83);
float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x);
	float b = mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x);
	return mix(a, b, f.y);
}
float cloud_noise(vec2 uv) {
	float n = noise2(uv * 1.2) * .55;
	n += noise2(uv * 2.35 + vec2(8.4, 3.7)) * .29;
	n += noise2(uv * 4.9 + vec2(-5.6, 11.8)) * .16;
	return n;
}
void sky() {
	vec3 dir = normalize(EYEDIR);
	float elevation = max(dir.y, 0.0);
	float sky_mix = smoothstep(-0.055, 0.85, dir.y);
	vec3 color = mix(sky_horizon, sky_zenith, sky_mix);
	vec2 cloud_uv = dir.xz / max(dir.y + .22, .27);
	float broad = cloud_noise(cloud_uv * 1.70 + vec2(3.2, -4.0));
	float detail = noise2(cloud_uv * 5.4 + vec2(11.0, -7.0));
	float coverage = smoothstep(.475, .69, broad + .075 * detail);
	coverage *= smoothstep(.015, .13, elevation);
	vec3 cloud = mix(cloud_shadow, cloud_light,
		smoothstep(.40, .80, broad + .17 * detail));
	color = mix(color, cloud, coverage * .78);
	float haze = exp(-elevation * 16.0) * .18;
	color = mix(color, sky_horizon, haze);
	COLOR = color;
}
"""

static func _mist_slices(root: Node3D, terrain_height: Callable) -> int:
	var container := Node3D.new()
	container.name = "BrumaNasEncostas"
	root.add_child(container)
	var created := 0
	# Moisture belongs to distant wooded valleys and hill crests, not lanes.
	for i in 14:
		var x := -680.0 + i * 101.0 + 18.0 * sin(float(i) * 2.11)
		var z := -641.0 + 26.0 * cos(float(i) * 1.83)
		var height: float = terrain_height.call(x, z)
		var veil := MIST_SCENE.instantiate() as Node3D
		veil.name = "NevoaMorro_%02d" % i
		veil.position = Vector3(x, height + 18.0 + 6.0 * sin(float(i) * 1.13), z)
		veil.rotation.y = .05 * sin(float(i) * 1.79)
		veil.scale = Vector3(1.0 + .28 * sin(float(i) * 1.31), .85 + .22 * cos(float(i) * 2.05), 1.0)
		container.add_child(veil)
		created += 1
	return created

static func build(root: Node3D, terrain_height: Callable) -> Dictionary:
	var world := WorldEnvironment.new()
	world.name = "AtmosferaFavela"
	var environment := Environment.new()
	var clouds := Shader.new()
	clouds.code = SKY_SHADER
	var sky_material := ShaderMaterial.new()
	sky_material.shader = clouds
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c9d2cf")
	environment.ambient_light_energy = .47
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("bec3bc")
	environment.fog_density = .00037
	environment.fog_sky_affect = .08
	world.environment = environment
	root.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.name = "SolAtmosferaFavela"
	sun.rotation_degrees = Vector3(-43.0, -28.0, 0.0)
	sun.light_color = Color("f2e5d1")
	sun.light_energy = .82
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 135.0
	root.add_child(sun)
	var veils := _mist_slices(root, terrain_height)
	root.set_meta("favela_mist_veils", veils)
	root.set_meta("favela_cloud_sky", true)
	return {"mist_veils": veils, "cloud_sky": true, "fog_density": environment.fog_density}
