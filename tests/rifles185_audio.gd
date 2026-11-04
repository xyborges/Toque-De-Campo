extends SceneTree
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func run() -> void:
	Engine.max_fps=60
	var stage:=Node3D.new();root.add_child(stage)
	var camera:=Camera3D.new();stage.add_child(camera);camera.current=true
	var audio:=GameWeaponAudio.new();stage.add_child(audio)
	var path: String="res://audio/"+GameWeaponAudio.PATHS.fal
	var stream:=GameCombatAudioCatalog.stream(path) as AudioStreamWAV
	check(path=="res://audio/fal-098.wav" and stream!=null,"FAL resolves the supplied sound_098 recording")
	if stream==null: quit(1);return
	check(absf(stream.get_length()-.59637)<.01 and not stream.stereo,"supplied mono recording imports with its original duration")
	check(stream.loop_mode==AudioStreamWAV.LOOP_DISABLED,"gunshot sample does not loop")
	var bus:=AudioServer.get_bus_index("WeaponShots")
	var capture:=AudioEffectCapture.new();capture.buffer_length=5;AudioServer.add_bus_effect(bus,capture)
	for i in 20:
		audio.play(7,"fal",Vector3(0,0,-1));await create_timer(.13).timeout
	check(audio.started_events==20,"every trigger in a full FAL magazine starts its own sound")
	check(audio.voices.size()==GameWeaponAudio.LIMIT and audio.pools["7:fal"].size()<=24,"burst reuses bounded spatial audio voices")
	await create_timer(.7).timeout
	var playing:=0
	for voice in audio.voices:
		if voice.playing: playing+=1
	check(playing==0,"all tails finish after releasing the trigger")
	var peak:=0.0;var energy:=0.0
	var frames:=capture.get_buffer(capture.get_frames_available())
	for frame in frames:
		peak=maxf(peak,maxf(absf(frame.x),absf(frame.y)));energy+=frame.length_squared()
	check(frames.size()>0 and energy>0,"actual supplied sample produces an audible captured mix")
	check(peak<1.0,"captured full-magazine mix remains below digital clipping")
	var report: Dictionary={"checks":checks,"failures":failures,"started_events":audio.started_events,"mix_peak":peak,"frames":frames.size(),"sample":path}
	NavalStorage.write_json("res://tests/rifles185-audio-results.json",report);print(JSON.stringify(report))
	stage.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
