extends SceneTree

var failures: Array[String]=[]
var checks:=0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool,description: String) -> void:
	checks+=1
	print(("PASS " if ok else "FAIL ")+description)
	if not ok: failures.append(description)

func close(a: float,b: float,margin:=.002) -> bool:
	return absf(a-b)<margin

func rms(buffer: PackedVector2Array) -> float:
	if buffer.is_empty(): return 0.0
	var power:=0.0
	for frame in buffer:
		power+=frame.length_squared()*.5
	return sqrt(power/float(buffer.size()))

func run() -> void:
	var boost:=linear_to_db(1.05)
	check(close(GameSoundPropagation.distant_gain_db(0.),0.),"zero meters has no boost")
	check(close(GameSoundPropagation.distant_gain_db(100.),0.),"near-field fire is unchanged")
	check(close(GameSoundPropagation.distant_gain_db(350.),0.),"boost starts at 350 meters")
	check(GameSoundPropagation.distant_gain_db(475.)>0.0 and GameSoundPropagation.distant_gain_db(475.)<boost,"transition is smooth between 350 and 600 meters")
	check(close(GameSoundPropagation.distant_gain_db(600.),boost,.00001),"600 meters receives exactly five percent amplitude gain")
	check(close(GameSoundPropagation.distant_gain_db(1500.),boost,.00001),"beyond 600 meters no further volume growth")
	check(close(GameSoundPropagation.delay(600.),600./343.,.00001),"speed of sound and propagation delay stay unchanged")
	if DisplayServer.get_name()=="headless":
		print("Requires native audio mix")
		quit(2)
		return

	var scene:=Node3D.new()
	root.add_child(scene)
	var camera:=Camera3D.new()
	scene.add_child(camera)
	camera.current=true
	var listener:=AudioListener3D.new()
	scene.add_child(listener)
	listener.make_current()
	var guns:=GameWeaponAudio.new()
	scene.add_child(guns)
	var explosions:=GameExplosionAudio.new()
	scene.add_child(explosions)
	await process_frame

	var near_gun:=guns._play_now(100,"g3",Vector3(0,0,-50))
	var distant_gun:=guns._play_now(101,"g3",Vector3(0,0,-600))
	check(is_instance_valid(near_gun) and is_instance_valid(distant_gun),"G3 sounds load at 50 and 600 meters")
	if is_instance_valid(near_gun) and is_instance_valid(distant_gun):
		check(close(near_gun.volume_db,float(near_gun.get_meta("base_db")),.002),"50m shot remains at original close-range gain")
		check(close(distant_gun.volume_db,float(distant_gun.get_meta("base_db"))+boost,.002),"600m shot gains 0.424dB without changing panning or dropoff")
		check(distant_gun.global_position==Vector3(0,0,-600),"600m shot retains the actual spatial origin")

	var near_blast:=explosions._start("far-gain:near",Vector3(0,0,-50),"destroy")
	var far_blast:=explosions._start("far-gain:600",Vector3(0,0,-600),"destroy")
	check(is_instance_valid(near_blast) and is_instance_valid(far_blast),"tank explosion near/far versions still play")
	if is_instance_valid(near_blast) and is_instance_valid(far_blast):
		var expected_near:=float(explosions.event_profile("destroy").db)+GameExplosionAudio.near_presence_db("destroy",50.)
		check(close(near_blast.volume_db,expected_near,.002),"nearby tank explosion preserves original strong impact")
		var expected_far:=float(explosions.event_profile("destroy").db)+boost
		check(close(far_blast.volume_db,expected_far,.002),"600m tank explosion gains exactly five percent before 3D falloff")
		check(far_blast.stream.resource_path==GameCombatAudioCatalog.EXPLOSIONS_FAR[1],"distant tank keeps its V3 distant sample")
		check(far_blast.unit_size==float(explosions.event_profile("destroy").unit) and far_blast.global_position==Vector3(0,0,-600),"distance profile and 3D position remain intact")

	# Compare actual output from the same V3 file at 600m; below limiter
	# threshold the 5% source gain should reach the mix as ~5% RMS.
	for voice in guns.voices: voice.stop()
	for voice in explosions.voices: voice.stop()
	for voice in explosions.pressure_voices: voice.stop()
	var master:=AudioServer.get_bus_index("Master")
	var capture:=AudioEffectCapture.new()
	capture.buffer_length=2.0
	AudioServer.add_bus_effect(master,capture)
	var measured: Array[float]=[]
	for baseline in [true,false]:
		for voice in explosions.voices: voice.stop()
		await create_timer(.15).timeout
		capture.clear_buffer()
		var test_voice:=explosions._start("far-pcm:"+str(baseline),Vector3(0,0,-600),"destroy")
		if is_instance_valid(test_voice):
			if baseline: test_voice.volume_db-=boost
			await create_timer(.9).timeout
			measured.append(rms(capture.get_buffer(capture.get_frames_available())))
		else:
			measured.append(0.0)
	AudioServer.remove_bus_effect(master,AudioServer.get_bus_effect_count(master)-1)
	var ratio:=measured[1]/maxf(.0000001,measured[0])
	print("FAR_AUDIO_PCM ",JSON.stringify({"baseline_rms":measured[0],"boosted_rms":measured[1],"amplitude_ratio":ratio,"expected":1.05}))
	check(ratio>=1.02 and ratio<=1.08,"600m sampled PCM mix is approximately five percent louder")

	print("AUDIO_FAR_GAIN ",JSON.stringify({"checks":checks,"failures":failures,"boost_db":boost}))
	scene.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
