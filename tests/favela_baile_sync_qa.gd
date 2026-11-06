extends SceneTree
const BAILE = preload("res://modes/war/scripts/favela_baile.gd")
var checks := 0
var failures: Array[String] = []

func verify(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures.append(message)
        push_error("BAILE_SYNC_FAIL " + message)

func _initialize() -> void:
    _run.call_deferred()

func _run() -> void:
    var world := Node3D.new()
    root.add_child(world)
    var camera := Camera3D.new()
    camera.position = Vector3(-39, 4, 8)
    camera.current = true
    world.add_child(camera)
    var stage := load("res://modes/war/library/favela_campo_baile.tscn").instantiate() as Node3D
    stage.position = Vector3(300, 20, -100)
    world.add_child(stage)
    camera.global_position = stage.global_position + Vector3(-39, 4, 8)
    BAILE.start(stage, true)
    await process_frame
    var ctrl := stage.get_node("ControleBaile") as Node
    verify(ctrl != null, "Controlador ausente")
    if ctrl == null:
        quit(1)
        return
    var voice := stage.find_child("SomDoBaile", true, false) as AudioStreamPlayer3D
    verify(voice != null, "Player 3D ausente")
    if voice != null:
        verify(voice.global_position.distance_to(stage.global_position + Vector3(-39, 3, 0)) < 0.1,
            "Posicao global do som fora do palco")
    verify(ctrl.TRACK_PATHS.size() == 6, "Precisamos de seis faixas")
    verify(ctrl.track_streams.size() == 6, "Seis streams devem carregar")
    for i in 6:
        verify(ctrl.track_streams[i] != null, "MP3 indisponivel: %d" % i)
        verify(ctrl.track_durations[i] > 10.0, "Duracao MP3 invalida: %d" % i)
    verify(is_equal_approx(voice.max_distance, 100.0), "Distancia diferente de 100m")
    verify(voice.playing, "Musica nao iniciou imediatamente")
    verify(ctrl._song_at(12345, 0.0).offset == 0.0, "Inicio nao e zero")
    for seed_value in [1, 42, 12345, 899999]:
        var order: Array = ctrl._order_for_cycle(seed_value, 0, -1)
        verify(order.size() == 6, "Playlist tem seis entradas")
        for i in 6:
            verify(i in order, "Playlist perdeu faixa")
        var previous: int = int(order.back())
        var next_cycle: Array = ctrl._order_for_cycle(seed_value, 1, previous)
        verify(next_cycle[0] != previous, "Repetiu faixa entre ciclos")
        for t in [0.0, 15.5, 123.0, 620.0, 1380.0, 2500.0]:
            var a: Dictionary = ctrl._song_at(seed_value, t)
            var b: Dictionary = ctrl._song_at(seed_value, t)
            verify(a == b, "Determinismo entre clientes falhou")
            verify(a.offset >= 0.0 and a.offset < ctrl.track_durations[a.index], "Offset fora da faixa")
    camera.global_position = voice.global_position + Vector3(110, 0, 0)
    ctrl._update_playlist()
    verify(not voice.playing, "Musica segue tocando fora de 100m")
    camera.global_position = voice.global_position + Vector3(10, 0, 0)
    ctrl._update_playlist()
    verify(voice.playing, "Musica nao retomou dentro dos 100m")
    world.queue_free()
    await process_frame
    print("FAVELA_BAILE_SYNC_QA ", JSON.stringify({"ok":failures.is_empty(),"checks":checks,"errors":failures}))
    quit.call_deferred(0 if failures.is_empty() else 1)
