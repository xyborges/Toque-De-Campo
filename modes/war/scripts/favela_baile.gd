extends Node3D
class_name WarFavelaBaile
## Quadra comunitaria com palco e paredao. Visual e fisica compartilham a origem.
## As seis faixas usam a semente e o relogio autoritativos da partida.
const TRACK_PATHS := [
	"res://modes/war/audio/baile/ak_do_flamengo.mp3",
	"res://modes/war/audio/baile/invejoso.mp3",
	"res://modes/war/audio/baile/predestinado.mp3",
	"res://modes/war/audio/baile/pitbull_do_marcinho.mp3",
	"res://modes/war/audio/baile/g3_chegou_clareando.mp3",
	"res://modes/war/audio/baile/eu_vi_o_mano.mp3",
]
const PINK := Color("ef396d")
const CYAN := Color("35c8ef")
const GOLD := Color("f1b94f")
const LIME := Color("7dc8a0")
const STEEL := Color("343a3d")
const CONCRETE := Color("747e77")
var voice: AudioStreamPlayer3D
var track_streams: Array[AudioStream] = []
var track_durations: Array[float] = []
var playlist_tick := 0.0
var local_start_usec := 0
var last_track := -1
var last_seed := -1
var last_position := -1.0
const HEARING_RADIUS := 100.0
const CHECK_INTERVAL := 0.20
var lights: Array[OmniLight3D] = []
var beams: Array[MeshInstance3D] = []
var light_clock := 0.0
var visuals_enabled := true
var materials: Dictionary = {}

static func start(stage: Node3D, visuals: bool = true) -> void:
	var controller := WarFavelaBaile.new()
	controller.name = "ControleBaile"
	stage.add_child(controller)
	controller._build_stage(stage, visuals)
	if visuals:
		controller.begin()

func _build_stage(stage: Node3D, visuals: bool) -> void:
	visuals_enabled = visuals
	# Plataforma com contato exatamente coincidente com a geometria visual.
	_box(stage, "Palco", Vector3(-48, 1.14, 0), Vector3(18, 1.8, 12), Color("3c3a38"), true)
	_box(stage, "PisoPalco", Vector3(-48, 2.065, 0), Vector3(18.35, .06, 12.35), Color("676864"), true)
	_box(stage, "FrentePalco", Vector3(-38.83, 1.12, 0), Vector3(.18, 1.65, 12.3), Color("9f3949"))
	for z: float in [-5.25, -3.15, -1.05, 1.05, 3.15, 5.25]:
		_box(stage, "SaiaPalco", Vector3(-38.70, 1.15, z), Vector3(.07, 1.45, .12), STEEL)
	# Tres degraus realmente apoiados e percorriveis pela frente do palco.
	for i in 3:
		var step := float(i)
		_box(stage, "EscadaPalco", Vector3(-35.95 - step * .83, .54 + step * .5, 0),
			Vector3(.83, .60 + step * .40, 2.25), Color("777a77"), true)
	# Cobertura: quatro colunas, trelicas, lona, paineis e cabos aparentes.
	for x: float in [-55.7, -40.3]:
		for z: float in [-6.1, 6.1]:
			_box(stage, "PilarTrelica", Vector3(x, 5.36, z),
				Vector3(.27, 10.25, .27), STEEL, true)
			_box(stage, "BaseTrelica", Vector3(x, .49, z),
				Vector3(.62, .50, .62), Color("454b49"), true)
			# Sapatas acompanham o desnivel natural sob a borda externa.
			_box(stage, "FundacaoTrelica", Vector3(x, -2.25, z),
				Vector3(.62, 5.0, .62), STEEL, true)
	for z: float in [-6.1, 6.1]:
		_box(stage, "TrelicaLongitudinal", Vector3(-48, 10.36, z),
			Vector3(16.3, .24, .24), STEEL)
		_box(stage, "FaixaLuminosa", Vector3(-48, 10.18, z),
			Vector3(15.7, .09, .08), CYAN if z < 0 else PINK, false, true)
	for x: float in [-55.7, -40.3]:
		_box(stage, "TrelicaLateral", Vector3(x, 10.36, 0),
			Vector3(.24, .24, 12.5), STEEL)
		for z: float in [-4.0, 0.0, 4.0]:
			_box(stage, "DiagonalTrelica", Vector3(x, 9.30, z),
				Vector3(.18, 1.9, .16), Color("5f6968"))
	_box(stage, "CoberturaLona", Vector3(-48, 10.7, 0),
		Vector3(17.0, .24, 13.2), Color("252f34"))
	_box(stage, "Testeira", Vector3(-39.9, 10.45, 0),
		Vector3(.16, .64, 13.1), PINK, false, true)
	_box(stage, "PainelLED", Vector3(-55.35, 5.50, 0),
		Vector3(.16, 5.3, 10.4), Color("1c2834"))
	if visuals_enabled:
		for line in 4:
			for col in 13:
				var color: Color = [PINK, CYAN, GOLD, Color("7564cb")][(col + line * 2) % 4]
				_box(stage, "LEDModulo", Vector3(-55.24, 3.58 + line * 1.21,
					-4.68 + col * .78), Vector3(.07, .95, .57), color, false, true)
		var title := Label3D.new()
		title.name = "LetreiroBaile"
		title.text = "BAILE DA QUADRA"
		title.font_size = 110
		title.pixel_size = .0065
		title.modulate = Color("f8e5c7")
		title.outline_size = 16
		title.position = Vector3(-39.53, 9.60, 0)
		title.rotation.y = PI * .5
		stage.add_child(title)
		# Estruturas luminosas e luminarias perceptiveis mesmo a distancia.
		for side: float in [-1.0, 1.0]:
			for j in 3:
				_box(stage, "Projetor", Vector3(-40.1, 9.56, side * (1.8 + j * 1.6)),
					Vector3(.52, .36, .48), Color("293338"))
		for i in 6:
			var lamp := OmniLight3D.new()
			lamp.name = "LuzBaile_%02d" % i
			lamp.position = Vector3(-40.6 + float(i / 3) * 9.0, 8.7,
				-4.5 + float(i % 3) * 4.5)
			lamp.light_color = [PINK, CYAN, GOLD][i % 3]
			lamp.light_energy = 1.8
			lamp.omni_range = 26.0
			lamp.shadow_enabled = false
			stage.add_child(lamp)
			lights.append(lamp)
		for i in 4:
			var origin := Vector3(-40.45, 9.2, -4.2 + float(i) * 2.8)
			var target := Vector3(-22.0, .35, -8.0 + float(i) * 5.3)
			var beam_color: Color = [PINK, CYAN, GOLD, LIME][i]
			beams.append(_light_beam(stage, origin, target, beam_color))
	# Mesa de DJ, cases e monitores fazem o palco parecer montado e utilizavel.
	_box(stage, "BalcaoDJ", Vector3(-49.25, 2.85, 0),
		Vector3(1.55, 1.51, 4.55), Color("22292d"), true)
	_box(stage, "TampoDJ", Vector3(-48.72, 3.66, 0),
		Vector3(1.12, .14, 4.80), Color("777c7b"), true)
	_box(stage, "ControladoraDJ", Vector3(-48.48, 3.77, 0),
		Vector3(.66, .08, 1.45), Color("151e22"))
	for z: float in [-1.62, 1.62]:
		_disc(stage, Vector3(-48.4, 3.76, z), .43)
		_box(stage, "CaseEquipamento", Vector3(-53.45, 2.55, z * 2.35),
			Vector3(1.15, .91, 1.22), Color("4b5759"), true)
		_box(stage, "RetornoMonitor", Vector3(-40.55, 2.32, z * 2.10),
			Vector3(1.28, .45, 1.35), Color("283034"), true)
	for i in 11:
		var z := -1.9 + float(i) * .38
		_box(stage, "LEDControladora", Vector3(-48.36, 3.82, z),
			Vector3(.10, .025, .06), PINK if i % 3 == 0 else CYAN, false, true)
	# O paredao fica sobre o solo, nao suspenso no ar.
	for side: float in [-1.0, 1.0]:
		var z := side * 8.1
		_box(stage, "CaixaSom", Vector3(-39.1, 2.19, z),
			Vector3(2.0, 3.9, 2.4), Color("171c1f"), true)
		_box(stage, "BaseCaixaSom", Vector3(-39.1, .36, z),
			Vector3(2.25, .24, 2.65), STEEL, true)
		if visuals_enabled:
			for y: float in [1.25, 2.60]:
				_speaker_cone(stage, Vector3(-38.06, y, z), .69)
			_box(stage, "GradeCaixaSom", Vector3(-38.03, 2.15, z),
				Vector3(.045, 3.45, 2.18), Color("283236"))
	# Guarda-corpo frente ao palco, com acesso livre pela escada.
	for z: float in [-9.1, -6.9, 6.9, 9.1]:
		_box(stage, "ProtecaoPalco", Vector3(-33.5, .72, z),
			Vector3(.26, .96, 2.0), Color("636c70"), true)
	# Pisos gastos, demarcacoes de futebol e ponto central, sem objetos suspensos.
	_box(stage, "PinturaCentral", Vector3(0, .246, 0),
		Vector3(74.5, .012, 43.5), Color("5b7971"))
	for z: float in [-21.9, 21.9]:
		_box(stage, "LinhaLateral", Vector3(0, .259, z),
			Vector3(74.0, .014, .13), Color("e1d8bb"))
	for x: float in [-37.0, 0.0, 37.0]:
		_box(stage, "LinhaFundoMeio", Vector3(x, .259, 0),
			Vector3(.13, .014, 43.8), Color("e1d8bb"))
	for i in 40:
		var angle := float(i) * TAU / 40.0
		var mark := _box(stage, "CirculoCentral", Vector3(cos(angle) * 6, .259, sin(angle) * 6),
			Vector3(.85, .014, .12), Color("e1d8bb"))
		if mark != null:
			mark.rotation.y = -angle
	for side: float in [-1.0, 1.0]:
		var x := side * 37.0
		for z: float in [-9.0, 9.0]:
			_box(stage, "AreaGol", Vector3(x - side * 6.0, .259, z),
				Vector3(12, .014, .12), Color("e1d8bb"))
		_box(stage, "AreaGol", Vector3(x - side * 12.0, .259, 0),
			Vector3(.12, .014, 18.0), Color("e1d8bb"))
		# Dois postes e travessao horizontal reais, alem da armação do fundo.
		for z: float in [-3.35, 3.35]:
			_box(stage, "PosteGol", Vector3(x, 1.48, z),
				Vector3(.17, 2.48, .17), Color("e5e9e4"), true)
			_box(stage, "RedeSuporte", Vector3(x + side * 1.3, 1.36, z),
				Vector3(.12, 2.23, .12), Color("bac6bd"), true)
		_box(stage, "TraveGol", Vector3(x, 2.72, 0),
			Vector3(.18, .16, 6.88), Color("e5e9e4"), true)
		_box(stage, "TraveRedeFundo", Vector3(x + side * 1.3, 2.48, 0),
			Vector3(.13, .13, 6.88), Color("bac6bd"))
		if visuals_enabled:
			for z in range(-3, 4):
				_box(stage, "FioRedeGol", Vector3(x + side * 1.1, 1.46, float(z)),
					Vector3(.025, 2.25, .025), Color("b2c0b8"))
			for j in 5:
				_box(stage, "FioRedeHorizontal", Vector3(x + side * 1.1, .42 + j * .49, 0),
					Vector3(.025, .025, 6.7), Color("b2c0b8"))
	# Alambrado robusto; contato e feito por paineis, nao por centenas de fios.
	for z: float in [-24.6, 24.6]:
		_collider(stage, "ContatoAlambrado", Vector3(0, 1.78, z),
			Vector3(81.0, 3.1, .17))
		for x in range(-40, 41, 8):
			_box(stage, "PosteAlambrado", Vector3(float(x), 2.16, z),
				Vector3(.18, 3.85, .18), Color("606b67"), true)
		for y: float in [.55, 1.35, 2.40, 3.83]:
			_box(stage, "MalhaAlambrado", Vector3(0, y, z),
				Vector3(81, .045, .045), Color("6c8781"))
		if visuals_enabled:
			for x in range(-38, 41, 3):
				_box(stage, "MalhaAlambrado", Vector3(float(x), 2.15, z),
					Vector3(.025, 3.25, .025), Color("6c8781"))
	for x: float in [-40.5, 40.5]:
		for z: float in [-17.0, 17.0]:
			_collider(stage, "ContatoAlambrado", Vector3(x, 1.78, z),
				Vector3(.17, 3.1, 15.0))
			for dz: float in [-7.4, 0.0, 7.4]:
				_box(stage, "PosteAlambrado", Vector3(x, 2.16, z + dz),
					Vector3(.18, 3.85, .18), Color("606b67"), true)
			for y: float in [.55, 1.35, 2.40, 3.83]:
				_box(stage, "MalhaAlambrado", Vector3(x, y, z),
					Vector3(.045, .045, 15.0), Color("6c8781"))
	# Iluminacao esportiva ancorada no piso da quadra.
	for x: float in [-32.5, 32.5]:
		for z: float in [-22.8, 22.8]:
			_box(stage, "TorreRefletor", Vector3(x, 3.82, z),
				Vector3(.3, 7.15, .3), Color("59666a"), true)
			_box(stage, "BaseRefletor", Vector3(x, .49, z),
				Vector3(.78, .5, .78), Color("92928a"), true)
			_box(stage, "LuminariaRefletor", Vector3(x, 7.31, z),
				Vector3(1.35, .48, .54), Color("e2edda"), false, true)
	# Bancos e lixeiras: pés tocam o piso, assentos com colisao.
	for z: float in [-18.5, 18.5]:
		for x: float in [-16.0, 12.0]:
			_box(stage, "BancoConcreto", Vector3(x, .77, z),
				Vector3(3.6, .24, .83), Color("b1b1a5"), true)
			for dx: float in [-1.36, 1.36]:
				_box(stage, "ApoioBanco", Vector3(x + dx, .45, z),
					Vector3(.30, .43, .68), CONCRETE, true)
		_box(stage, "LixeiraQuadra", Vector3(-23.5, .72, z),
			Vector3(.64, .95, .62), Color("34625b"), true)
	# Pequenos residuos de papel encostados no piso, visuais e de baixo custo.
	if visuals_enabled:
		var litter_rng := RandomNumberGenerator.new()
		litter_rng.seed = 241106
		for i in 27:
			var p := Vector3(litter_rng.randf_range(-31.0, 29.0), .251,
				litter_rng.randf_range(-20.5, 20.5))
			var scrap := _box(stage, "PapelNoChao", p,
				Vector3(.18, .012, .14), Color("b7afa0") if i % 2 == 0 else Color("d9cfbc"))
			scrap.rotation.y = litter_rng.randf_range(0, TAU)
	stage.set_meta("baile_stage_ready", true)
	stage.set_meta("baile_collisions_shared", true)

func _collider(parent: Node3D, label: String, at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = label if not parent.has_node(label) else "%s_%03d" % [label, parent.get_child_count()]
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = at
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)

func _material(color: Color, glowing: bool) -> StandardMaterial3D:
	var key := color.to_html() + ("_glow" if glowing else "")
	if materials.has(key):
		return materials[key] as StandardMaterial3D
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = .78 if glowing else .91
	if glowing:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 2.7
	materials[key] = mat
	return mat

func _box(parent: Node3D, label: String, at: Vector3, size: Vector3,
		color: Color, solid := false, glowing := false) -> Node3D:
	if not visuals_enabled and not solid:
		return null
	var holder: Node3D = StaticBody3D.new() if solid else MeshInstance3D.new()
	holder.name = label if not parent.has_node(label) else "%s_%03d" % [label, parent.get_child_count()]
	holder.position = at
	if solid:
		var body := holder as StaticBody3D
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.add_child(shape)
	if visuals_enabled:
		var visual: MeshInstance3D
		if solid:
			visual = MeshInstance3D.new()
			visual.name = "Modelo"
			holder.add_child(visual)
		else:
			visual = holder as MeshInstance3D
		var mesh := BoxMesh.new()
		mesh.size = size
		visual.mesh = mesh
		visual.material_override = _material(color, glowing)
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if not solid:
			visual.visibility_range_end = 195.0
	parent.add_child(holder)
	return holder

func _speaker_cone(parent: Node3D, at: Vector3, radius: float) -> void:
	var instance := MeshInstance3D.new()
	instance.name = "Woofer"
	instance.position = at
	instance.rotation.z = PI * .5
	var cone := CylinderMesh.new()
	cone.top_radius = radius
	cone.bottom_radius = radius
	cone.height = .07
	cone.radial_segments = 20
	instance.mesh = cone
	instance.material_override = _material(Color("434b50"), false)
	parent.add_child(instance)

func _disc(parent: Node3D, at: Vector3, radius: float) -> void:
	if not visuals_enabled:
		return
	var turntable := MeshInstance3D.new()
	turntable.name = "PratoDJ"
	turntable.position = at
	var disk := CylinderMesh.new()
	disk.top_radius = radius
	disk.bottom_radius = radius
	disk.height = .045
	disk.radial_segments = 24
	turntable.mesh = disk
	turntable.material_override = _material(Color("151a1d"), false)
	turntable.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(turntable)

func _light_beam(parent: Node3D, origin: Vector3, target: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = "FachoBaile_%d" % beams.size()
	var ray := target - origin
	instance.position = (origin + target) * .5
	instance.quaternion = Quaternion(Vector3.UP, ray.normalized())
	var cone := CylinderMesh.new()
	cone.top_radius = 2.1
	cone.bottom_radius = .12
	cone.height = ray.length()
	cone.radial_segments = 10
	instance.mesh = cone
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(color.r, color.g, color.b, .12)
	instance.material_override = mat
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.visibility_range_end = 165.0
	parent.add_child(instance)
	return instance

func _process(delta: float) -> void:
	playlist_tick += delta
	if playlist_tick >= CHECK_INTERVAL:
		playlist_tick = 0.0
		_update_playlist()
	if lights.is_empty():
		return
	light_clock += delta
	if light_clock < .18:
		return
	light_clock = 0.0
	var beat := Time.get_ticks_msec() / 1000.0
	var colors := [PINK, CYAN, GOLD, Color("9e6ef8"), LIME]
	for i in lights.size():
		lights[i].light_color = colors[posmod(i + floori(beat * 1.5), colors.size())]
		lights[i].light_energy = 1.0 + .85 * (.5 + .5 * sin(beat * 4.5 + float(i)))
	for i in beams.size():
		var tone: Color = colors[posmod(i + floori(beat * 1.5), colors.size())]
		var mat := beams[i].material_override as StandardMaterial3D
		mat.albedo_color = Color(tone.r, tone.g, tone.b,
			.11 + .04 * sin(beat * 4.5 + float(i)))

func begin() -> void:
	local_start_usec = Time.get_ticks_usec()
	voice = AudioStreamPlayer3D.new()
	voice.name = "SomDoBaile"
	voice.bus = "Ambiente" if AudioServer.get_bus_index("Ambiente") >= 0 else "Master"
	# A fonte sonora permanece no paredao; o som nunca ultrapassa 100 metros.
	voice.position = Vector3(-39.0, 3.0, 0.0)
	voice.max_distance = HEARING_RADIUS
	voice.unit_size = 22.0
	voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	voice.volume_db = -3.0
	add_child(voice)
	# Carregar as seis duracoes antes de iniciar garante ordem/offset iguais em
	# todos os clientes, inclusive para quem entrar no meio da musica.
	for path: String in TRACK_PATHS:
		var stream := load(path) as AudioStream if ResourceLoader.exists(path) else null
		track_streams.append(stream)
		track_durations.append(maxf(1.0, stream.get_length()) if stream != null else 180.0)
	_update_playlist()

func _authority_timeline() -> Dictionary:
	var node := get_parent()
	while node != null:
		if node.has_meta("war_mode"):
			# Evitar dependencia circular do controlador com WarGame.
			var authority_seed := int(node.get("weather_seed"))
			if authority_seed <= 0:
				return {}
			return {"seed": authority_seed, "time": maxf(0.0, float(node.get("war_clock")))}
		node = node.get_parent()
	# Cenas de QA/preview sem WarGame possuem um relogio local previsivel.
	return {"seed": 1, "time": float(Time.get_ticks_usec() - local_start_usec) * 0.000001}

func _order_for_cycle(seed_value: int, cycle: int, preceding: int) -> Array[int]:
	var indices: Array[int] = []
	for i in TRACK_PATHS.size():
		indices.append(i)
	var shuffle_rng := RandomNumberGenerator.new()
	shuffle_rng.seed = seed_value + cycle * 7919
	for i in range(indices.size() - 1, 0, -1):
		var j := shuffle_rng.randi_range(0, i)
		var current: int = indices[i]
		indices[i] = indices[j]
		indices[j] = current
	if indices.size() > 1 and indices[0] == preceding:
		var first: int = indices[0]
		indices[0] = indices[1]
		indices[1] = first
	return indices

func _song_at(seed_value: int, seconds: float) -> Dictionary:
	var elapsed := maxf(0.0, seconds)
	var cycle := 0
	var preceding := -1
	# Sem estado aleatorio por cliente: playlist e tempo dependem somente
	# da semente e do relogio recebidos do servidor.
	while cycle < 1000:
		var order := _order_for_cycle(seed_value, cycle, preceding)
		for index: int in order:
			var length: float = track_durations[index]
			if elapsed < length:
				return {"index": index, "offset": elapsed}
			elapsed -= length
		preceding = order.back()
		cycle += 1
	return {"index": 0, "offset": 0.0}

func _update_playlist() -> void:
	if not is_instance_valid(voice) or track_durations.size() != TRACK_PATHS.size():
		return
	var timeline := _authority_timeline()
	if timeline.is_empty():
		if voice.playing:
			voice.stop()
		return
	var seed_value := int(timeline.seed)
	var desired := _song_at(seed_value, float(timeline.time))
	var index := int(desired.index)
	var offset := float(desired.offset)
	# O playback continua sincronizado ao longe; apenas o audio local para.
	# Ao voltar para a quadra, retoma a faixa no instante correto.
	var camera := get_viewport().get_camera_3d()
	if is_instance_valid(camera) and camera.global_position.distance_to(voice.global_position) > HEARING_RADIUS:
		if voice.playing:
			voice.stop()
		last_track = -1
		return
	if last_track == index and last_seed == seed_value and voice.playing:
		var actual := voice.get_playback_position()
		if absf(actual - offset) < 0.40:
			return
		voice.seek(offset)
		last_position = offset
		return
	last_track = index
	last_seed = seed_value
	var stream: AudioStream = track_streams[index]
	if stream == null:
		push_warning("Baile: faixa %d ausente; usando batida original de reserva." % index)
		stream = _backup_beat()
		voice.stream = stream
		voice.play(fposmod(offset, 4.0))
	else:
		voice.stream = stream
		voice.play(offset)
	last_position = offset

func _backup_beat() -> AudioStreamWAV:
	# Batida instrumental original de reserva, sintetizada em memoria.
	# Nao incorpora amostras ou melodias de gravacoes comerciais.
	const RATE := 22050
	const SECONDS := 4
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = RATE * SECONDS
	var pcm := PackedByteArray()
	pcm.resize(wav.loop_end * 2)
	for i in wav.loop_end:
		var t := float(i) / float(RATE)
		var beat := fposmod(t, .5)
		var hat := fposmod(t, .25)
		var clap := fposmod(t - .5, 1.0)
		var noise := float((i * 173 + 311) % 1021) / 510.5 - 1.0
		var kick := sin(TAU * (74.0 * beat - 25.0 * beat * beat)) * exp(-beat * 16.0) * .43
		var hat_hit := noise * exp(-hat * 65.0) * .075
		var clap_hit := noise * exp(-clap * 38.0) * .16 if clap < .16 else 0.0
		var bass := sin(TAU * 55.0 * t) * exp(-beat * 8.0) * .17
		var sample := clampi(roundi((kick + hat_hit + clap_hit + bass) * 28000.0), -32768, 32767)
		pcm[i * 2] = sample & 255
		pcm[i * 2 + 1] = (sample >> 8) & 255
	wav.data = pcm
	return wav
