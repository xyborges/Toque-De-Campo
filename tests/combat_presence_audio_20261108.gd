extends SceneTree

# QA for a GLOBAL combat-loudness revision, not a Favela-only tuning.
var failures: Array[String]=[]
var checks:=0

func _initialize() -> void:
	run.call_deferred()

func verify(ok: bool,label: String) -> void:
	checks+=1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)

func within(x: float,y: float,tolerance:=.03) -> bool:
	return absf(x-y)<=tolerance

func measure_pcm(frames: PackedVector2Array) -> Dictionary:
	var energy:=0.0
	var peak:=0.0
	for frame in frames:
		energy+=frame.length_squared()*.5
		peak=maxf(peak,maxf(absf(frame.x),absf(frame.y)))
	return {"rms":sqrt(energy/maxf(1.,float(frames.size()))),"peak":peak,"count":frames.size()}

func run() -> void:
	var distances: Array[float]=[0.,50.,150.,250.,400.,600.,1000.]
	var previous:=-100.0
	for distance in distances:
		var gain:=GameSoundPropagation.combat_presence_db(distance)
		verify(gain>=previous and is_finite(gain),"combat presence remains smooth and nondecreasing at "+str(int(distance))+" m")
		previous=gain
	verify(within(GameSoundPropagation.combat_presence_db(0.),3.5,.001),"near-field gets a moderate, peak-limited boost")
	verify(GameSoundPropagation.combat_presence_db(400.)>=10.0,"all modes receive substantial, not token, combat gain around 400m")
	verify(GameSoundPropagation.combat_presence_db(600.)>11.5 and GameSoundPropagation.combat_presence_db(1000.)==12.5,"presence gain rises toward its bounded cap without reversing 3D distance")
	verify(within(GameSoundPropagation.delay(400.),400.0/343.0,.00001),"physical propagation speed and delay unchanged")
	# The natural 3D loss for the largest current combat unit_size (240m)
	# must always exceed any added gain between increasing distances.
	var previous_heavy:=INF
	for dist in [0.,25.,50.,100.,150.,200.,250.,400.,500.,600.,700.,1000.,1500.]:
		var effective_db:=GameSoundPropagation.combat_presence_db(dist)+GameSoundPropagation.distant_gain_db(dist)-linear_to_db(1.0+dist/240.0)
		verify(effective_db<=previous_heavy+.01,"even the heaviest cannon keeps fading at "+str(int(dist))+"m")
		previous_heavy=effective_db
	verify(GameWeaponAudio.FILTER_BLOCKED_HZ==5600.0,"wall coloration is less excessively dark")
	if DisplayServer.get_name()=="headless":
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
	var blasts:=GameExplosionAudio.new()
	scene.add_child(blasts)
	await process_frame

	var master:=AudioServer.get_bus_index("Master")
	var limiters:=0
	var limiter: AudioEffectLimiter
	for i in AudioServer.get_bus_effect_count(master):
		if AudioServer.get_bus_effect(master,i) is AudioEffectLimiter:
			limiter=AudioServer.get_bus_effect(master,i) as AudioEffectLimiter
			limiters+=1
	verify(limiters==1 and within(limiter.ceiling_db,-1.0,.001),"one peak limiter protects whole mix at -1 dBFS")
	var before:=AudioServer.get_bus_effect_count(master)
	GameAudioSettings.ensure()
	verify(before==AudioServer.get_bus_effect_count(master),"repeated audio initialization does not duplicate limiter")
	verify(AudioServer.get_bus_send(AudioServer.get_bus_index("Armas"))=="Efeitos","user combat-volume controls remain connected")

	var gun_names:=["glock","ak","fal","g3","sniper","lightMG","heavyMG","hmg","autocannon","tank","rpg","stinger","tv","missile"]
	for i in gun_names.size():
		var name: String=gun_names[i]
		var shot:=guns._play_now(100+i,name,Vector3(0,0,-400))
		var wanted:=float(GameWeaponAudio.profile(name).db)+GameSoundPropagation.combat_presence_db(400.)+GameSoundPropagation.distant_gain_db(400.)+GameWeaponAudio.distant_shot_relief_db(name,400.)
		verify(is_instance_valid(shot) and shot.playing,"weapon "+name+" has real loaded 3D sound at 400m")
		if is_instance_valid(shot):
			verify(within(shot.volume_db,wanted,.04),"weapon "+name+" receives calibrated long-range gain")
			verify(shot.max_db>=2.0 and shot.global_position.z==-400.,"weapon "+name+" keeps 3D origin with raised source ceiling")
			shot.stop()
	verify(guns.voices.size()==GameWeaponAudio.LIMIT,"96-voice weapons budget unchanged")
	# War/Favela/Afghan/Ukrainian modes use WarAudio; Naval and BR reuse
	# the base weapon manager. Check the War override that uses tank-fire.wav.
	var war:=WarAudio.new()
	scene.add_child(war)
	await process_frame
	var war_rifle:=war._play_now(1250,"fal",Vector3(0,0,-400))
	verify(is_instance_valid(war_rifle) and within(war_rifle.volume_db,GameWeaponAudio.profile("fal").db+GameSoundPropagation.combat_presence_db(400.)+GameSoundPropagation.distant_gain_db(400.)+GameWeaponAudio.distant_shot_relief_db("fal",400.),.04),"War mode inherits amplified world-space rifle")
	var war_cannon:=war._play_now(1251,"tank",Vector3(0,0,-400))
	verify(is_instance_valid(war_cannon) and war_cannon.stream.resource_path=="res://audio/war/tank-fire.wav","War tank override keeps its dedicated cannon sample")
	verify(is_instance_valid(war_cannon) and within(war_cannon.volume_db,GameWeaponAudio.profile("tank").db+GameSoundPropagation.combat_presence_db(400.)+GameSoundPropagation.distant_gain_db(400.),.04),"War tank cannon keeps global gain after stream override")
	var war_blast:=war.explosion_audio._start("war-presence:400",Vector3(0,0,-400),"destroy")
	verify(is_instance_valid(war_blast) and war_blast.volume_db>0.,"War vehicle destruction also inherits global explosion gain")
	for v in war.voices: v.stop()
	for v in war.explosion_audio.voices: v.stop()
	var gun:=guns._play_now(900,"ak",Vector3(0,0,-400))
	var free_gain:=gun.volume_db
	GameWeaponAudio.apply_acoustics(gun,400.,true,false)
	verify(gun.bus.begins_with("WeaponBlocked") and within(free_gain-gun.volume_db,4.5,.01),"remote rifle behind a Favela wall retains the original 4.5dB occlusion")
	verify(GameWeaponAudio.filter_target_hz(400.,1800.,true,false,0.)>=5500.,"occluded weapons retain useful midrange energy")
	gun.stop()
	var melee:=guns._play_now(901,"fists",Vector3(0,0,-4))
	verify(is_instance_valid(melee) and melee.volume_db<GameWeaponAudio.profile("fists").db+.5 and melee.max_db==-3.,"melee and tool swings are not boosted as gunshots")
	if is_instance_valid(melee): melee.stop()

	for kind in ["grenade","tank","destroy","drone","rpg","autocannon_ground","autocannon_metal"]:
		var source:=blasts._start("global-presence:"+kind,Vector3(0,0,-400),kind)
		verify(is_instance_valid(source) and source.playing,"explosion "+kind+" remains audible at 400m")
		if is_instance_valid(source):
			var weight:=float(source.get_meta("mix_weight",1.0))
			var expected:=float(blasts.event_profile(kind).db)+GameSoundPropagation.combat_presence_db(400.)+GameSoundPropagation.distant_gain_db(400.)+linear_to_db(weight)
			verify(within(source.volume_db,expected,.04),"explosion "+kind+" receives the same global distance calibration")
			verify(source.global_position.z==-400. and source.max_distance>=1400.,"explosion "+kind+" retains spatial range")
		for voice in blasts.voices: voice.stop()
	verify(blasts.voices.size()==24 and blasts.pressure_voices.size()==8,"explosion/pressure pool sizes unchanged")
	verify(blasts.pressure_started==0,"long-range explosions do not add unnecessary near-field pressure voices")

	# Steady state PCM A/B through the same 400m 3D path. No subjective
	# interpretation of transient timing or recorded sample differences.
	var capture:=AudioEffectCapture.new()
	capture.buffer_length=2.0
	AudioServer.add_bus_effect(master,capture)
	var tone:=AudioStreamWAV.new()
	tone.format=AudioStreamWAV.FORMAT_16_BITS
	tone.mix_rate=48000
	tone.stereo=false
	var bytes:=PackedByteArray()
	bytes.resize(4800*2)
	for i in 4800:
		bytes.encode_s16(i*2,int(sin(TAU*440.0*float(i)/48000.0)*1800.0))
	tone.data=bytes
	tone.loop_mode=AudioStreamWAV.LOOP_FORWARD
	tone.loop_end=4800
	var voice:=AudioStreamPlayer3D.new()
	scene.add_child(voice)
	voice.stream=tone
	voice.bus="WeaponFar"
	voice.attenuation_model=AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	voice.unit_size=95.0
	voice.max_distance=1800.
	voice.max_db=2.0
	voice.global_position=Vector3(0,0,-400)
	var pcm_levels: Array[Dictionary]=[]
	var extra_gain:=GameSoundPropagation.combat_presence_db(400.)
	for level in [-16.0,-16.0+extra_gain]:
		voice.volume_db=level
		voice.play()
		await create_timer(.24).timeout
		capture.clear_buffer()
		await create_timer(.38).timeout
		pcm_levels.append(measure_pcm(capture.get_buffer(capture.get_frames_available())))
		voice.stop()
		await create_timer(.16).timeout
	var measured_ratio:=float(pcm_levels[1].rms)/maxf(.00000001,float(pcm_levels[0].rms))
	var expected_ratio:=db_to_linear(extra_gain)
	print("COMBAT_PCM_GAIN ",JSON.stringify({"distance_m":400,"gain_db":extra_gain,"expected_amplitude":expected_ratio,"observed_amplitude":measured_ratio,"baseline":pcm_levels[0],"boosted":pcm_levels[1]}))
	verify(float(pcm_levels[0].rms)>.000001 and absf(measured_ratio/expected_ratio-1.0)<.10,"400m 3D output delivers the substantial, calibrated gain after buses and limiter")

	for v in guns.voices: v.stop()
	for v in blasts.voices: v.stop()
	for v in blasts.pressure_voices: v.stop()
	voice.stop()
	capture.clear_buffer()
	# Six rifles + two heavy explosions must not overflow the final mix.
	for i in 6: guns._play_now(2000+i,"fal",Vector3(float(i-3)*5.0,0,-80))
	for i in 2: blasts._start("peak-stress:"+str(i),Vector3(float(i)*10.,0,-120.),"destroy")
	await create_timer(.6).timeout
	var mixed:=measure_pcm(capture.get_buffer(capture.get_frames_available()))
	print("COMBAT_PCM_STRESS ",JSON.stringify(mixed))
	verify(mixed.count>0 and mixed.peak<=1.001,"final mix protects against digital overload when firearms and explosions overlap")
	AudioServer.remove_bus_effect(master,AudioServer.get_bus_effect_count(master)-1)

	print("COMBAT_PRESENCE_QA ",JSON.stringify({"checks":checks,"failures":failures}))
	scene.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
