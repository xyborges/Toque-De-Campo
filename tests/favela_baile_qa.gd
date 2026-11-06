extends SceneTree
const BAILE = preload("res://modes/war/scripts/favela_baile.gd")
## QA isolado da quadra, palco, colisao cliente/servidor e playlist.
var failures: Array[String] = []
var checks := 0

func verify(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error("BAILE_QA_FAIL " + message)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var source := load("res://modes/war/library/favela_campo_baile.tscn") as PackedScene
	verify(source != null, "Cena do campo ausente")
	if source == null:
		quit(1)
		return
	var field := source.instantiate() as Node3D
	root.add_child(field)
	BAILE.start(field, true)
	await process_frame
	verify(field.has_meta("baile_stage_ready"), "Palco nao construido")
	verify(field.get_node_or_null("Palco") is StaticBody3D, "Palco sem contato")
	verify(field.get_node_or_null("ContatoQuadra") is StaticBody3D, "Piso sem contato")
	var bodies := field.find_children("*", "StaticBody3D", true, false)
	verify(bodies.size() >= 35, "Colisores insuficientes: " + str(bodies.size()))
	var goal_count := 0
	var speakers := 0
	for body in bodies:
		if body.name.begins_with("PosteGol"):
			goal_count += 1
		if body.name.begins_with("CaixaSom"):
			speakers += 1
		var has_shape := false
		for child in body.get_children():
			if child is CollisionShape3D and child.shape != null:
				has_shape = true
		verify(has_shape, "Contato sem shape: " + body.name)
	verify(goal_count == 4, "Traves com contato incompleto")
	verify(speakers == 2, "Paredao sem duas caixas fisicas")
	var player := field.find_child("SomDoBaile", true, false) as AudioStreamPlayer3D
	verify(player != null, "Fonte sonora nao instanciada")
	if player != null:
		verify(player.position.x < -30.0, "Audio fora do palco")
		verify(player.max_distance >= 150.0, "Alcance do som insuficiente")
		verify(player.stream != null and player.playing, "Musica ou batida de reserva nao iniciou")
	verify(field.find_children("LuzBaile_*", "OmniLight3D", true, false).size() == 6,
		"Efeitos de luz ausentes")
	verify(field.find_children("FachoBaile_*", "MeshInstance3D", true, false).size() == 4,
		"Fachos de luz volumetricos ausentes")
	verify(field.get_node_or_null("BalcaoDJ") is StaticBody3D, "Balcao DJ sem contato")
	field.queue_free()
	await process_frame
	var server_field := source.instantiate() as Node3D
	root.add_child(server_field)
	BAILE.start(server_field, false)
	await process_frame
	var server_bodies := server_field.find_children("*", "StaticBody3D", true, false)
	verify(server_bodies.size() == bodies.size(), "Cliente e servidor nao compartilham colisores")
	verify(server_field.find_child("SomDoBaile", true, false) == null, "Servidor reproduziu audio")
	server_field.queue_free()
	await process_frame
	print("FAVELA_BAILE_QA ", JSON.stringify({"ok":failures.is_empty(),
		"checks":checks, "errors":failures, "physics_bodies":bodies.size()}))
	quit.call_deferred(0 if failures.is_empty() else 1)
