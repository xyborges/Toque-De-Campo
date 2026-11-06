extends SceneTree
## Native PCM test of the Favela speaker in the full map.
## Samples at a musical segment: the supplied first MP3 has recorded silence
## between roughly 3 and 10 seconds; a silent waveform is not a mixer failure.
const MAP = preload("res://modes/war/scripts/favela_map.gd")
var failures: Array[String] = []
var readings: Array[Dictionary] = []
var capture: AudioEffectCapture

func _initialize() -> void:
	_run.call_deferred()

func _verify(ok: bool, name: String) -> void:
	print(("PASS " if ok else "FAIL ") + name)
	if not ok: failures.append(name)

func _measure(controller: Node, camera: Camera3D, distance: float) -> Dictionary:
	var voice := controller.voice as AudioStreamPlayer3D
	camera.global_position = voice.global_position + Vector3(0.0, 0.0, distance)
	controller._update_playlist()
	await create_timer(0.25).timeout
	capture.clear_buffer()
	await create_timer(0.48).timeout
	var frames := capture.get_buffer(capture.get_frames_available())
	var power := 0.0
	for frame in frames:
		power += frame.x * frame.x + frame.y * frame.y
	return {"distance": distance, "rms": sqrt(power / maxf(1.0, float(frames.size()) * 2.0)),
		"frames": frames.size(), "playing": voice.playing,
		"position": voice.get_playback_position()}

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("PCM verification requires the native audio mixer")
		quit(2)
		return
	WarRules.configure(WarOperation.FAVELA)
	WarTerrain.configure(WarOperation.FAVELA)
	var world := Node3D.new()
	root.add_child(world)
	var map := MAP.new() as Node3D
	map.render_visuals = true
	world.add_child(map)
	map.build()
	var stage := map.get_node_or_null("CampoDeBaile") as Node3D
	_verify(stage != null, "full map has the field")
	if not is_instance_valid(stage):
		quit(1)
		return
	var controller := stage.get_node_or_null("ControleBaile")
	_verify(is_instance_valid(controller) and is_instance_valid(controller.voice), "speaker exists and is a 3D emitter")
	if not is_instance_valid(controller) or not is_instance_valid(controller.voice):
		quit(1)
		return
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	var listener := AudioListener3D.new()
	camera.add_child(listener)
	listener.make_current()
	var voice := controller.voice as AudioStreamPlayer3D
	var bus := AudioServer.get_bus_index(voice.bus)
	_verify(bus >= 0 and listener.is_current(), "listener and audio bus are live")
	if bus < 0:
		quit(1)
		return
	capture = AudioEffectCapture.new()
	capture.buffer_length = 1.0
	AudioServer.add_bus_effect(bus, capture)
	await process_frame
	# The first MP3's audible segment is after its embedded quiet interval.
	# This preserves the original music and tests the actual 3D propagation.
	controller.local_start_usec = Time.get_ticks_usec() - 14000000
	for distance in [3.0, 30.0, 60.0, 90.0, 110.0]:
		readings.append(await _measure(controller, camera, distance))
	_verify(readings[0].frames > 4096 and readings[0].rms > 0.00001 and readings[0].playing,
		"full-map speaker yields PCM at 3m")
	_verify(readings[1].rms > 0.000002 and readings[1].playing,
		"the same MP3 is audible at 30m")
	_verify(readings[3].rms > 0.0000002 and readings[3].playing,
		"the MP3 is audible at 90m")
	_verify(readings[0].rms > readings[3].rms,
		"sound decreases with distance")
	_verify(not readings[4].playing, "audio stops beyond 100m")
	print("FAVELA_BAILE_AUDIO_WORLD_QA ", JSON.stringify({
		"ok": failures.is_empty(), "failures": failures, "source": str(voice.global_position),
		"bus": voice.bus, "samples": readings}))
	AudioServer.remove_bus_effect(bus, AudioServer.get_bus_effect_count(bus) - 1)
	world.queue_free()
	await process_frame
	quit.call_deferred(0 if failures.is_empty() else 1)
