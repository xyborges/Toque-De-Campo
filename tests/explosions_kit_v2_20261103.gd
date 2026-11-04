extends SceneTree
var failures: Array[String]=[]
var count:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	count+=1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func playing_event(a: GameExplosionAudio,id: String) -> Array[AudioStreamPlayer3D]:
	var result: Array[AudioStreamPlayer3D]=[]
	for voice in a.voices:
		if voice.playing and str(voice.get_meta("event_id",""))==id:
			result.append(voice)
	return result
func run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("audio validation requires native rendering")
		quit(2);return
	var scene:=Node3D.new();root.add_child(scene)
	var camera:=Camera3D.new();scene.add_child(camera);camera.current=true
	var listener:=AudioListener3D.new();scene.add_child(listener);listener.make_current()
	var a:=GameExplosionAudio.new();scene.add_child(a)
	await process_frame
	for index in 3:
		var near_stream:=GameCombatAudioCatalog.stream(GameCombatAudioCatalog.EXPLOSIONS[index]) as AudioStreamWAV
		var far_stream:=GameCombatAudioCatalog.stream(GameCombatAudioCatalog.EXPLOSIONS_FAR[index]) as AudioStreamWAV
		check(near_stream!=null and far_stream!=null and not near_stream.stereo and not far_stream.stereo,"kit "+str(index)+" mono WAV loaded")
		check(near_stream.mix_rate==48000 and far_stream.mix_rate==48000,"kit "+str(index)+" native 48 kHz")
		check(absf(near_stream.get_length()-far_stream.get_length())<.01,"kit "+str(index)+" two variants have matching durations")
	check(GameCombatAudioCatalog.explosion_type("grenade")==0 and GameCombatAudioCatalog.explosion_type("standard")==0,"grenade and default infantry blast map to grenade")
	check(GameCombatAudioCatalog.explosion_type("tank")==1 and GameCombatAudioCatalog.explosion_type("destroy")==1,"tank cannon and vehicle destruction map to heavy explosion")
	check(GameCombatAudioCatalog.explosion_type("drone")==2 and GameCombatAudioCatalog.explosion_type("tv")==2,"drone and guided missile map to drone explosion")
	var kinds:=["grenade","tank","drone"]
	for index in kinds.size():
		var kind: String=kinds[index]
		var id: String="near-"+kind
		var point:=Vector3(2.,0.,-25.-index)
		var near:=a._start(id,point,kind)
		check(is_instance_valid(near) and near.playing and near.stream.resource_path==GameCombatAudioCatalog.EXPLOSIONS[index],"close "+kind+" selects supplied close recording")
		check(playing_event(a,id).size()==1,"close "+kind+" allocates one voice")
		check(near.global_position==point and int(near.get_meta("variant",-1))==index,"close "+kind+" keeps real 3D origin and type")
	for index in kinds.size():
		var kind: String=kinds[index]
		var id: String="far-"+kind
		var far:=a._start(id,Vector3(0,0,-550.-index),kind)
		check(is_instance_valid(far) and far.playing and far.stream.resource_path==GameCombatAudioCatalog.EXPLOSIONS_FAR[index],"far "+kind+" selects supplied distant recording")
		check(playing_event(a,id).size()==1,"far "+kind+" allocates one voice")
	var mixed:=a._start("mix-tank",Vector3(0,0,-285.),"tank")
	var layers:=playing_event(a,"mix-tank")
	var near_weight:=0.
	var far_weight:=0.
	for voice in layers:
		if bool(voice.get_meta("distant_sample",false)): far_weight=float(voice.get_meta("mix_weight",0))
		else: near_weight=float(voice.get_meta("mix_weight",0))
	check(is_instance_valid(mixed) and layers.size()==2,"middle distance uses two complementary voices")
	check(absf(near_weight+far_weight-1.)<.001 and absf(near_weight-.5)<.02,"crossfade uses complementary gain, never doubles full loudness")
	check(layers[0].global_position==layers[1].global_position,"crossfade keeps both samples at the same world origin")
	check(a.voices.size()==GameExplosionAudio.LIMIT,"the voice pool remains bounded at 24")
	var near_event:=a.play_event("anti-duplicate",Vector3(0,0,-1),"grenade")
	check(is_instance_valid(near_event) and a.play_event("anti-duplicate",Vector3.ZERO,"drone")==null,"duplicate network event never plays twice")
	var reverb_count:=0
	var far_bus:=AudioServer.get_bus_index("CombatExplosionsFar")
	for effect in AudioServer.get_bus_effect_count(far_bus):
		if AudioServer.get_bus_effect(far_bus,effect) is AudioEffectReverb:reverb_count+=1
	check(reverb_count==0,"supplied outdoor recordings do not receive artificial room reverb")
	print("KIT_EXPLOSIONS_V2 ",JSON.stringify({"checks":count,"failures":failures,"layers":layers.size()}))
	scene.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
