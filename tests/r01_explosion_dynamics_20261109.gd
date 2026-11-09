extends SceneTree

# R01: compare true 3D PCM with/without the explosion-only transient compressor.
# No production WAVs, network logic, project settings or user volumes are changed.
var issues: Array[String]=[]
var checks:=0
var stage: Node3D
var explosions: GameExplosionAudio
var capture: AudioEffectCapture
var explosion_bus: int
var compressor_index: int
var master_bus: int

func _initialize() -> void:
	_run.call_deferred()

func verify(ok: bool, label: String) -> void:
	checks+=1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: issues.append(label)

func close(a: float,b: float,epsilon:=.08) -> bool:
	return absf(a-b)<=epsilon

func signal_metrics(frames: PackedVector2Array) -> Dictionary:
	var samples:=mini(frames.size(),int(AudioServer.get_mix_rate()*1.0))
	var sum_power:=0.0
	var max_peak:=0.0
	var near_ceiling:=0
	var digital_clip:=0
	for index in samples:
		var frame: Vector2=frames[index]
		var peak:=maxf(absf(frame.x),absf(frame.y))
		max_peak=maxf(max_peak,peak)
		sum_power+=frame.length_squared()*.5
		if peak>.885: near_ceiling+=1
		if peak>0.999: digital_clip+=1
	var rms:=sqrt(sum_power/maxf(1.,float(samples)))
	return {"peak_db":linear_to_db(maxf(.00000001,max_peak)),
		"rms_db":linear_to_db(maxf(.00000001,rms)),
		"near_ceiling_pct":100.0*near_ceiling/maxi(1,samples),
		"clipped_pct":100.0*digital_clip/maxi(1,samples),
		"frames":samples}

func measure(tag: String, kind: String, meters: float, events: int, enabled: bool) -> Dictionary:
	for voice in explosions.voices: voice.stop()
	for voice in explosions.pressure_voices: voice.stop()
	await create_timer(.35).timeout
	AudioServer.set_bus_effect_enabled(explosion_bus,compressor_index,enabled)
	capture.clear_buffer()
	var active_count:=0
	for event in events:
		var point:=Vector3(float(event)*2.5,0.,-meters)
		var player:=explosions._start(tag+":"+str(event),point,kind)
		if is_instance_valid(player): active_count+=1
	await create_timer(1.16).timeout
	var measurements:=signal_metrics(capture.get_buffer(capture.get_frames_available()))
	measurements.merge({"case":tag,"kind":kind,"distance_m":meters,
		"events":events,"active":active_count,"compressor":enabled})
	print("R01_EXPLOSION_PCM ",JSON.stringify(measurements))
	return measurements

func _run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("R01 mixer validation needs native audio")
		quit(2)
		return
	stage=Node3D.new()
	root.add_child(stage)
	var camera:=Camera3D.new()
	stage.add_child(camera)
	camera.current=true
	var listener:=AudioListener3D.new()
	stage.add_child(listener)
	listener.make_current()
	explosions=GameExplosionAudio.new()
	stage.add_child(explosions)
	await process_frame
	explosion_bus=AudioServer.get_bus_index("CombatExplosions")
	master_bus=AudioServer.get_bus_index("Master")
	var compressor_count:=0
	var limiter_count:=0
	var limiter_index:=99
	for i in AudioServer.get_bus_effect_count(explosion_bus):
		var effect:=AudioServer.get_bus_effect(explosion_bus,i)
		if effect is AudioEffectCompressor:
			compressor_count+=1
			compressor_index=i
			var c:=effect as AudioEffectCompressor
			verify(close(c.threshold,-3.5,.01) and close(c.ratio,3.5,.01),
				"Explosion-only compressor keeps calibrated threshold and ratio")
			verify(close(c.attack_us,5000.,1.) and close(c.release_ms,180.,1.),
				"Transient attack and tail release are unchanged")
		if effect is AudioEffectLimiter:
			limiter_count+=1
			limiter_index=i
	verify(compressor_count==1 and limiter_count==1 and compressor_index<limiter_index,
		"One compressor precedes one safety limiter on explosion bus")
	verify(AudioServer.get_bus_send(explosion_bus)=="Armas",
		"Explosion bus still obeys user's Arms/Effects/Master sliders")
	var master_limiter: AudioEffectLimiter
	var master_count:=0
	for i in AudioServer.get_bus_effect_count(master_bus):
		if AudioServer.get_bus_effect(master_bus,i) is AudioEffectLimiter:
			master_count+=1
			master_limiter=AudioServer.get_bus_effect(master_bus,i) as AudioEffectLimiter
	verify(master_count==1 and master_limiter!=null,"Single Master limiter exists")
	if master_limiter!=null:
		master_limiter.threshold_db=-6.0
		master_limiter.ceiling_db=-.7
		GameAudioSettings.ensure()
		verify(close(master_limiter.threshold_db,-1.0,.001) and close(master_limiter.ceiling_db,-1.0,.001),
			"Legacy -6dB Master makeup is corrected to -1dB without duplicate")
	var master_effect_count:=AudioServer.get_bus_effect_count(master_bus)
	GameAudioSettings.ensure()
	verify(AudioServer.get_bus_effect_count(master_bus)==master_effect_count,
		"Repeated settings initialization creates no duplicate limiter")
	var second_manager:=GameExplosionAudio.new()
	stage.add_child(second_manager)
	await process_frame
	verify(AudioServer.get_bus_effect_count(explosion_bus)==2,
		"Second explosion manager does not add duplicate compressors or limiters")
	second_manager.queue_free()
	await process_frame

	capture=AudioEffectCapture.new()
	capture.buffer_length=3.0
	AudioServer.add_bus_effect(master_bus,capture)
	var near_plain: Dictionary=await measure("baseline_heavy_50","destroy",50.,1,false)
	var near_shaped: Dictionary=await measure("shaped_heavy_50","destroy",50.,1,true)
	var pair_plain: Dictionary=await measure("baseline_pair_50","destroy",50.,2,false)
	var pair_shaped: Dictionary=await measure("shaped_pair_50","destroy",50.,2,true)
	var far_plain: Dictionary=await measure("baseline_heavy_400","destroy",400.,1,false)
	var far_shaped: Dictionary=await measure("shaped_heavy_400","destroy",400.,1,true)
	var very_far: Dictionary=await measure("shaped_heavy_600","destroy",600.,1,true)
	var grenade: Dictionary=await measure("shaped_grenade_25","grenade",25.,1,true)
	var drone: Dictionary=await measure("shaped_drone_25","drone",25.,1,true)
	var stressed: Dictionary=await measure("shaped_four_heavy_50","destroy",50.,4,true)
	verify(float(near_plain.near_ceiling_pct)>float(near_shaped.near_ceiling_pct)*2.0,
		"Transient compressor reduces near-field ceiling saturation for one tank")
	verify(float(pair_plain.near_ceiling_pct)>float(pair_shaped.near_ceiling_pct)*3.0,
		"Transient compressor substantially reduces ceiling saturation of two tanks")
	verify(float(pair_shaped.near_ceiling_pct)<2.0,
		"Two heavy explosions spend less than 2% of frames near the Master ceiling")
	verify(float(pair_shaped.rms_db)<float(pair_plain.rms_db)-2.0,
		"Two simultaneous tank blasts no longer raise the mix body excessively")
	verify(float(near_shaped.rms_db)>float(far_shaped.rms_db)+1.5,
		"Close heavy blast keeps a clear level advantage over 400m")
	verify(absf(float(far_plain.rms_db)-float(far_shaped.rms_db))<.65,
		"400m heavy blast stays within 0.65dB of the already-approved loud range")
	verify(float(far_shaped.rms_db)>float(very_far.rms_db)+.4,
		"Heavy explosions keep attenuating physically between 400 and 600m")
	verify(float(near_shaped.rms_db)>-17.0,
		"Close heavy blast retains low-frequency body and audible impact")
	for value in [near_shaped,pair_shaped,far_shaped,very_far,grenade,drone,stressed]:
		verify(float(value.clipped_pct)==0.0 and float(value.peak_db)<-.9,
			str(value.case)+" protected against digital clipping")
	verify(float(stressed.near_ceiling_pct)<8.0 and int(stressed.active)==4,
		"Four simultaneous heavy explosions remain bounded and audible")
	verify(int(explosions.voices.size())==GameExplosionAudio.LIMIT
		and int(explosions.pressure_voices.size())==GameExplosionAudio.PRESSURE_LIMIT,
		"Original 24+8 voice budgets remain unchanged")
	AudioServer.set_bus_effect_enabled(explosion_bus,compressor_index,true)
	AudioServer.remove_bus_effect(master_bus,AudioServer.get_bus_effect_count(master_bus)-1)
	print("R01_EXPLOSION_DYNAMICS ",JSON.stringify({"checks":checks,"failures":issues,
		"godot":"4.7.2","gpu":"GTX 1650","native_audio":true}))
	stage.queue_free()
	await process_frame
	quit(0 if issues.is_empty() else 1)
