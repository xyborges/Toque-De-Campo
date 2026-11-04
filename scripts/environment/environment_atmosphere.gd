extends Node3D
class_name EnvironmentAtmosphere
var kind := "desert"
var dust: CPUParticles3D
var update_clock := 0.0
func _ready() -> void:
	if DisplayServer.get_name()=="headless": return
	GameAudioSettings.ensure()
	var ambient := AudioStreamPlayer.new()
	ambient.bus = "Ambiente"
	var audio := AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = 11025
	audio.loop_mode = AudioStreamWAV.LOOP_FORWARD
	audio.loop_end = 22050
	var bytes := PackedByteArray()
	bytes.resize(44100)
	var random := RandomNumberGenerator.new()
	random.seed = 21843
	var low := 0.0
	for i in range(22050):
		low = low*.96+random.randf_range(-1,1)*.04
		var fade := sin(PI*float(i)/22050.0)
		bytes.encode_s16(i*2,int(low*fade*18000))
	audio.data = bytes
	ambient.stream = audio
	ambient.volume_db = -24.0
	add_child(ambient)
	ambient.play()
	if kind!="desert": return
	dust = CPUParticles3D.new()
	dust.amount = 36
	dust.lifetime = 12
	dust.preprocess = 5
	dust.local_coords = false
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(20,3,20)
	dust.direction = Vector3(1,.05,.25)
	dust.spread = 15
	dust.initial_velocity_min = 1.1
	dust.initial_velocity_max = 1.8
	dust.gravity = Vector3.ZERO
	dust.scale_amount_min = .08
	dust.scale_amount_max = .22
	var mesh := QuadMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(.76,.65,.44,.15)
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mesh.material = material
	dust.mesh = mesh
	add_child(dust)

func _process(delta: float) -> void:
	if dust==null: return
	update_clock += delta
	if update_clock<.5: return
	update_clock = 0
	var camera := get_viewport().get_camera_3d()
	if camera: dust.global_position = camera.global_position+Vector3(-12,1,0)
