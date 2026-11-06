extends Node
class_name WarFavelaBaile
## Local ambient baile playlist. Songs are shuffled without replacement;
## each event starts at a random track offset after a random delay.
const TRACK_PATHS := [
	"res://modes/war/audio/baile/ak_do_flamengo.mp3",
	"res://modes/war/audio/baile/invejoso.mp3",
	"res://modes/war/audio/baile/predestinado.mp3",
	"res://modes/war/audio/baile/pitbull_do_marcinho.mp3",
	"res://modes/war/audio/baile/g3_chegou_clareando.mp3",
	"res://modes/war/audio/baile/eu_vi_o_mano.mp3",
]
var voice: AudioStreamPlayer3D
var queue: Array[int] = []
var previous := -1
var rng := RandomNumberGenerator.new()
var lights: Array[OmniLight3D] = []
var light_clock := 0.0

static func start(stage: Node3D, visuals: bool = true) -> void:
	var controller := WarFavelaBaile.new()
	stage.add_child(controller)
	controller._build_stage(stage, visuals)
	if visuals: controller.begin()

func _build_stage(stage: Node3D, visuals: bool) -> void:
	var deck_body := StaticBody3D.new()
	deck_body.name = "ColisaoPalco"
	deck_body.collision_layer = 1
	deck_body.collision_mask = 0
	deck_body.position = Vector3(-48, 1.0, 0)
	var deck_shape := CollisionShape3D.new()
	var deck_box := BoxShape3D.new()
	deck_box.size = Vector3(18, 2.0, 12)
	deck_shape.shape = deck_box
	deck_body.add_child(deck_shape)
	stage.add_child(deck_body)
	if not visuals:
		set_process(false)
		return
	var deck := _box(stage, "Palco", Vector3(-48, 1.1, 0), Vector3(18, 2.0, 12), Color("332b25"))
	var fascia := _box(stage, "FrentePalco", Vector3(-48, 2.25, 6.0), Vector3(18, .35, .25), Color("bf293c"), true)
	_box(stage, "Pista", Vector3(-28, .18, 0), Vector3(22, .24, 17), Color("544a3d"))
	_box(stage, "TorreLuzOeste", Vector3(-60, 6, -9), Vector3(.55, 12, .55), Color("26252a"))
	_box(stage, "TorreLuzLeste", Vector3(-36, 6, -9), Vector3(.55, 12, .55), Color("26252a"))
	_box(stage, "TraveLuz", Vector3(-48, 12, -9), Vector3(24, .5, .5), Color("26252a"))
	for i in 8:
		var lamp := OmniLight3D.new()
		lamp.name = "LuzBaile_%02d" % i
		lamp.position = Vector3(-59 + float(i % 4) * 7.3, 10.8, 6.5 if i < 4 else -9)
		lamp.light_color = [Color("ff315b"), Color("27c7ff"), Color("ffd33f"), Color("a64dff")][i % 4]
		lamp.light_energy = 2.3
		lamp.omni_range = 23.0
		lamp.shadow_enabled = false
		stage.add_child(lamp)
		lights.append(lamp)
	for side: float in [-1.0, 1.0]:
		for i in 8:
			var post := _box(stage, "TraveCampo", Vector3(0, .65, side * 24), Vector3(.18, 1.3, .18), Color("eee5d0"))
			post.position.x = -37 + i * 10.5
	for x in [-41.0, -15.0]:
		var horn := _box(stage, "CaixaSom", Vector3(x, 5.0, 4.8), Vector3(2.2, 4.0, 1.5), Color("171719"))
		_box(stage, "AltoFalante", horn.position + Vector3(0, .15, .78), Vector3(1.3, 2.9, .08), Color("34343a"))
	for side: float in [-1.0, 1.0]:
		var gx: float = 35.0 * side
		_box(stage, "GolTrave", Vector3(gx, 1.2, 0), Vector3(.18, 2.4, 7.2), Color("e4dfcf"))
		_box(stage, "GolPoste", Vector3(gx, 2.4, -3.5), Vector3(.18, .18, .18), Color("e4dfcf"))
		_box(stage, "GolPoste", Vector3(gx, 2.4, 3.5), Vector3(.18, .18, .18), Color("e4dfcf"))
	# Painted touchlines and halfway markings give the pitch a readable scale.
	for z in [-24.0, 24.0]:
		_box(stage, "LinhaCampo", Vector3(0, .27, z), Vector3(76, .025, .12), Color("ddd9bf"))
	for x in [-38.0, 0.0, 38.0]:
		_box(stage, "LinhaCampo", Vector3(x, .27, 0), Vector3(.12, .025, 48), Color("ddd9bf"))
	# Small clusters of cups and paper around the dance floor.
	var litter_rng := RandomNumberGenerator.new()
	litter_rng.seed = 241106
	for i in 34:
		var at := Vector3(litter_rng.randf_range(-38, 38), .34, litter_rng.randf_range(-23, 23))
		var scrap := _box(stage, "LixoBaile", at, Vector3(.18, .035, .14), Color("bda878") if i % 2 == 0 else Color("d8d0ba"))
		scrap.rotation.y = litter_rng.randf_range(0, TAU)
	stage.set_meta("baile_stage_meshes", [deck, fascia])
	# Narrow paths around the pitch connect it to the settlement.
	for p in [Vector3(-12, .14, 30), Vector3(12, .14, 20), Vector3(33, .14, 8)]:
		_box(stage, "TrilhaTerrosa", p, Vector3(5.0, .24, 18.0), Color("71604a"))

func _process(delta: float) -> void:
	light_clock += delta
	if light_clock < .32: return
	light_clock = 0.0
	var colors := [Color("ff315b"), Color("27c7ff"), Color("ffd33f"), Color("a64dff"), Color("47e281")]
	for i in lights.size():
		lights[i].light_color = colors[posmod(i + floori(Time.get_ticks_msec() / 640.0), colors.size())]

func _box(parent: Node3D, label: String, at: Vector3, size: Vector3, color: Color, emissive := false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = .88
	if emissive:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.8
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance

func begin() -> void:
	rng.randomize()
	voice = AudioStreamPlayer3D.new()
	voice.name = "SomDoBaile"
	voice.bus = "Ambiente"
	voice.position = Vector3(0, 4.0, 2.0)
	voice.max_distance = 100.0
	voice.unit_size = 12.0
	voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	voice.volume_db = -5.0
	voice.finished.connect(_next_song)
	add_child(voice)
	await get_tree().create_timer(rng.randf_range(8.0, 38.0)).timeout
	_next_song()

func _next_song() -> void:
	if not is_instance_valid(voice): return
	if queue.is_empty():
		queue.assign(range(TRACK_PATHS.size()))
		queue.shuffle()
		if queue.size() > 1 and queue.back() == previous:
			var swap: int = rng.randi_range(0, queue.size() - 2)
			var last: int = int(queue.back())
			queue[queue.size() - 1] = queue[swap]
			queue[swap] = last
	var index: int = queue.pop_back()
	previous = index
	var stream := load(TRACK_PATHS[index]) as AudioStream
	if stream == null:
		push_error("Faixa do baile não foi importada: " + TRACK_PATHS[index])
		return
	voice.stream = stream
	voice.play(rng.randf_range(0.0, maxf(0.0, stream.get_length() - 2.0)))
