extends GameDayNight
class_name BRAfghanAtmosphere

# Reuses the existing one sun, one unshadowed moon and cloud layer. No
# volumetric fog, screen pass, extra lights or changes to collision/navigation.
const AFTERNOON_HOUR:=15.5
var distant_material: ShaderMaterial

static func install(parent: Node3D) -> BRAfghanAtmosphere:
	var world:=WorldEnvironment.new();world.name="AfghanEnvironment"
	var env:=Environment.new();env.background_mode=Environment.BG_SKY
	var sky:=Sky.new();sky.sky_material=ProceduralSkyMaterial.new();env.sky=sky
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode=Environment.TONE_MAPPER_FILMIC;env.tonemap_exposure=.98
	env.fog_enabled=true;env.fog_mode=Environment.FOG_MODE_DEPTH
	env.fog_depth_begin=160.;env.fog_depth_end=1700.;env.fog_depth_curve=1.4
	env.fog_density=.55;env.fog_height=36.;env.fog_height_density=.003
	env.adjustment_enabled=true;env.adjustment_contrast=1.08;env.adjustment_saturation=1.12
	env.fog_sky_affect=.14;env.fog_sun_scatter=.12
	world.environment=env;parent.add_child(world)
	var light:=DirectionalLight3D.new();light.name="AfghanSun"
	light.shadow_enabled=true;light.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	light.directional_shadow_max_distance=100.;light.directional_shadow_split_1=.28
	# Values below the engine defaults caused dense self-shadow bands on soil.
	# Retain the directional shadows; fix their depth/normal offset instead.
	light.shadow_bias=.1;light.shadow_normal_bias=2.
	parent.add_child(light)
	var cycle:=BRAfghanAtmosphere.new();parent.add_child(cycle)
	cycle.configure(env,light)
	(cycle.clouds.material_override as ShaderMaterial).shader=preload("res://modes/battle_royale/map/afghan_clouds.gdshader")
	return cycle

func apply_time(seconds: float,force:=false) -> float:
	if not force and absf(seconds-last_time)<.1: return daylight
	last_time=seconds
	# Preserve the shared 14-minute full cycle, only start this map late in
# the afternoon. Match time remains replicated by the original game code.
	var hour:=fposmod(seconds/PERIOD*24.+AFTERNOON_HOUR,24.)
	var angle:=TAU*(hour/24.-.25)
	var altitude:=sin(angle)
	daylight=smoothstep(-.16,.23,altitude)
	if environment==null or not is_instance_valid(sun): return daylight
	var dusk:=1.-smoothstep(.12,.65,maxf(0.,altitude))
	sun.rotation=Vector3(-angle,-.92,0)
	sun.visible=altitude>-.16;sun.light_energy=.92*daylight
	sun.light_color=Color("fff0d2").lerp(Color("edbc89"),dusk)
	moon.rotation=Vector3(-angle+PI,-.92,0);moon.light_energy=.26*(1.-daylight)
	moon.light_color=Color("a0b8d2");moon.shadow_enabled=false
	environment.ambient_light_energy=lerpf(.40,.29,daylight)
	environment.ambient_light_color=Color("8ca3bd").lerp(Color("c7bb9d"),daylight)
	var sky:=environment.sky.sky_material as ProceduralSkyMaterial
	sky.sky_top_color=Color("101c32").lerp(Color("386f9a"),daylight)
	sky.sky_horizon_color=Color("384452").lerp(Color("cbbd9f"),daylight)
	sky.sky_curve=.72;sky.ground_curve=.3;sky.sky_energy_multiplier=.80
	sky.ground_bottom_color=Color("151c23").lerp(Color("6d655d"),daylight)
	sky.ground_horizon_color=sky.sky_horizon_color
	fog_color=Color("35485c").lerp(Color("b9aa8e"),daylight)
	environment.fog_light_color=fog_color;environment.fog_light_energy=.83
	if is_instance_valid(clouds):
		(clouds.material_override as ShaderMaterial).set_shader_parameter("daylight",daylight)
		(clouds.material_override as ShaderMaterial).set_shader_parameter("ocean_time",seconds)
	if distant_material: distant_material.set_shader_parameter("daylight",daylight)
	return daylight
