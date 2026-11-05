extends SceneTree

var failures: Array[String]=[]
var checks:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)

func event_voices(manager: GameExplosionAudio,id: String) -> Array:
	var results: Array=[]
	for voice in manager.voices:
		if voice.playing and str(voice.get_meta("event_id",""))==id:
			results.append(voice)
	return results

func run() -> void:
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
	var impacts:=GameExplosionAudio.new()
	scene.add_child(impacts)
	await process_frame
	var clips: Array=GameCombatAudioCatalog.AUTOCANNON_SHOTS+[GameCombatAudioCatalog.AUTOCANNON_SHOT_FAR]+GameCombatAudioCatalog.AUTOCANNON_IMPACTS
	for path in clips:
		var wav:=GameCombatAudioCatalog.stream(path) as AudioStreamWAV
		check(wav!=null and wav.mix_rate==48000 and not wav.stereo and wav.get_length()>=1.7,"30mm WAV 48 kHz mono imported: "+str(path).get_file())
	check(GameWeaponAudio.PATHS["autocannon"]!="heavy-mg.wav","30mm no longer plays generic machine gun")
	check(GameWeaponAudio.profile("autocannon").range==4000.,"original cannon 3D range is preserved")
	var source:=Vector3(0,0,-25)
	for i in 3:
		var shot:=guns._play_now(42,"autocannon",source)
		check(is_instance_valid(shot) and shot.playing and shot.stream.resource_path==GameCombatAudioCatalog.AUTOCANNON_SHOTS[i],"APC shot alternates variant "+str(i+1))
		check(is_instance_valid(shot) and is_equal_approx(shot.pitch_scale, [.98,1.0,1.02][i]),"shot pitch matches restrained variant "+str(i+1))
		check(is_instance_valid(shot) and shot.global_position==source,"shot uses vehicle muzzle position")
	var other_apc:=guns._play_now(77,"autocannon",Vector3(6,0,-30))
	check(is_instance_valid(other_apc) and other_apc.stream.resource_path==GameCombatAudioCatalog.AUTOCANNON_SHOTS[0],"second APC rotates variants independently")
	var distant_gun:=guns._play_now(42,"autocannon",Vector3(0,0,-650))
	check(is_instance_valid(distant_gun) and distant_gun.stream.resource_path==GameCombatAudioCatalog.AUTOCANNON_SHOT_FAR,"distant APC uses dedicated open air shot")
	check(is_instance_valid(distant_gun) and distant_gun.global_position.z==-650,"distant shot keeps 3D origin")
	check(guns.voices.size()==GameWeaponAudio.LIMIT,"fixed 96-player gun budget preserved")
	check(GameCombatAudioCatalog.autocannon_impact_kind("vehicle")=="autocannon_metal" and GameCombatAudioCatalog.autocannon_impact_kind("metal")=="autocannon_metal","armored or metal collision selects armor impact")
	check(GameCombatAudioCatalog.autocannon_impact_kind("mud")=="autocannon_ground" and GameCombatAudioCatalog.autocannon_impact_kind("concrete")=="autocannon_ground","ground or concrete collision selects ground impact")
	var before_pressure:=impacts.pressure_started
	var ground:=impacts._start("impact:ground",Vector3(0,0,-25),"autocannon_ground")
	var metal:=impacts._start("impact:metal",Vector3(0,0,-30),"autocannon_metal")
	var far:=impacts._start("impact:far",Vector3(0,0,-800),"autocannon_metal")
	check(is_instance_valid(ground) and ground.stream.resource_path==GameCombatAudioCatalog.AUTOCANNON_IMPACTS[0],"close 30mm ground has its dedicated WAV")
	check(is_instance_valid(metal) and metal.stream.resource_path==GameCombatAudioCatalog.AUTOCANNON_IMPACTS[1],"30mm armored hit has its dedicated WAV")
	check(is_instance_valid(far) and far.stream.resource_path==GameCombatAudioCatalog.AUTOCANNON_IMPACTS[2],"far 30mm impact has its distant WAV")
	check(impacts.pressure_started==before_pressure,"30mm does not double-trigger grenade pressure audio")
	check(is_instance_valid(far) and far.global_position.z==-800 and far.max_distance==2500.0,"distant 30mm impact retains position and range")
	var mixed:=impacts._start("impact:crossfade",Vector3(0,0,-285),"autocannon_metal")
	var layers:=event_voices(impacts,"impact:crossfade")
	var total:=0.0
	for voice in layers:total+=float(voice.get_meta("mix_weight",0))
	check(is_instance_valid(mixed) and layers.size()==2,"30mm impact crossfades between close and distant at medium range")
	check(absf(total-1.0)<.001,"impact crossfade does not double the full sample volume")
	check(impacts.voices.size()==GameExplosionAudio.LIMIT,"fixed 24-player explosion budget preserved")
	var war:=WarAudio.new()
	scene.add_child(war)
	await process_frame
	war.explosion("route:armor",Vector3(0,0,-1),"autocannon","vehicle")
	war.explosion("route:soil",Vector3(0,0,-1.5),"autocannon","mud")
	var routed_metal:=event_voices(war.explosion_audio,"route:armor")
	var routed_ground:=event_voices(war.explosion_audio,"route:soil")
	check(routed_metal.size()==1 and routed_metal[0].stream.resource_path==GameCombatAudioCatalog.AUTOCANNON_IMPACTS[1],"WarAudio routes armor surface into 30mm metal sample")
	check(routed_ground.size()==1 and routed_ground[0].stream.resource_path==GameCombatAudioCatalog.AUTOCANNON_IMPACTS[0],"WarAudio routes terrain surface into 30mm soil sample")
	check(war.explosion_audio.pressure_started==0,"WarAudio routed impacts do not create grenade explosion pressure")
	check(war.autocannon_sequence.is_empty(),"firing rotation stays per owning audio manager")
	for voice in guns.voices:voice.stop()
	for voice in impacts.voices:voice.stop()
	for voice in war.voices:voice.stop()
	print("APC30MM_AUDIO_QA ",JSON.stringify({"checks":checks,"failures":failures,"resources":clips.size()}))
	scene.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
