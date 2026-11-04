extends Node3D
class_name GameDayNight

const PERIOD:=840.0
const START_HOUR:=10.0
var environment: Environment
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var clouds: MeshInstance3D
var indoor:=false
var last_time:=-100.0
var daylight:=1.0
var fog_color:=Color("819da9")
static var cloud_texture: NoiseTexture2D

static func sample(seconds: float) -> Dictionary:
	var phase:=fposmod(seconds/PERIOD+START_HOUR/24.0,1.0)
	var altitude:=sin(TAU*(phase-.25))
	return {"hour":phase*24,"angle":-TAU*(phase-.25),"daylight":smoothstep(-.16,.23,altitude),"altitude":altitude}

func configure(env: Environment,light: DirectionalLight3D,layer: MeshInstance3D=null,night: DirectionalLight3D=null,interior:=false) -> void:
	environment=env;sun=light;clouds=layer;moon=night;indoor=interior
	if not is_instance_valid(moon):
		moon=DirectionalLight3D.new();moon.shadow_enabled=false;moon.light_color=Color("6c8eb5");add_child(moon)
	if not is_instance_valid(clouds):
		clouds=MeshInstance3D.new();clouds.name="CloudLayer"
		var plane:=PlaneMesh.new();plane.size=Vector2(4400,4400);clouds.mesh=plane;clouds.position.y=260
		clouds.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material:=ShaderMaterial.new();material.shader=preload("res://modes/naval/shaders/clouds.gdshader")
		if cloud_texture==null:
			var noise:=FastNoiseLite.new();noise.seed=83416;noise.frequency=.018
			cloud_texture=NoiseTexture2D.new();cloud_texture.width=256;cloud_texture.height=256;cloud_texture.seamless=true;cloud_texture.noise=noise
		material.set_shader_parameter("cloud_noise",cloud_texture);clouds.material_override=material;add_child(clouds)
	apply_time(0,true)

func apply_time(seconds: float,force:=false) -> float:
	if not force and absf(seconds-last_time)<.1: return daylight
	last_time=seconds
	var state:=sample(seconds);daylight=float(state.daylight)
	if environment==null or not is_instance_valid(sun): return daylight
	sun.rotation=Vector3(state.angle,-.5,0);sun.light_energy=(.58 if indoor else .85)*daylight
	sun.visible=float(state.altitude)>-.16
	moon.rotation=Vector3(float(state.angle)+PI,-.5,0);moon.light_energy=.075*(1-daylight)
	var sunset:=1-absf(float(state.altitude))*3
	sun.light_color=Color("f3e7ca").lerp(Color("df996b"),clampf(sunset,0,1))
	environment.ambient_light_energy=lerpf(.20 if indoor else .12,.32,daylight)
	environment.ambient_light_color=Color("718aa9").lerp(Color("c8bea5") if not indoor else Color("b9b6ad"),daylight)
	var sky:=environment.sky.sky_material as ProceduralSkyMaterial
	sky.sky_top_color=Color("061020").lerp(Color("668a9b"),daylight)
	sky.sky_horizon_color=Color("152238").lerp(Color("c6bcaa"),daylight)
	sky.ground_horizon_color=sky.sky_horizon_color
	sky.ground_bottom_color=Color("101824").lerp(Color("545b58"),daylight)
	fog_color=Color("132338").lerp(Color("c6b698"),daylight)
	environment.fog_light_color=fog_color
	var material:=clouds.material_override as ShaderMaterial
	material.set_shader_parameter("ocean_time",seconds);material.set_shader_parameter("daylight",daylight)
	return daylight
