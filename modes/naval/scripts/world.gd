extends Node3D
class_name NavalWorld

var sun: DirectionalLight3D
var environment: WorldEnvironment
var water: MeshInstance3D
var visuals := true
var clock := 0.0
var effects: Array[Dictionary] = []
var effect_pool: Array[MeshInstance3D] = []
var shot_streams: Dictionary = {}
var sound_players: Dictionary = {}
var wake_clock := 0.0
var mountain_index := 0
var effect_sphere: SphereMesh
var effect_plane: PlaneMesh
var explosion_audio: GameExplosionAudio
var coastal_lights: Array[Light3D] = []
var clouds: MeshInstance3D
var cycle: GameDayNight
var combat_visuals: GameCombatVisuals
var weapon_audio: GameWeaponAudio
var combat_feedback: GameCombatFeedback
var metal_sparks: GameMetalSparks
var moon: DirectionalLight3D

func build(render_visuals := true, map_seed := 0) -> void:
	visuals = render_visuals
	var map_random := RandomNumberGenerator.new()
	map_random.seed = map_seed
	mountain_index = map_random.randi_range(0,NavalCatalog.ISLANDS.size()-1)
	for index in range(NavalCatalog.ISLANDS.size()): _island(index)
	NavalIslands.seabed(self,visuals,mountain_index)
	for side in [-1.0,1.0]:
		_solid_box(Vector3(side*1000,0,0),Vector3(3,15,2000))
		_solid_box(Vector3(0,0,side*1000),Vector3(2000,15,3))
	if not visuals: return
	effect_sphere = SphereMesh.new()
	effect_sphere.radial_segments = 8
	effect_sphere.rings = 4
	effect_plane = PlaneMesh.new()
	effect_plane.size = Vector2.ONE
	metal_sparks=GameMetalSparks.new();add_child(metal_sparks)
	explosion_audio=GameExplosionAudio.new()
	explosion_audio.bus_name="NavalExplosions"
	explosion_audio.category="NavalSFX"
	add_child(explosion_audio)
	environment = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	(sky.sky_material as ProceduralSkyMaterial).sky_top_color = Color("536e89")
	(sky.sky_material as ProceduralSkyMaterial).sky_horizon_color = Color("b8c8cb")
	(sky.sky_material as ProceduralSkyMaterial).ground_horizon_color = Color("b8c8cb")
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8da5b5")
	env.ambient_light_energy = 0.45
	env.fog_enabled = true
	env.fog_light_color = Color("819da9")
	env.fog_density = 0.00018
	env.fog_sky_affect = 0.25
	environment.environment = env
	add_child(environment)
	sun = DirectionalLight3D.new()
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 180.0
	add_child(sun)
	water = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(4400,4400)
	plane.subdivide_width = 180
	plane.subdivide_depth = 180
	water.mesh = plane
	var shader := preload("res://modes/naval/shaders/ocean.gdshader")
	var material := ShaderMaterial.new()
	material.shader = shader
	var island_data := PackedVector4Array()
	for index in range(5):
		var p: Vector3 = NavalCatalog.ISLANDS[index]
		island_data.append(Vector4(p.x,p.z,float(NavalCatalog.RADII[index]),0))
	material.set_shader_parameter("islands",island_data)
	water.material_override = material
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)
	_build_atmosphere()
	cycle=GameDayNight.new();add_child(cycle);cycle.configure(env,sun,clouds,moon)
	weapon_audio=GameWeaponAudio.new();add_child(weapon_audio)
	combat_feedback=GameCombatFeedback.new();add_child(combat_feedback)
	combat_visuals=GameCombatVisuals.new();combat_visuals.initial_pool=0;add_child(combat_visuals)

func _solid_box(pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.position = pos
	add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)

func _island(index: int) -> void:
	NavalIslands.build(self,index,mountain_index,visuals)

func update_time(time: float) -> void:
	clock = time
	if not visuals: return
	var light:=cycle.apply_time(time)
	(water.material_override as ShaderMaterial).set_shader_parameter("ocean_time",time)
	(water.material_override as ShaderMaterial).set_shader_parameter("daylight",maxf(.12,light))
	for lamp in coastal_lights:
		lamp.light_energy = float(lamp.get_meta("base_energy"))*clampf(1.15-light,0.0,1.0)
		if lamp.get_meta("beacon",false): lamp.rotation.y = time*.18
	var camera := get_viewport().get_camera_3d()
	var depth := maxf(0.0,-camera.global_position.y) if camera else 0.0
	environment.environment.fog_density = lerpf(.00018,.045,clampf(depth/45.0,0,1))
	environment.environment.fog_light_color = cycle.fog_color.lerp(Color("16455a"),clampf(depth/5.0,0,1))

func _build_atmosphere() -> void:
	clouds = MeshInstance3D.new()
	clouds.name = "CloudLayer"
	var plane := PlaneMesh.new()
	plane.size = Vector2(4400,4400)
	clouds.mesh = plane
	clouds.position.y = 260
	clouds.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = preload("res://modes/naval/shaders/clouds.gdshader")
	var noise := FastNoiseLite.new()
	noise.seed = 83416
	noise.frequency = .018
	var texture := NoiseTexture2D.new()
	texture.width = 256
	texture.height = 256
	texture.seamless = true
	texture.noise = noise
	material.set_shader_parameter("cloud_noise",texture)
	clouds.material_override = material
	add_child(clouds)
	moon = DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-48,130,0)
	moon.light_color = Color("7797b2")
	moon.light_energy = .12
	moon.shadow_enabled = false
	add_child(moon)
	for child in find_children("*","Light3D",true,false):
		if child.get_meta("night_light",false):
			child.set_meta("base_energy",child.light_energy)
			coastal_lights.append(child)
	var atmosphere := EnvironmentAtmosphere.new()
	atmosphere.kind = "marine"
	add_child(atmosphere)

func effect(pos: Vector3, color: Color, size: float, duration := 0.5, flat := false,smoke:=false) -> void:
	if not visuals or effects.size() >= 128: return
	var node: MeshInstance3D = effect_pool.pop_back() if not effect_pool.is_empty() else MeshInstance3D.new()
	if node.get_parent() == null: add_child(node)
	node.mesh = effect_plane if flat else effect_sphere
	var material := node.material_override as StandardMaterial3D
	if material == null:
		material = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		node.material_override = material
	material.albedo_color = Color(color.r,color.g,color.b,0.0) if smoke else color
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.position = pos
	node.scale = Vector3.ONE*size
	node.visible = true
	effects.append({"node":node,"left":duration,"total":duration,"size":size,"color":color,"smoke":smoke})

func _process(delta: float) -> void:
	for i in range(effects.size()-1,-1,-1):
		var item: Dictionary = effects[i]
		item.left = float(item.left)-delta
		if item.left <= 0.0:
			item.node.hide()
			effect_pool.append(item.node)
			effects.remove_at(i)
		else:
			item.node.scale = Vector3.ONE*float(item.size)*(1.0+(1.0-float(item.left)/float(item.total))*0.6)
			item.node.material_override.albedo_color.a = GameEffectEnvelope.opacity(float(item.total)-float(item.left),float(item.total),.55 if item.get("smoke",false) else .015,1.6 if item.get("smoke",false) else minf(.5,float(item.total)*.7))*item.color.a

func sound(weapon: String, point: Vector3, owner: String,elapsed:=0.0) -> void:
	if visuals and is_instance_valid(weapon_audio): weapon_audio.play(int(owner),weapon,point,elapsed)

func _exit_tree() -> void:
	for player in sound_players.values():
		if is_instance_valid(player): player.stop()

func forget_owner(owner: String) -> void:
	for id in sound_players.keys():
		if str(id).begins_with(owner+":"):
			sound_players[id].stop()
			sound_players[id].queue_free()
			sound_players.erase(id)

func explosion(point: Vector3, event_id: String) -> void:
	while effects.size()>112:
		var old: Dictionary = effects.pop_front()
		old.node.hide()
		effect_pool.append(old.node)
	# One bounded burst per authoritative death; no particles with physics bodies.
	effect(point+Vector3.UP*3,Color("fff1a9"),11.0,0.35)
	effect(point+Vector3.UP*4,Color("ff923b"),17.0,1.25)
	effect(point+Vector3.UP*0.2,Color("f7c76c"),25.0,0.8,true)
	var random := RandomNumberGenerator.new()
	random.seed = event_id.hash()
	for i in range(7):
		var offset := Vector3(random.randf_range(-6,6),random.randf_range(2,12),random.randf_range(-6,6))
		effect(point+offset,Color("f3a34b") if i<3 else Color("3b4249"),random.randf_range(5,9),1.0 if i<3 else 5.0,false,i>=3)
	play_explosion_sound(point,event_id)

func play_explosion_sound(point: Vector3,event_id: String) -> void:
	if not visuals: return
	if not is_instance_valid(explosion_audio):
		explosion_audio=GameExplosionAudio.new()
		explosion_audio.bus_name="NavalExplosions"
		explosion_audio.category="NavalSFX"
		add_child(explosion_audio)
	explosion_audio.play_event(event_id,point,"destroy")

func _explosion_audio() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var bytes := PackedByteArray()
	bytes.resize(22050*2*2)
	var noise := RandomNumberGenerator.new()
	noise.seed = 17391
	var low := 0.0
	for i in range(44100):
		var t := i/22050.0
		low = low*0.87+noise.randf_range(-1,1)*0.13
		var value := (low*0.75+sin(TAU*(48.0*t-5.0*t*t))*0.16)*exp(-t*3.3)*minf(1.0,t*300.0)
		bytes.encode_s16(i*2,int(clampf(value,-0.85,0.85)*32767))
	stream.data = bytes
	return stream
