extends SceneTree

var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func pool_count(effect: WarEffects) -> int:
	var total:=0
	for slot in effect.slots:
		if not slot.is_empty(): total+=1
	return total
func run() -> void:
	if DisplayServer.get_name()=="headless":
		quit(2);return
	var scene:=Node3D.new()
	root.add_child(scene)
	var camera:=Camera3D.new();scene.add_child(camera)
	camera.current=true
	camera.global_position=Vector3.ZERO
	var listener:=AudioListener3D.new();scene.add_child(listener)
	listener.make_current()
	var audio:=GameExplosionAudio.new();scene.add_child(audio)
	var effects:=WarEffects.new();scene.add_child(effects)
	await process_frame
	var home_h:=camera.h_offset
	var home_v:=camera.v_offset
	for i in 3:
		var stream:=GameCombatAudioCatalog.stream(GameExplosionAudio.PRESSURE_PATHS[i]) as AudioStreamWAV
		check(stream!=null and stream.mix_rate==48000 and not stream.stereo,"new explosion pressure waveform "+str(i)+" loads as mono 48k")
	var near:=audio._start("cinematic:near",Vector3(0,0,-20),"tank")
	check(is_instance_valid(near) and near.playing,"original tank kit WAV remains primary")
	check(audio.pressure_voices.size()==8 and audio.voices.size()==24,"pressure has bounded 8-player pool and original kit retains 24")
	check(audio.pressure_started==1,"heavy nearby explosion adds one physical pressure transient")
	var pressure_stream:=GameCombatAudioCatalog.stream(GameExplosionAudio.PRESSURE_PATHS[1])
	var pressure_ok:=false
	for voice in audio.pressure_voices:
		if voice.playing and voice.stream==pressure_stream and voice.global_position==Vector3(0,0,-20): pressure_ok=true
	check(pressure_ok,"tank pressure layer stays at actual 3D impact point")
	var active_before:=audio.pressure_started
	audio._start("cinematic:far",Vector3(0,0,-700),"tank")
	check(audio.pressure_started==active_before,"distant explosions avoid unnecessary pressure-layer players")
	effects.explosion(Vector3(0,0,-15),9.,17001,"tank_wreck")
	check(pool_count(effects)>=28,"near vehicle explosion creates substantial dust, fragments, flash and smoke")
	check(effects.ring_events.size()==1,"heavy blast creates visible shockwave ring")
	check(effects.shock_left>0 and effects.shock_power>0,"near heavy blast schedules a small local camera impulse")
	var heavy_count:=pool_count(effects)
	effects._process(.08)
	check(absf(camera.h_offset-home_h)>0.00001 or absf(camera.v_offset-home_v)>0.00001,"blast camera impulse is visible")
	effects._process(.8)
	check(camera.h_offset==home_h and camera.v_offset==home_v and effects.shock_left==0,"camera offsets restore after the blast")
	check(effects.pool.visible_instance_count<=WarEffects.LIMIT,"multimesh draw remains limited to 256 instances")
	var before:=pool_count(effects)
	effects.explosion(Vector3(0,0,-650),3.,17002,"grenade")
	check(pool_count(effects)-before<=12,"distant grenade respects reduced particle budget")
	for i in 40:
		effects.explosion(Vector3(0,0,-15-float(i%5)),4.,18000+i,"drone")
		audio._start("burst:"+str(i),Vector3(0,0,-15-float(i%5)),"drone")
	effects._process(.016)
	check(effects.slots.size()==WarEffects.LIMIT and effects.pool.visible_instance_count<=WarEffects.LIMIT,"40 explosive events remain inside fixed 256-instance particle pool")
	check(effects.rings.size()==WarEffects.MAX_CINEMATIC and effects.ring_events.size()<=WarEffects.MAX_CINEMATIC,"shockwave meshes do not grow with load")
	check(audio.voices.size()==24 and audio.pressure_voices.size()==8,"no new audio players generated during 40 simultaneous events")
	var pressure_total:=audio.pressure_started
	scene.queue_free();await process_frame
	print("EXPLOSION_IMPACT_QA ",JSON.stringify({"checks":checks,"failures":failures,"initial_heavy_cards":heavy_count,"pressure_started":pressure_total}))
	quit(0 if failures.is_empty() else 1)
