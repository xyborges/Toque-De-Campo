extends SceneTree
const BAILE = preload("res://modes/war/scripts/favela_baile.gd")
const SAMPLES := 200
var results := {}
var stage: Node3D
var ctrl: Node
var audio_peak_db := -200.0

func _initialize() -> void:
    _run.call_deferred()

func _measure(label: String, enabled: bool) -> void:
    for lamp in ctrl.lights:
        lamp.visible = enabled
    for beam in ctrl.beams:
        beam.visible = enabled
    for i in 90:
        await process_frame
    var values: Array[float] = []
    var before := Time.get_ticks_usec()
    for i in SAMPLES:
        await process_frame
        var now := Time.get_ticks_usec()
        values.append((now - before) * .001)
        before = now
        var bus_index := AudioServer.get_bus_index(ctrl.voice.bus)
        if bus_index >= 0:
            audio_peak_db = maxf(audio_peak_db, AudioServer.get_bus_peak_volume_left_db(bus_index, 0))
    values.sort()
    var total := 0.0
    for x in values:
        total += x
    var mean := total / values.size()
    results[label] = {"mean_ms":snappedf(mean,.001),"fps":snappedf(1000.0 / maxf(mean,.01),.01),"p50_ms":values[100],"p95_ms":values[190],"p99_ms":values[198]}

func _run() -> void:
    if DisplayServer.get_name() == "headless":
        push_error("Nao e possivel medir FPS de GPU em headless")
        quit(2)
        return
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    Engine.max_fps = 0
    var world := Node3D.new()
    root.add_child(world)
    var camera := Camera3D.new()
    camera.position = Vector3(-12, 10, 35)
    camera.look_at_from_position(camera.position, Vector3(-35, 3, 0))
    camera.current = true
    world.add_child(camera)
    stage = load("res://modes/war/library/favela_campo_baile.tscn").instantiate()
    stage.position = Vector3(430, 121, -275)
    world.add_child(stage)
    camera.global_position = stage.global_position + Vector3(-12, 10, 35)
    camera.look_at(stage.global_position + Vector3(-35, 3, 0))
    BAILE.start(stage, true)
    ctrl = stage.get_node("ControleBaile")
    await _measure("lights_off", false)
    await _measure("lights_on", true)
    await _measure("lights_off_again", false)
    print("FAVELA_BAILE_LIGHT_PERF ", JSON.stringify({"display":DisplayServer.get_name(),"lights":ctrl.lights.size(),"beams":ctrl.beams.size(),"samples_per_pass":SAMPLES,"audio_peak_db":audio_peak_db,"audio_playing":ctrl.voice.playing,"results":results}))
    world.queue_free()
    await process_frame
    quit.call_deferred(0)
