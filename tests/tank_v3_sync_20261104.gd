extends SceneTree

var failures: Array[String] = []
var checks:=0
func _initialize() -> void: run.call_deferred()
func verify(ok: bool, label: String) -> void:
	checks+=1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)

func run() -> void:
	if DisplayServer.get_name()=="headless":quit(2);return
	var scene:=Node3D.new();root.add_child(scene)
	var camera:=Camera3D.new();scene.add_child(camera);camera.current=true
	var listener:=AudioListener3D.new();scene.add_child(listener);listener.make_current()
	var audio:=GameExplosionAudio.new();scene.add_child(audio)
	var visuals:=WarEffects.new();scene.add_child(visuals)
	await process_frame

	for path in [GameCombatAudioCatalog.EXPLOSIONS[1],GameCombatAudioCatalog.EXPLOSIONS_FAR[1]]:
		var wav:=GameCombatAudioCatalog.stream(path) as AudioStreamWAV
		verify(wav!=null and wav.mix_rate==48000 and not wav.stereo and absf(wav.get_length()-13.4)<.02,"V3 PCM resource imported correctly: "+path.get_file())
	verify(GameCombatAudioCatalog.explosion_type("destroy")==1 and GameCombatAudioCatalog.explosion_type("tank")==1,"vehicle/tank destruction points to tank V3 resource")
	var near:=audio._start("V3:near",Vector3(0,0,-25),"destroy")
	var far:=audio._start("V3:far",Vector3(0,0,-550),"destroy")
	verify(is_instance_valid(near) and near.stream.resource_path==GameCombatAudioCatalog.EXPLOSIONS[1],"close tank uses V3 nearby file")
	verify(is_instance_valid(far) and far.stream.resource_path==GameCombatAudioCatalog.EXPLOSIONS_FAR[1],"distant tank uses V3 far file")
	verify(audio.voices.size()==24 and audio.pressure_voices.size()==8,"V3 reuses established bounded pools and pressure transients")

	var kinds:=["tank_wreck","armor_wreck"]
	var times:=PackedFloat32Array([1.46,1.27,.36,1.17,1.85])
	for kind in kinds:
		visuals.cinematic.clear()
		visuals.explosion(Vector3(0,0,-27),9.,12345,kind)
		verify(visuals.cinematic.size()==1,"wreck "+kind+" gets synchronized visual sequence")
		for i in 5:
			visuals._cinematic_step(times[i])
			verify(int(visuals.cinematic[0].next)==i+1,"wreck "+kind+" visual cookoff "+str(i+1)+" follows V3 audio")
		verify(int(visuals.cinematic[0].next)==5,"wreck "+kind+" emits five matching secondary flashes")
	print("TANK_V3_SYNC ",JSON.stringify({"checks":checks,"failures":failures}))
	scene.queue_free();await process_frame
	quit(0 if failures.is_empty() else 1)
