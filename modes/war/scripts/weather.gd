extends Node3D
class_name WarWeather
# Shared match clock: one occasional 75s shower per 14-minute cycle,
# 9% of the cycle including smooth transitions. No client-side random roll.
static var seed:=0
const CYCLE:=840.0
const START:=563.0
const LENGTH:=75.0
var game: Node
var ocean: MeshInstance3D
var rain: GPUParticles3D
var clock:=0.0
var roof_clock:=0.0
var roofed:=false
static func intensity(seconds: float) -> float:
	var cycle:=floori(seconds/CYCLE)
	if posmod(cycle*7919+seed*137,100)>=25: return 0.
	# Some seeded showers occur in daylight; others remain nocturnal.
	# Every client and water simulation uses the same match seed/clock.
	var starts:=180.0 if posmod(seed+cycle,2)==0 else START
	var at:=fposmod(seconds,CYCLE)-starts
	if at<0 or at>LENGTH: return 0.
	return smoothstep(0,16,at)*(1-smoothstep(LENGTH-18,LENGTH,at))
func _ready() -> void:
	if DisplayServer.get_name()=="headless": return
	ocean=MeshInstance3D.new();ocean.name="WarSea"
	var mesh:=PlaneMesh.new();mesh.size=Vector2(12000,12000);mesh.subdivide_width=255;mesh.subdivide_depth=255
	ocean.mesh=mesh;ocean.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat:=ShaderMaterial.new();mat.shader=preload("res://modes/war/shaders/sea.gdshader");ocean.material_override=mat;add_child(ocean)
	rain=GPUParticles3D.new();rain.name="LocalRain";rain.amount=650;rain.lifetime=1.1;rain.preprocess=.1;rain.visibility_aabb=AABB(Vector3(-30,-35,-30),Vector3(60,70,60))
	var particle:=ParticleProcessMaterial.new();particle.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_BOX;particle.emission_box_extents=Vector3(24,1,24);particle.direction=Vector3(.1,-1,.03);particle.spread=3;particle.initial_velocity_min=23;particle.initial_velocity_max=30;particle.gravity=Vector3(0,-4,0)
	rain.process_material=particle
	var drop:=QuadMesh.new();drop.size=Vector2(.018,.65)
	var drop_mat:=StandardMaterial3D.new();drop_mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;drop_mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;drop_mat.albedo_color=Color(.65,.73,.78,.38);drop_mat.billboard_mode=BaseMaterial3D.BILLBOARD_FIXED_Y;drop.material=drop_mat
	rain.draw_pass_1=drop;rain.emitting=false;add_child(rain)
func _process(_delta: float) -> void:
	roof_clock+=_delta
	# Editor/gallery previews do not always live under WarGame.
	if not is_instance_valid(game) or not game is WarGame:return
	seed=int(game.weather_seed);clock=float(game.war_clock)
	var strength:=intensity(clock)
	if ocean:
		var mat:=ocean.material_override as ShaderMaterial;mat.set_shader_parameter("ocean_time",clock);mat.set_shader_parameter("storm",strength)
		var cycle:=get_parent().get_node_or_null("WarDayNight") as WarDayNight
		if cycle: mat.set_shader_parameter("daylight",cycle.daylight)
	if rain:
		var camera:=get_viewport().get_camera_3d()
		if camera: rain.global_position=camera.global_position+Vector3.UP*18
		if camera and roof_clock>.3:
			roof_clock=0
			var ray:=PhysicsRayQueryParameters3D.create(camera.global_position,camera.global_position+Vector3.UP*22,1)
			roofed=not get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
		rain.amount_ratio=strength;rain.emitting=strength>.025 and not roofed
