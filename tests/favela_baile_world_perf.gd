extends SceneTree
const MAP = preload("res://modes/war/scripts/favela_map.gd")
const SAMPLES := 180
var results := {}
var controller: Node
var audio_peak_db := -200.0

func _initialize() -> void:
    _run.call_deferred()

func _sample(label: String, lights_enabled: bool) -> void:
    for light in controller.lights:
        light.visible = lights_enabled
    for beam in controller.beams:
        beam.visible = lights_enabled
    for i in 70:
        await process_frame
    var values: Array[float] = []
    var prior := Time.get_ticks_usec()
    for i in SAMPLES:
        await process_frame
        var current := Time.get_ticks_usec()
        values.append((current - prior) * .001)
        prior = current
        var bus := AudioServer.get_bus_index(controller.voice.bus)
        if bus >= 0:
            audio_peak_db = maxf(audio_peak_db, AudioServer.get_bus_peak_volume_left_db(bus, 0))
    values.sort()
    var sum := 0.0
    for ms in values:
        sum += ms
    var mean := sum / values.size()
    results[label] = {"mean_ms":snappedf(mean, .001),"fps":snappedf(1000.0 / mean, .01),
        "p50_ms":values[90],"p95_ms":values[171],"p99_ms":values[178]}

func _run() -> void:
    if DisplayServer.get_name() == "headless":
        push_error("Full Favela benchmark precisa de renderizacao real")
        quit(2)
        return
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    Engine.max_fps = 0
    WarRules.configure(WarOperation.FAVELA)
    WarTerrain.configure(WarOperation.FAVELA)
    var world := Node3D.new()
    root.add_child(world)
    var map := MAP.new() as Node3D
    map.render_visuals = true
    world.add_child(map)
    var build_start := Time.get_ticks_usec()
    map.build()
    var build_ms := (Time.get_ticks_usec() - build_start) * .001
    var stage := map.get_node_or_null("CampoDeBaile") as Node3D
    if stage == null:
        push_error("CampoDeBaile inexistente")
        quit(1)
        return
    controller = stage.get_node_or_null("ControleBaile")
    var camera := Camera3D.new()
    camera.position = stage.global_position + Vector3(0, 10, 44)
    camera.look_at_from_position(camera.position, stage.global_position + Vector3(-39, 3, 0))
    camera.current = true
    world.add_child(camera)
    var audio_listener := AudioListener3D.new()
    camera.add_child(audio_listener)
    audio_listener.make_current()
    await process_frame
    var listener: Camera3D = root.get_camera_3d()
    print("BAILE_WORLD_DIAG ", JSON.stringify({"stage":str(stage.global_position),
        "camera":str(camera.global_position),"voice":str(controller.voice.global_position),
        "camera_distance":camera.global_position.distance_to(controller.voice.global_position),
        "active_listener_distance":listener.global_position.distance_to(controller.voice.global_position) if listener != null else -1.0,
        "timeline":controller._authority_timeline(),"voice_playing_before":controller.voice.playing}))
    controller._update_playlist()
    print("BAILE_WORLD_DIAG_AFTER ", JSON.stringify({"voice_playing":controller.voice.playing,
        "stream":str(controller.voice.stream),"offset":controller.voice.get_playback_position()}))
    var range_results := {}
    for distance in [3.0, 30.0, 60.0, 90.0, 110.0]:
        camera.global_position = controller.voice.global_position + Vector3(0, 0, distance)
        var best_db := -200.0
        for frame in 70:
            await process_frame
            var bus_index := AudioServer.get_bus_index(controller.voice.bus)
            if bus_index >= 0:
                best_db = maxf(best_db, AudioServer.get_bus_peak_volume_left_db(bus_index, 0))
        range_results[str(distance)] = {"peak_db":best_db,"playing":controller.voice.playing}
    print("BAILE_WORLD_AUDIO_RANGE ", JSON.stringify(range_results))
    camera.global_position = stage.global_position + Vector3(0, 10, 44)
    await _sample("lights_off", false)
    await _sample("lights_on", true)
    await _sample("lights_off_again", false)
    print("FAVELA_BAILE_WORLD_PERF ", JSON.stringify({"display":DisplayServer.get_name(),"resolution":"1920x1080",
        "map_build_ms":build_ms,"audio_peak_db":audio_peak_db,
        "audio_playing":controller.voice.playing,
        "lights":controller.lights.size(),"beams":controller.beams.size(),
        "samples_per_pass":SAMPLES,"results":results}))
    world.queue_free()
    await process_frame
    quit.call_deferred(0)
